package dev.coderoftime.vikunja

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.coderoftime.vikunja/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "osVersion" -> result.success(Build.VERSION.RELEASE)
                    else -> result.notImplemented()
                }
            }
    }
}
