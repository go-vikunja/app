package dev.coderoftime.vikunja

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.activity.OnBackPressedCallback
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.dart.DartExecutor

// A FragmentActivity because local_auth's BiometricPrompt needs one.
class MainActivity : FlutterFragmentActivity() {
    private var engineId: String? = null
    private var engineState = EngineState()
    private var device: DeviceChannel? = null
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
        // Before super: a restored FlutterFragment looks its engine up at once.
        // A state saved before engines were kept restores a fragment with an
        // engine of its own.
        engineId = if (savedInstanceState == null) KeptEngines.newId() else savedInstanceState.getString(ENGINE_ID)
        engineId?.let {
            keepEngine(it)
            engineState = KeptEngines.state(it)
        }
        super.onCreate(savedInstanceState)
        onBackPressedDispatcher.addCallback(this, backWhileLocked)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        engineId?.let { outState.putString(ENGINE_ID, it) }
    }

    override fun onDestroy() {
        val leaving = leavingForGood
        super.onDestroy()
        val id = engineId ?: return
        if (leaving) {
            FlutterEngineCache.getInstance().get(id)?.destroy()
            FlutterEngineCache.getInstance().remove(id)
            KeptEngines.forget(id)
        }
    }

    private val leavingForGood: Boolean
        get() = isFinishing && !isChangingConfigurations

    override fun getCachedEngineId(): String? = engineId

    override fun shouldDestroyEngineWithHost(): Boolean = engineId == null

    private fun keepEngine(id: String) {
        if (FlutterEngineCache.getInstance().contains(id)) return
        // What FlutterFragmentActivity does for an engine of its own: the link
        // that started the app becomes the initial route, and the engine takes
        // the flags of `flutter run`; here only in debuggable builds, since any
        // app can start this activity with extras.
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val args = if (debuggable) FlutterShellArgs.fromIntent(intent).toArray() else null
        val engine = FlutterEngine(applicationContext, args)
        val link = intent.data?.takeIf { shouldHandleDeeplinking() }?.toString()
        engine.navigationChannel.setInitialRoute(link ?: "/")
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(id, engine)
    }

    internal fun applyWindowState() {
        val windowState = engineState.window
        if (windowState.secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        val recents = windowState.recentsScreenshotEnabled
        if (recents != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(recents)
        }
        backWhileLocked.isEnabled = windowState.backMovesTaskToBack
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
        device = DeviceChannel(applicationContext, messenger, engineState.window, this)
        applyWindowState()
        shareInbox = ShareInbox(applicationContext, messenger)
        fileActions = FileActionsChannel(this, messenger, engineState)
        documents = DocumentPickerChannel(this, messenger, engineState)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // A relaunched or recreated activity gets the results of the pick or
        // "save as" still open; one leaving for good answers them with nothing
        // before its engine goes.
        val keepPending = engineId != null && !leavingForGood
        device?.detach()
        device = null
        shareInbox?.detach()
        shareInbox = null
        fileActions?.detach(keepPending)
        fileActions = null
        documents?.detach(keepPending)
        documents = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (fileActions?.onActivityResult(requestCode, resultCode, data) == true) return
        if (documents?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private companion object {
        const val ENGINE_ID = "dev.coderoftime.vikunja.ENGINE_ID"
    }
}
