package io.vikunja.app

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.content.IntentCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReferenceArray

internal class PendingShare<T> {
    class Entry<T>(val id: Long, val share: T)

    @Volatile
    var current: Entry<T>? = null
        private set
    private var nextId = 0L

    @Synchronized
    fun replace(share: T) {
        current = Entry(++nextId, share)
    }

    @Synchronized
    fun clear(id: Long?): Boolean {
        val entry = current ?: return false
        if (entry.id != id) return false
        current = null
        return true
    }
}

// The share MainActivity received, offered to Dart over a channel until
// Dart clears it. It lives in the process, not the activity, so a
// recreated activity still has it; a new process never replays it, because
// MainActivity strips the share from its intent once taken. Shared files
// are read only through content URIs of other apps (never file://, never
// this app's own providers, which would hand out the app's private files),
// and only those of the pending share; copies go to cache/share-inbox under
// random names. Nothing shared is logged. A sending app's provider may
// never answer or never deliver: every call to it runs on a thread of its
// own, at most MAX_PROVIDER_CALLS at a time, with a time limit the main
// thread watches, and nothing else waits behind it. A provider that ran out
// of time gets no further calls for the share.
class ShareInbox(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
        if (pending.current == null) {
            purges.execute { purgeFiles(File(context.cacheDir, INBOX), olderThanMillis = DAY_MILLIS) }
        }
    }

    fun detach() = channel.setMethodCallHandler(null)

    // Tells Dart about a share that arrived while the app runs.
    fun announce() {
        val share = pending.current ?: return
        describe(share) { described -> described?.let { channel.invokeMethod("shared", it) } }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pending" -> {
                val share = pending.current
                if (share == null) {
                    result.success(null)
                } else {
                    describe(share) { result.success(it) }
                }
            }
            "copy" -> {
                val uri = call.argument<String>("uri")
                val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                if (uri == null || maxBytes == null) {
                    result.error("bad_arguments", null, null)
                } else {
                    val copy = Copy(uri, result, main, started = now())
                    if (authorityOf(uri) in stalled || !slots.tryTake()) {
                        copy.answer { it.error("unreadable", null, null) }
                    } else {
                        copies.add(copy)
                        providerCalls.execute {
                            try {
                                copy(copy, maxBytes)
                            } finally {
                                slots.give()
                            }
                        }
                        watch(copy)
                    }
                }
            }
            "cancelCopy" -> {
                val uri = call.argument<String>("uri")
                copies.filter { it.uri == uri }.forEach { it.stop() }
                result.success(null)
            }
            "clear" -> {
                val id = call.argument<Number>("id")?.toLong()
                if (!pending.clear(id)) {
                    result.success(null)
                    return
                }
                stopCopies()
                stalled.clear()
                purges.execute {
                    purgeFiles(File(context.cacheDir, INBOX))
                    main.post { result.success(null) }
                }
            }
            else -> result.notImplemented()
        }
    }

    // What the providers say about the files, as far as each answers within
    // the limit; a file without an answer goes with its URI only, and its
    // provider is taken as stalled. reply gets null once a newer share has
    // taken this one's place.
    private fun describe(entry: PendingShare.Entry<Share>, reply: (Map<String, Any?>?) -> Unit) {
        val share = entry.share
        val files = AtomicReferenceArray<Map<String, Any?>>(share.uris.size)
        val signal = CancellationSignal()
        val answered = AtomicBoolean(false)
        val lastAnswer = AtomicLong(now())
        val describing = AtomicInteger(-1)
        lateinit var watch: Runnable
        val finish = Runnable {
            if (!answered.compareAndSet(false, true)) return@Runnable
            main.removeCallbacks(watch)
            signal.cancel()
            reply(
                answerFor(entry, pending.current) {
                    mapOf(
                        "id" to entry.id,
                        "subject" to share.subject,
                        "text" to share.text,
                        "files" to share.uris.mapIndexed { index, uri ->
                            files.get(index) ?: mapOf("uri" to uri.toString(), "name" to "")
                        },
                    )
                },
            )
        }
        watch = object : Runnable {
            override fun run() {
                val now = now()
                val last = lastAnswer.get()
                if (!describeOverdue(now, last, DESCRIBE_LIMIT_MILLIS)) {
                    main.postDelayed(this, DESCRIBE_LIMIT_MILLIS - (now - last))
                    return
                }
                share.uris.getOrNull(describing.get())?.authority?.let { stalled.add(it) }
                finish.run()
            }
        }
        if (share.uris.isEmpty() || !slots.tryTake()) {
            finish.run()
            return
        }
        providerCalls.execute {
            try {
                for ((index, uri) in share.uris.withIndex()) {
                    if (answered.get()) return@execute
                    describing.set(index)
                    files.set(index, describeContent(context.contentResolver, uri, signal))
                    lastAnswer.set(now())
                }
                main.post(finish)
            } finally {
                slots.give()
            }
        }
        main.postDelayed(watch, DESCRIBE_LIMIT_MILLIS)
    }

    // Stops the copy once its provider has not opened the file within the
    // open limit, or nothing has arrived for the idle limit: a read the
    // kernel blocks never returns to the copy's own check.
    private fun watch(copy: Copy) {
        main.postDelayed(
            object : Runnable {
                override fun run() {
                    if (copy.stopped) return
                    if (copyOverdue(now(), copy.started, copy.lastProgress, OPEN_LIMIT_MILLIS, IDLE_LIMIT_MILLIS)) {
                        authorityOf(copy.uri)?.let { stalled.add(it) }
                        copy.stop()
                    } else {
                        main.postDelayed(this, WATCH_INTERVAL_MILLIS)
                    }
                }
            },
            WATCH_INTERVAL_MILLIS,
        )
    }

    private fun copy(copy: Copy, maxBytes: Long) {
        try {
            val uri = pending.current?.share?.uris?.firstOrNull { it.toString() == copy.uri }
            if (uri == null || !isForeignContent(context, uri)) {
                copy.answer { it.error("unreadable", null, null) }
                return
            }
            val directory = File(context.cacheDir, INBOX).apply { mkdirs() }
            val target = File(directory, randomFileName())
            try {
                val size = copyArriving(
                    context.contentResolver,
                    uri,
                    target,
                    maxBytes,
                    copy.signal,
                    IDLE_LIMIT_MILLIS,
                    progressed = { copy.lastProgress = now() },
                    stopped = { copy.stopped },
                )
                val path = target.absolutePath
                if (!copy.answer { it.success(mapOf("path" to path, "size" to size)) }) {
                    target.delete()
                }
            } catch (_: TooLargeException) {
                copy.answer { it.error("too_large", null, null) }
            } catch (_: Exception) {
                copy.answer { it.error("unreadable", null, null) }
            }
        } finally {
            copies.remove(copy)
        }
    }

    private class Share(val subject: String?, val text: String?, val uris: List<Uri>)

    // One copy's answer, given once: by the copy, or as unreadable when it
    // is called off or runs out of time.
    private class Copy(
        val uri: String,
        private val result: MethodChannel.Result,
        private val main: Handler,
        val started: Long,
    ) {
        val signal = CancellationSignal()
        private val answered = AtomicBoolean(false)

        // When the provider opened the file or last delivered; null before.
        @Volatile
        var lastProgress: Long? = null

        val stopped: Boolean get() = answered.get()

        fun answer(reply: (MethodChannel.Result) -> Unit): Boolean {
            if (!answered.compareAndSet(false, true)) return false
            main.post { reply(result) }
            return true
        }

        fun stop() {
            if (answer { it.error("unreadable", null, null) }) signal.cancel()
        }
    }

    companion object {
        const val ACTION_SHARE = "io.vikunja.app.action.SHARE"
        private const val CHANNEL = "io.vikunja.app/share"
        private const val INBOX = "share-inbox"
        private const val DAY_MILLIS = 24L * 60 * 60 * 1000
        private const val MAX_TEXT_CHARS = 100_000
        private const val MAX_FILES = 50
        private const val DESCRIBE_LIMIT_MILLIS = 10_000L
        private const val OPEN_LIMIT_MILLIS = 300_000L
        private const val IDLE_LIMIT_MILLIS = 30_000L
        private const val WATCH_INTERVAL_MILLIS = 5_000L
        private const val MAX_PROVIDER_CALLS = 8

        private val purges = Executors.newSingleThreadExecutor()

        // A thread per call, as a provider that never answers keeps its
        // thread until its process ends.
        private val providerCalls = Executors.newCachedThreadPool { task ->
            Thread(task, "share-inbox").apply { isDaemon = true }
        }

        private val slots = CallSlots(MAX_PROVIDER_CALLS)

        private val copies: MutableSet<Copy> = ConcurrentHashMap.newKeySet()

        // Authorities that ran out of time for the pending share.
        private val stalled: MutableSet<String> = ConcurrentHashMap.newKeySet()

        private fun stopCopies() = copies.forEach { it.stop() }

        private fun now() = SystemClock.elapsedRealtime()

        private fun authorityOf(uri: String): String? = Uri.parse(uri).authority

        internal fun <S : Any> answerFor(
            share: S,
            current: S?,
            described: () -> Map<String, Any?>,
        ): Map<String, Any?>? = if (share === current) described() else null

        internal fun copyOverdue(now: Long, started: Long, lastProgress: Long?, openLimit: Long, idleLimit: Long) =
            if (lastProgress == null) now - started >= openLimit else now - lastProgress >= idleLimit

        internal fun describeOverdue(now: Long, lastAnswer: Long, limit: Long) = now - lastAnswer >= limit

        private val pending = PendingShare<Share>()

        // Takes the share out of an intent MainActivity received; anything
        // not acceptable is left out here too, as MainActivity is exported
        // and anyone may send it this action.
        fun receive(context: Context, intent: Intent) {
            val share = Share(
                subject = textExtra(intent, Intent.EXTRA_SUBJECT),
                text = textExtra(intent, Intent.EXTRA_TEXT),
                uris = streamsOf(intent).filter { isForeignContent(context, it) },
            )
            if (share.subject != null || share.text != null || share.uris.isNotEmpty()) {
                pending.replace(share)
                // The earlier share's copies are of no use any more.
                stopCopies()
                stalled.clear()
            }
        }

        // The intent without the share, so neither Recents nor a restore
        // can hand it over again.
        fun withoutShare(intent: Intent): Intent = Intent(intent)
            .setAction(Intent.ACTION_MAIN)
            .replaceExtras(Bundle())
            .also { it.clipData = null }

        fun textExtra(intent: Intent, name: String): String? = try {
            intent.getCharSequenceExtra(name)?.toString()?.takeIf { it.isNotBlank() }
                ?.let { cutText(it, MAX_TEXT_CHARS) }
        } catch (_: RuntimeException) {
            // Extras another app sent that cannot be unparcelled.
            null
        }

        // At most maxChars UTF-16 units, never half a surrogate pair, which
        // the channel's UTF-8 could not carry.
        internal fun cutText(text: String, maxChars: Int): String {
            if (text.length <= maxChars) return text
            val end = if (Character.isHighSurrogate(text[maxChars - 1])) maxChars - 1 else maxChars
            return text.substring(0, end)
        }

        fun streamsOf(intent: Intent): List<Uri> {
            val uris = LinkedHashSet<Uri>()
            try {
                if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
                    IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                        ?.filterNotNull()?.let { uris.addAll(it) }
                } else {
                    IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                        ?.let { uris.add(it) }
                }
            } catch (_: RuntimeException) {
                // Extras another app sent that cannot be unparcelled.
            }
            intent.clipData?.let { clip ->
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index).uri?.let { uris.add(it) }
                }
            }
            return uris.take(MAX_FILES)
        }

        fun isForeignContent(context: Context, uri: Uri): Boolean =
            isForeignContent(uri.scheme, uri.authority, context.packageName) { authority ->
                context.packageManager.resolveContentProvider(authority, 0)?.packageName
            }

        // providerPackage: the package of the provider with that authority,
        // null for none the app can see.
        internal fun isForeignContent(
            scheme: String?,
            uriAuthority: String?,
            ownPackage: String,
            providerPackage: (String) -> String?,
        ): Boolean {
            if (scheme != ContentResolver.SCHEME_CONTENT) return false
            // "10@authority" addresses another Android user's provider; the
            // part after the @ names the provider.
            val authority = uriAuthority?.substringAfterLast('@') ?: return false
            if (authority.isEmpty() || authority.startsWith(ownPackage)) return false
            // A lookup that fails cannot rule out the app's own provider.
            val provider = try {
                providerPackage(authority)
            } catch (_: RuntimeException) {
                return false
            }
            return provider != ownPackage
        }
    }
}

// At most max calls out at a time; a call stuck in a provider keeps its
// slot until the provider answers.
internal class CallSlots(private val max: Int) {
    private val taken = AtomicInteger(0)

    fun tryTake(): Boolean {
        if (taken.incrementAndGet() <= max) return true
        taken.decrementAndGet()
        return false
    }

    fun give() {
        taken.decrementAndGet()
    }
}
