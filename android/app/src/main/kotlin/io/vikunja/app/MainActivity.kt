package io.vikunja.app

import android.content.Intent
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * App not open:
 *  - After click on tile, share or a widget task row onCreate is called
 *  - Then configureFlutterEngine is called.
 *    This the the launch method for later and registers a method channel
 *  - After that "isQuickTile" is called from flutter code to check
 *    if the launch method was set and if parameter were passed
 *  - If so the add task dialog is shown or the tapped task opened
 *
 * App open:
 *  - When the flutter application start a method channel is registered
 *  - After click on tile, share or a widget task row onCreate is called
 *  - Then onNewIntent is called.
 *  - This register a method channel and direclty calles flutter code
 *    to show the add taks dialog or open the tapped task
 *
 */
class MainActivity : FlutterActivity() {
    private var launchMethod: String? = null
    private var launchArgument: String? = null
    private val CHANNEL = "vikunja"

    override fun onNewIntent(intent: Intent) {
        callFlutterCode(intent, flutterEngine!!);
        super.onNewIntent(intent)
    }

    private fun callFlutterCode(intent: Intent, flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        when (intent.action) {
            Intent.ACTION_INSERT -> when {
                isOpenTaskIntent(intent) -> {
                    val taskId = taskIDFromIntent(intent)
                    Log.d("VikunjaWidget", "onNewIntent open_task taskId=$taskId")
                    channel.invokeMethod("open_task", taskId)
                }
                INTENT_TYPE_ADD_TASK == intent.type ->
                    channel.invokeMethod("open_add_task", "")
            }

            Intent.ACTION_SEND if "text/plain" == intent.type -> {
                channel.invokeMethod("open_add_task", intent.getStringExtra(Intent.EXTRA_TEXT))
            }

            else -> {
            }
        }
    }

    private fun isOpenTaskIntent(intent: Intent): Boolean {
        // The widget row action carries vikunja-app://openTask?taskID=N as its
        // data URI. Match on the URI first: Intent.setData() clears the MIME
        // type, so the OPEN_TASK type flag does not survive the trip.
        return INTENT_TYPE_OPEN_TASK == intent.type ||
            intent.data?.host == "openTask"
    }

    private fun taskIDFromIntent(intent: Intent): String? {
        // The widget sends the id as an extra and in the data URI; prefer the
        // extra, fall back to the URI if extras were dropped.
        return intent.getStringExtra(EXTRA_TASK_ID)
            ?: intent.data?.getQueryParameter("taskID")
    }


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setLaunchMethod(intent)

        registerMethodChannel(flutterEngine)
    }

    private fun setLaunchMethod(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_INSERT -> when {
                isOpenTaskIntent(intent) -> {
                    launchMethod = "open_task"
                    launchArgument = taskIDFromIntent(intent)
                }
                INTENT_TYPE_ADD_TASK == intent.type ->
                    launchMethod = "open_add_task"
            }

            Intent.ACTION_SEND if "text/plain" == intent.type -> {
                launchMethod = "open_add_task"
                launchArgument = intent.getStringExtra(Intent.EXTRA_TEXT)
            }

            else -> {
            }
        }

        Log.d(
            "VikunjaWidget",
            "cold start launch: action=${intent.action} type=${intent.type} " +
                "method=$launchMethod argument=$launchArgument data=${intent.data}"
        )
    }

    private fun registerMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method?.contentEquals("isQuickTile") == true) {
                val method = launchMethod
                Log.d(
                    "VikunjaWidget",
                    "isQuickTile poll: method=$method argument=$launchArgument"
                )
                if (method != null) {
                    result.success(mapOf("method" to method, "argument" to launchArgument))
                } else {
                    result.error("1", null, null)
                }

                launchMethod = null
                launchArgument = null
            }
        }
    }
}
