package io.vikunja.app

import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ProxySelector
import java.net.URI
import java.security.KeyStore
import java.security.cert.X509Certificate
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
            "openAppSettings" -> result.success(openAppSettings())
            "removeLocation" -> removeLocation(call.argument<String>("path"), result)
            "backgroundState" -> result.success(backgroundState())
            "previousAppTraces" -> offMain(result) { PreviousApp.traces(context) }
            "clearPreviousApp" -> offMain(result) {
                PreviousApp.clear(context)
                null
            }
            "setAppLanguage" -> setAppLanguage(call.argument<String>("language"), result)
            "userCaCertificates" -> offMain(result) { userCaCertificates() }
            "proxyFor" -> offMain(result) { proxyFor(call.argument<String>("url")) }
            "startNativeCrashReports" -> startNativeCrashReports(call, result)
            "stopNativeCrashReports" -> stopNativeCrashReports(result)
            else -> result.notImplemented()
        }
    }

    private fun startNativeCrashReports(call: MethodCall, result: MethodChannel.Result) {
        val dsn = call.argument<String>("dsn")
        val release = call.argument<String>("release")
        val dist = call.argument<String>("dist")
        if (dsn.isNullOrEmpty() || release == null || dist == null) {
            result.error("invalid_arguments", "dsn, release or dist is missing", null)
            return
        }
        crashReportWork.execute {
            val failure = crashReportFailureOf { NativeCrashReports.start(context, dsn, release, dist) }
            // Nothing half-started stays.
            if (failure != null) crashReportFailureOf { NativeCrashReports.stop() }
            main.post {
                if (failure == null) {
                    result.success(null)
                } else {
                    Log.w(TAG, "Could not start the native crash reports: ${failure.javaClass.simpleName}")
                    result.error("unavailable", failure.javaClass.simpleName, null)
                }
            }
        }
    }

    // Closing flushes for up to the SDK's flush timeout.
    private fun stopNativeCrashReports(result: MethodChannel.Result) {
        crashReportWork.execute {
            val failure = crashReportFailureOf { NativeCrashReports.stop() }
            main.post {
                if (failure == null) {
                    result.success(null)
                } else {
                    Log.w(TAG, "Could not stop the native crash reports: ${failure.javaClass.simpleName}")
                    result.error("unavailable", failure.javaClass.simpleName, null)
                }
            }
        }
    }

    // A class the SDK lacks is a LinkageError, which would end the app.
    private fun crashReportFailureOf(work: () -> Unit): Throwable? = try {
        work()
        null
    } catch (error: Exception) {
        error
    } catch (error: LinkageError) {
        error
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

    // Each read and step guards itself, so Dart always gets a result.
    // The CAs the user or a device policy installed, which the network
    // security config trusts for Cronet; the realtime socket's dart:io
    // client gets them from here.
    private fun userCaCertificates(): List<String> = try {
        val store = KeyStore.getInstance("AndroidCAStore").apply { load(null) }
        store.aliases().toList()
            .filter { it.startsWith("user:") }
            .mapNotNull { alias -> (store.getCertificate(alias) as? X509Certificate)?.encoded }
            .map { der ->
                "-----BEGIN CERTIFICATE-----\n" +
                    Base64.encodeToString(der, Base64.DEFAULT) +
                    "-----END CERTIFICATE-----\n"
            }
    } catch (e: Exception) {
        Log.i(TAG, "User CAs not read: ${e.javaClass.simpleName}")
        emptyList()
    }

    // In the form of HttpClient.findProxy: "PROXY host:port; DIRECT".
    private fun proxyFor(url: String?): String {
        val proxies = try {
            ProxySelector.getDefault()?.select(URI(url ?: return "DIRECT"))
        } catch (e: Exception) {
            null
        } ?: return "DIRECT"
        val entries = proxies.mapNotNull { proxy ->
            when (proxy.type()) {
                Proxy.Type.DIRECT -> "DIRECT"
                Proxy.Type.HTTP -> (proxy.address() as? InetSocketAddress)
                    ?.let { "PROXY ${it.hostString}:${it.port}" }
                else -> null
            }
        }
        return entries.ifEmpty { listOf("DIRECT") }.joinToString("; ")
    }

    private fun offMain(result: MethodChannel.Result, work: () -> Any?) {
        previousAppWork.execute {
            val value = work()
            main.post { result.success(value) }
        }
    }

    private fun setAppLanguage(language: String?, result: MethodChannel.Result) {
        if (language == null) {
            result.error("invalid_arguments", "language is missing", null)
            return
        }
        result.success(PreviousApp.setAppLanguage(context, language))
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

    // App info, the way to the app's battery use, where a background
    // restriction is lifted.
    private fun openAppSettings(): Boolean {
        val activity = activity ?: return false
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        )
        return try {
            activity.startActivity(intent)
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
        const val CHANNEL = "io.vikunja.app/device"
        const val TAG = "Vikunja"

        val removals = Executors.newSingleThreadExecutor()
        val previousAppWork = Executors.newSingleThreadExecutor()

        // Not previousAppWork: a stop that flushes for seconds would hold back
        // the network settings a reconnect reads there. One thread keeps start
        // and stop in the order Dart sends them.
        val crashReportWork = Executors.newSingleThreadExecutor { work -> Thread(work, "vikunja-crash-reports") }

        // ClipDescription.EXTRA_IS_SENSITIVE from API 33; Android 13 hides the
        // clipboard preview of a clip marked with it, older versions ignore it.
        const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }
}
