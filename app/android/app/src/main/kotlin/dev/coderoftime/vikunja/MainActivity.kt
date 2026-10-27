package dev.coderoftime.vikunja

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.activity.OnBackPressedCallback
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity because local_auth's BiometricPrompt needs one.
class MainActivity : FlutterFragmentActivity() {
    private var shareInbox: ShareInbox? = null
    private var fileActions: FileActionsChannel? = null
    private var documents: DocumentPickerChannel? = null

    // On while the app lock is up, when Flutter leaves back to the platform:
    // Android would otherwise close the activity, and the app's state with
    // it, whenever the task was not started from the launcher.
    private val backWhileLocked = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            moveTaskToBack(true)
        }
    }

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
        onBackPressedDispatcher.addCallback(this, backWhileLocked)
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

    override fun onPostResume() {
        super.onPostResume()
        // Under the AppCompat theme, Android draws its grey default focus
        // highlight over the focused FlutterView, i.e. the whole app, once a
        // key press leaves touch mode, and keeps it there.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            withoutFocusHighlight(window.decorView)
        }
    }

    private fun withoutFocusHighlight(view: View) {
        if (view is FlutterView) {
            view.defaultFocusHighlightEnabled = false
        } else if (view is ViewGroup) {
            for (i in 0 until view.childCount) withoutFocusHighlight(view.getChildAt(i))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "dev.coderoftime.vikunja/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "osVersion" -> result.success(Build.VERSION.RELEASE)
                    "copySensitive" -> copySensitive(call.argument<String>("text"), result)
                    "setSecure" -> setSecure(call.argument<Boolean>("secure"), result)
                    "setRecentsScreenshotEnabled" ->
                        setRecentsScreenshot(call.argument<Boolean>("enabled"), result)
                    "moveTaskToBack" -> result.success(moveTaskToBack(true))
                    "setBackMovesTaskToBack" ->
                        setBackMovesTaskToBack(call.argument<Boolean>("enabled"), result)
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

    private fun copySensitive(text: String?, result: MethodChannel.Result) {
        if (text == null) {
            result.error("invalid_arguments", "text is missing", null)
            return
        }
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply { putBoolean(EXTRA_IS_SENSITIVE, true) }
        getSystemService(ClipboardManager::class.java).setPrimaryClip(clip)
        result.success(null)
    }

    private fun setSecure(secure: Boolean?, result: MethodChannel.Result) {
        when (secure) {
            true -> window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            false -> window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            null -> {
                result.error("invalid_arguments", "secure is missing", null)
                return
            }
        }
        result.success(null)
    }

    private fun setRecentsScreenshot(enabled: Boolean?, result: MethodChannel.Result) {
        if (enabled == null) {
            result.error("invalid_arguments", "enabled is missing", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(false)
            return
        }
        setRecentsScreenshotEnabled(enabled)
        result.success(true)
    }

    private fun setBackMovesTaskToBack(enabled: Boolean?, result: MethodChannel.Result) {
        if (enabled == null) {
            result.error("invalid_arguments", "enabled is missing", null)
            return
        }
        backWhileLocked.isEnabled = enabled
        result.success(null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (fileActions?.onActivityResult(requestCode, resultCode, data) == true) return
        if (documents?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private companion object {
        // ClipDescription.EXTRA_IS_SENSITIVE from API 33; Android 13 hides the
        // clipboard preview of a clip marked with it, older versions ignore it.
        const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }
}
