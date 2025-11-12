package io.vikunja.flutteringvikunja

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * App not open:
 *  - After click on tile or share onCreate is called
 *  - Then configureFlutterEngine is called.
 *    This the the launch method for later and registers a method channel
 *  - After that "isQuickTile" is called from flutter code to check
 *    if the launch method was set and if parameter were passed
 *  - If so the add task dialog is shown
 *
 * App open:
 *  - When the flutter application start a method channel is registered
 *  - After click on tile or share onCreate is called
 *  - Then onNewIntent is called.
 *  - This register a method channel and direclty calles flutter code
 *    to show the add taks dialog
 *
 */
class MainActivity : FlutterActivity() {
    private var launchMethod: String? = null
    private val CHANNEL = "vikunja"

    override fun onNewIntent(intent: Intent) {
        callFlutterCode(intent, flutterEngine!!);
        super.onNewIntent(intent)
    }

    private fun callFlutterCode(intent: Intent, flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val action: String? = intent.action
        val type: String? = intent.type

        when (action) {
            Intent.ACTION_INSERT -> {
                if (INTENT_TYPE_ADD_TASK == type) {
                    channel.invokeMethod("open_add_task", "")
                }
            }

            Intent.ACTION_SEND if "text/plain" == type -> {
                channel.invokeMethod("open_add_task", intent.getStringExtra(Intent.EXTRA_TEXT))
            }

            else -> {
            }
        }
    }


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setLaunchMethod(intent)

        registerMethodChannel(flutterEngine)
    }

    private fun setLaunchMethod(intent: Intent) {
        val action: String? = intent.action
        val type: String? = intent.type

        when (action) {
            Intent.ACTION_INSERT -> {
                if (INTENT_TYPE_ADD_TASK == type) {
                    launchMethod = "open_add_task"
                }
            }

            Intent.ACTION_SEND if "text/plain" == type -> {
                launchMethod = "open_add_task"
            }

            else -> {
            }
        }
    }

    private fun registerMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method?.contentEquals("isQuickTile") == true) {
                if (launchMethod == "open_add_task") {
                    result.success(intent.getStringExtra(Intent.EXTRA_TEXT))
                } else {
                    result.error("1", null, null)
                }

                launchMethod = null
            }
        }
    }
}
