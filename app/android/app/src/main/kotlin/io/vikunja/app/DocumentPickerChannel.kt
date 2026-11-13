package io.vikunja.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// The system's document picker for attachments. The picked files are
// described off the main thread and only the ones Dart asks for are
// copied, capped, into cache/picked under random names: a plugin that
// read each whole file into memory on the main thread would freeze or
// kill the app for a large one. Only the files of the latest pick can be
// copied. Nothing picked is logged.
internal class DocumentPickerChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val state: EngineState,
) : MethodChannel.MethodCallHandler {

    // A copy running on the executor may outlive the activity. The read grants
    // of picked files hold for the whole app while the activity record lives,
    // which a relaunch keeps.
    private val context: Context = activity.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
        executor.execute { purgeFiles(pickedDirectory(), olderThanMillis = DAY_MILLIS) }
    }

    fun detach(keepPending: Boolean) {
        channel.setMethodCallHandler(null)
        state.pick.release(keep = keepPending)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(
                imagesOnly = call.argument<Boolean>("imagesOnly") == true,
                multiple = call.argument<Boolean>("multiple") != false,
                result = result,
            )
            "copy" -> {
                val uri = call.argument<String>("uri")
                val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                if (uri == null || maxBytes == null) {
                    result.error("bad_arguments", null, null)
                } else {
                    executor.execute { copy(uri, maxBytes, result) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun pick(imagesOnly: Boolean, multiple: Boolean, result: MethodChannel.Result) {
        if (state.pick.isPending) {
            result.error("busy", null, null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(if (imagesOnly) "image/*" else "*/*")
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
        state.pick.start(result)
        try {
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (_: ActivityNotFoundException) {
            state.pick.take()
            result.error("no_picker", null, null)
        }
    }

    // True when the result was this channel's.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = state.pick.take() ?: return true
        val uris = if (resultCode == Activity.RESULT_OK && data != null) urisOf(data) else emptyList()
        state.picked = uris.toSet()
        executor.execute {
            val described = uris.map { describeContent(context.contentResolver, it) }
            main.post { result.success(described) }
        }
        return true
    }

    private fun urisOf(data: Intent): List<Uri> {
        val uris = LinkedHashSet<Uri>()
        data.data?.let { uris.add(it) }
        data.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let { uris.add(it) }
            }
        }
        return uris.filter { it.scheme == ContentResolver.SCHEME_CONTENT }
    }

    private fun copy(uriText: String, maxBytes: Long, result: MethodChannel.Result) {
        val uri = state.picked.firstOrNull { it.toString() == uriText }
        if (uri == null) {
            main.post { result.error("unreadable", null, null) }
            return
        }
        val target = File(pickedDirectory().apply { mkdirs() }, randomFileName())
        try {
            val size = copyCapped(context.contentResolver, uri, target, maxBytes)
            main.post { result.success(mapOf("path" to target.absolutePath, "size" to size)) }
        } catch (_: TooLargeException) {
            main.post { result.error("too_large", null, null) }
        } catch (_: Exception) {
            main.post { result.error("unreadable", null, null) }
        }
    }

    private fun pickedDirectory() = File(context.cacheDir, PICKED)

    companion object {
        private const val CHANNEL = "io.vikunja.app/documents"
        private const val PICKED = "picked"
        private const val REQUEST_PICK = 0x5a7f
        private const val DAY_MILLIS = 24L * 60 * 60 * 1000
        private val executor = Executors.newSingleThreadExecutor()
    }
}
