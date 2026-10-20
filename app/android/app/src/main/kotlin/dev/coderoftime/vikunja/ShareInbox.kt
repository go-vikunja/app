package dev.coderoftime.vikunja

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.IntentCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// The share MainActivity received, offered to Dart over a channel until
// Dart clears it. It lives in the process, not the activity, so a
// recreated activity still has it; a new process never replays it, because
// MainActivity strips the share from its intent once taken. Shared files
// are read only through content URIs of other apps (never file://, never
// this app's own providers, which would hand out the app's private files),
// and only those of the pending share; copies go to cache/share-inbox under
// random names. Nothing shared is logged.
class ShareInbox(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
        if (pending == null) {
            executor.execute { purgeFiles(File(context.cacheDir, INBOX), olderThanMillis = DAY_MILLIS) }
        }
    }

    fun detach() = channel.setMethodCallHandler(null)

    // Tells Dart about a share that arrived while the app runs.
    fun announce() {
        val share = pending ?: return
        executor.execute {
            val described = describe(share)
            main.post { channel.invokeMethod("shared", described) }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pending" -> {
                val share = pending
                if (share == null) {
                    result.success(null)
                } else {
                    executor.execute {
                        val described = describe(share)
                        main.post { result.success(described) }
                    }
                }
            }
            "copy" -> {
                val uri = call.argument<String>("uri")
                val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                if (uri == null || maxBytes == null) {
                    result.error("bad_arguments", null, null)
                } else {
                    executor.execute { copy(uri, maxBytes, result) }
                }
            }
            "clear" -> {
                pending = null
                executor.execute {
                    purgeFiles(File(context.cacheDir, INBOX))
                    main.post { result.success(null) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun describe(share: Share): Map<String, Any?> = mapOf(
        "subject" to share.subject,
        "text" to share.text,
        "files" to share.uris.map { describeContent(context.contentResolver, it) },
    )

    private fun copy(uriText: String, maxBytes: Long, result: MethodChannel.Result) {
        val uri = pending?.uris?.firstOrNull { it.toString() == uriText }
        if (uri == null || !isForeignContent(context, uri)) {
            main.post { result.error("unreadable", null, null) }
            return
        }
        val directory = File(context.cacheDir, INBOX).apply { mkdirs() }
        val target = File(directory, randomFileName())
        try {
            val size = copyCapped(context.contentResolver, uri, target, maxBytes)
            main.post { result.success(mapOf("path" to target.absolutePath, "size" to size)) }
        } catch (_: TooLargeException) {
            main.post { result.error("too_large", null, null) }
        } catch (_: Exception) {
            main.post { result.error("unreadable", null, null) }
        }
    }

    private class Share(val subject: String?, val text: String?, val uris: List<Uri>)

    companion object {
        const val ACTION_SHARE = "dev.coderoftime.vikunja.action.SHARE"
        private const val CHANNEL = "dev.coderoftime.vikunja/share"
        private const val INBOX = "share-inbox"
        private const val DAY_MILLIS = 24L * 60 * 60 * 1000
        private const val MAX_TEXT_CHARS = 100_000
        private const val MAX_FILES = 50

        private val executor = Executors.newSingleThreadExecutor()

        @Volatile
        private var pending: Share? = null

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
                pending = share
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
                ?.let { if (it.length > MAX_TEXT_CHARS) it.substring(0, MAX_TEXT_CHARS) else it }
        } catch (_: RuntimeException) {
            // Extras another app sent that cannot be unparcelled.
            null
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

        fun isForeignContent(context: Context, uri: Uri): Boolean {
            if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false
            // "10@authority" addresses another Android user's provider; the
            // part after the @ names the provider.
            val authority = uri.authority?.substringAfterLast('@') ?: return false
            if (authority.isEmpty() || authority.startsWith(context.packageName)) return false
            val provider = try {
                context.packageManager.resolveContentProvider(authority, 0)
            } catch (_: RuntimeException) {
                null
            }
            return provider?.packageName != context.packageName
        }
    }
}
