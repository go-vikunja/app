package io.vikunja.app

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import androidx.activity.OnBackPressedCallback
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
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
    private var throwaway = false

    // On while the app lock is up, when Flutter leaves back to the platform:
    // Android would otherwise close the activity, and the app's state with
    // it, whenever the task was not started from the launcher.
    private val backWhileLocked = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            moveTaskToBack(true)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val start = OwnTask.start(
            isTaskRoot = isTaskRoot,
            flags = intent.flags,
            restored = savedInstanceState != null,
            launcher = OwnTask.isLauncherStart(intent.action, intent.categories),
        ) { OwnTask.rootIsMainActivity(this) }
        start.plan?.let { plan ->
            throwaway = true
            // Nothing restored and no kept engine: the fragment this adds gets
            // an engine of its own on the way out, which never runs Dart.
            OwnTask.handOver(
                plan = plan,
                intent = intent,
                finish = ::finish,
                restart = { OwnTask.restart(this, it) },
                start = ::startActivity,
                withoutExtras = LaunchExtras::dropped,
                setIntent = { intent = it },
                create = { super.onCreate(null) },
            )
            return
        }
        // Before super: a restored FlutterFragment looks its engine up at once.
        // A state saved before engines were kept restores a fragment with an
        // engine of its own.
        engineId = if (savedInstanceState == null) KeptEngines.newId() else savedInstanceState.getString(ENGINE_ID)
        val engineKept = engineId?.let { FlutterEngineCache.getInstance().contains(it) } == true
        engineId?.let { engineState = KeptEngines.state(it) }
        val launch = intent
        // Reopened from Recents, or restored after Android ended the process or
        // destroyed the activity, the activity gets the intent that started its
        // task once more: flutter_local_notifications would report that
        // notification tap again, quick_actions that home screen shortcut,
        // Flutter's deep linking would open that task link, and a share would
        // be offered again. A new tap, shortcut or link that restores the
        // activity comes through onNewIntent. A relaunch for a configuration
        // change keeps the intent: the engine carries on, its plugins only
        // reattach, and Dart may not have read the notification tap yet.
        val restored = savedInstanceState != null
        if (LaunchReplay.isReplay(intent.flags, restored, engineKept && engineState.relaunching)) {
            intent = LaunchReplay.withoutLaunch(intent)
        } else if (!restored && intent.action == ShareInbox.ACTION_SHARE) {
            ShareInbox.receive(this, intent)
            intent = ShareInbox.withoutShare(intent)
        }
        engineId?.let { keepEngine(it, launch) }
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
        } else {
            engineState.relaunching = isChangingConfigurations
        }
    }

    private val leavingForGood: Boolean
        get() = isFinishing && !isChangingConfigurations

    override fun getCachedEngineId(): String? = engineId

    override fun shouldDestroyEngineWithHost(): Boolean = engineId == null

    private fun keepEngine(id: String, launch: Intent) {
        if (FlutterEngineCache.getInstance().contains(id)) return
        // What FlutterFragmentActivity does for an engine of its own: the link
        // that started the app becomes the initial route, and the engine takes
        // the flags of `flutter run`, on a restore too, from the intent as it
        // came; here only in debuggable builds, since any app can start this
        // activity with extras.
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val args = if (debuggable) FlutterShellArgs.fromIntent(launch).toArray() else null
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

    override fun shouldAttachEngineToActivity(): Boolean = !throwaway

    override fun getBackgroundMode(): BackgroundMode = LaunchExtras.backgroundMode

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (throwaway) return
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
        const val ENGINE_ID = "io.vikunja.app.ENGINE_ID"
    }
}
