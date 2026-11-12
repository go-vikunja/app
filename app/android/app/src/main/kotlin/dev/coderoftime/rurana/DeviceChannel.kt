package dev.coderoftime.rurana

import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// The engine outlives the activity, so the channel stays registered after
// detach: what Dart sets on the window until the next activity shows the
// engine is kept for that one instead of reaching a destroyed activity.
internal class DeviceChannel(
    private val context: Context,
    messenger: BinaryMessenger,
    private val windowState: WindowState,
    private var activity: MainActivity?,
) : MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    fun detach() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "osVersion" -> result.success(Build.VERSION.RELEASE)
            "copySensitive" -> copySensitive(call.argument<String>("text"), result)
            "setSecure" -> setSecure(call.argument<Boolean>("secure"), result)
            "setRecentsScreenshotEnabled" ->
                setRecentsScreenshot(call.argument<Boolean>("enabled"), result)
            "moveTaskToBack" -> result.success(activity?.moveTaskToBack(true) ?: false)
            "setBackMovesTaskToBack" ->
                setBackMovesTaskToBack(call.argument<Boolean>("enabled"), result)
            "canOpenAppLocaleSettings" -> result.success(canOpenAppLocaleSettings())
            "openAppLocaleSettings" -> result.success(openAppLocaleSettings())
            "removeLocation" -> removeLocation(call.argument<String>("path"), result)
            "backgroundState" -> result.success(backgroundState())
            else -> result.notImplemented()
        }
    }

    private fun copySensitive(text: String?, result: MethodChannel.Result) {
        if (text == null) {
            result.error("invalid_arguments", "text is missing", null)
            return
        }
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply { putBoolean(EXTRA_IS_SENSITIVE, true) }
        context.getSystemService(ClipboardManager::class.java).setPrimaryClip(clip)
        result.success(null)
    }

    private fun setSecure(secure: Boolean?, result: MethodChannel.Result) {
        if (secure == null) {
            result.error("invalid_arguments", "secure is missing", null)
            return
        }
        windowState.secure = secure
        activity?.applyWindowState()
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
        windowState.recentsScreenshotEnabled = enabled
        activity?.applyWindowState()
        result.success(true)
    }

    private fun setBackMovesTaskToBack(enabled: Boolean?, result: MethodChannel.Result) {
        if (enabled == null) {
            result.error("invalid_arguments", "enabled is missing", null)
            return
        }
        windowState.backMovesTaskToBack = enabled
        activity?.applyWindowState()
        result.success(null)
    }

    // Dart waits for the answer, so it comes whatever goes wrong.
    private fun removeLocation(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("invalid_arguments", "path is missing", null)
            return
        }
        removals.execute {
            val failure = LocationRemoval.failureOf { LocationRemoval.removeFrom(File(path)) }
            main.post {
                if (failure == null) {
                    result.success(null)
                } else {
                    // The reason goes to Dart, whose log keeps it.
                    Log.w(TAG, "A location stays in a file")
                    result.error("remove_location_failed", failure, null)
                }
            }
        }
    }

    private fun canOpenAppLocaleSettings(): Boolean =
        AppLocaleSettings.canOpen(Build.VERSION.SDK_INT) {
            AppLocaleSettings.intent(context.packageName)
                .resolveActivity(context.packageManager) != null
        }

    private fun openAppLocaleSettings(): Boolean {
        val activity = activity ?: return false
        if (!AppLocaleSettings.supported(Build.VERSION.SDK_INT)) return false
        return try {
            activity.startActivity(AppLocaleSettings.intent(activity.packageName))
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    private fun backgroundState(): Map<String, Any> {
        val reads = linkedMapOf<String, () -> Any>(
            "ignoresBatteryOptimizations" to {
                service<PowerManager>().isIgnoringBatteryOptimizations(context.packageName)
            },
            "powerSaveMode" to { service<PowerManager>().isPowerSaveMode },
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            reads["backgroundRestricted"] = { service<ActivityManager>().isBackgroundRestricted }
            reads["standbyBucket"] = {
                BackgroundState.bucketName(service<UsageStatsManager>().appStandbyBucket)
            }
        }
        return BackgroundState.collect(reads)
    }

    private inline fun <reified T : Any> service(): T = context.getSystemService(T::class.java)

    private companion object {
        const val CHANNEL = "dev.coderoftime.rurana/device"
        const val TAG = "Rurana"

        val removals = Executors.newSingleThreadExecutor()

        // ClipDescription.EXTRA_IS_SENSITIVE from API 33; Android 13 hides the
        // clipboard preview of a clip marked with it, older versions ignore it.
        const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }
}
