package dev.coderoftime.vikunja

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shareInbox: ShareInbox? = null
    private var fileActions: FileActionsChannel? = null
    private var documents: DocumentPickerChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Reopened from Recents, the activity gets the task's root intent
        // again; when a home screen shortcut started the task, quick_actions
        // would report that shortcut a second time, when a task link started
        // it, Flutter's deep linking would open the task again, and a share
        // would be offered again. A restore after the process died replays
        // the launch intent too.
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) {
            intent = Intent(intent).setAction(Intent.ACTION_MAIN).replaceExtras(Bundle()).setData(null)
                .also { it.clipData = null }
        } else if (savedInstanceState != null) {
            if (intent.action == ShareInbox.ACTION_SHARE) {
                intent = ShareInbox.withoutShare(intent)
            } else if (intent.data != null) {
                intent = Intent(intent).setData(null)
            }
        } else if (intent.action == ShareInbox.ACTION_SHARE) {
            ShareInbox.receive(this, intent)
            intent = ShareInbox.withoutShare(intent)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        if (intent.action != ShareInbox.ACTION_SHARE) {
            super.onNewIntent(intent)
            return
        }
        ShareInbox.receive(this, intent)
        val taken = ShareInbox.withoutShare(intent)
        setIntent(taken)
        super.onNewIntent(taken)
        shareInbox?.announce()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "dev.coderoftime.vikunja/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "osVersion" -> result.success(Build.VERSION.RELEASE)
                    else -> result.notImplemented()
                }
            }
        shareInbox = ShareInbox(applicationContext, messenger)
        fileActions = FileActionsChannel(this, messenger)
        documents = DocumentPickerChannel(this, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        shareInbox?.detach()
        shareInbox = null
        fileActions?.detach()
        fileActions = null
        documents?.detach()
        documents = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (fileActions?.onActivityResult(requestCode, resultCode, data) == true) return
        if (documents?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
