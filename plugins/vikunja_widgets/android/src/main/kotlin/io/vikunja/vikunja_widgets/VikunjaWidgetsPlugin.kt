package io.vikunja.vikunja_widgets

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/**
 * Registered on every engine (UI, workmanager, notification actions, the
 * widget worker), so each isolate can reach it. File work stays in Dart; the
 * channel runs on a background task queue because it reads the config files.
 */
class VikunjaWidgetsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private lateinit var widgets: WidgetInstances

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        widgets = WidgetInstances(binding.applicationContext)
        val messenger = binding.binaryMessenger
        channel = MethodChannel(
            messenger,
            CHANNEL,
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "directory" -> result.success(directories(widgets.context))
                "configs" -> result.success(widgets.configs())
                "update" -> {
                    widgets.update(call.argument<List<String>>("keys").orEmpty().toSet())
                    result.success(null)
                }
                "updateAll" -> {
                    widgets.updateAll()
                    result.success(null)
                }
                "canRequestPin" -> result.success(widgets.canRequestPin())
                "requestPin" -> result.success(
                    widgets.requestPin(
                        WidgetProviderKind.fromName(call.argument("provider")),
                        call.argument("config"),
                    ),
                )
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            Log.w(TAG, "${call.method} failed: ${error.javaClass.simpleName}")
            result.error("failed", error.javaClass.simpleName, null)
        }
    }

    private fun directories(context: Context): Map<String, String?> = mapOf(
        "widgets" to WidgetInstances.widgetsDir(context).path,
        "files" to context.filesDir.path,
        "appGroup" to null,
    )

    private companion object {
        const val CHANNEL = "io.vikunja.vikunja_widgets"
        const val TAG = "VikunjaWidgets"
    }
}
