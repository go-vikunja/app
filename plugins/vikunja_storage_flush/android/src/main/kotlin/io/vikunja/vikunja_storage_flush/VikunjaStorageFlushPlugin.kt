package io.vikunja.vikunja_storage_flush

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/**
 * Registered on every engine, the background ones included. An empty commit()
 * while an apply() is pending writes the file's current state at once and
 * waits for it, through the process-wide SharedPreferences instance of that
 * file; commit() writes the file, so the channel runs on a background queue.
 */
class VikunjaStorageFlushPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
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
        if (call.method != "flushSharedPreferences") {
            result.notImplemented()
            return
        }
        val name = call.argument<String>("name")
        if (name == null) {
            result.error("argument", "name is missing", null)
            return
        }
        val written = context.getSharedPreferences(name, Context.MODE_PRIVATE).edit().commit()
        if (written) result.success(null) else result.error("io", "could not write $name", null)
    }

    private companion object {
        const val CHANNEL = "io.vikunja.vikunja_storage_flush"
    }
}
