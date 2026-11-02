package dev.coderoftime.rurana

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.Executors

// "Open with" and "save as" for downloaded attachments. Only files in
// cache/attachments are handed out: through AttachmentFileProvider, with a
// read grant for the one app that opens it, which ends with that app's
// task.
internal class FileActionsChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val state: EngineState,
) : MethodChannel.MethodCallHandler {

    // A write running on the executor may outlive the activity.
    private val context: Context = activity.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    fun detach(keepPending: Boolean) {
        channel.setMethodCallHandler(null)
        state.saveAs.release(keep = keepPending)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val file = call.argument<String>("path")?.let { attachmentFile(it) }
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        when (call.method) {
            "openWith" -> if (file == null) {
                result.error("not_allowed", null, null)
            } else {
                openWith(file, mime, result)
            }
            "saveAs" -> if (file == null) {
                result.error("not_allowed", null, null)
            } else {
                saveAs(file, call.argument<String>("name") ?: file.name, mime, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun openWith(file: File, mime: String, result: MethodChannel.Result) {
        val uri = FileProvider.getUriForFile(context, authority(context), file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, mime)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            activity.startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        }
    }

    private fun saveAs(file: File, name: String, mime: String, result: MethodChannel.Result) {
        if (state.saveAs.isPending) {
            result.error("busy", null, null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mime)
            .putExtra(Intent.EXTRA_TITLE, name)
        state.saveAs.start(file to result)
        try {
            activity.startActivityForResult(intent, REQUEST_SAVE_AS)
        } catch (_: ActivityNotFoundException) {
            state.saveAs.take()
            result.success(false)
        }
    }

    // True when the result was this channel's.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SAVE_AS) return false
        val (file, result) = state.saveAs.take() ?: return true
        val target = data?.data
        if (resultCode != Activity.RESULT_OK || target == null) {
            result.success(false)
            return true
        }
        executor.execute {
            try {
                write(file, target)
                main.post { result.success(true) }
            } catch (_: Exception) {
                main.post { result.error("write_failed", null, null) }
            }
        }
        return true
    }

    private fun write(file: File, target: Uri) {
        val resolver = context.contentResolver
        // Not every provider takes "wt"; a new document is empty anyway.
        val output = try {
            resolver.openOutputStream(target, "wt")
        } catch (_: FileNotFoundException) {
            resolver.openOutputStream(target, "w")
        } catch (_: IllegalArgumentException) {
            resolver.openOutputStream(target, "w")
        } ?: throw IOException("no stream")
        output.use { sink -> file.inputStream().use { it.copyTo(sink) } }
    }

    private fun attachmentFile(path: String): File? {
        val root = File(context.cacheDir, ATTACHMENTS).canonicalFile
        val file = File(path).canonicalFile
        if (!file.isFile || !file.path.startsWith(root.path + File.separator)) return null
        return file
    }

    companion object {
        private const val CHANNEL = "dev.coderoftime.rurana/files"
        private const val ATTACHMENTS = "attachments"
        private const val REQUEST_SAVE_AS = 0x5a7e
        private val executor = Executors.newSingleThreadExecutor()

        fun authority(context: Context) = "${context.packageName}.files"
    }
}

class AttachmentFileProvider : FileProvider()
