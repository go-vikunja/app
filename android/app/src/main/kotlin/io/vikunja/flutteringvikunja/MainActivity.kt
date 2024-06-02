package io.vikunja.flutteringvikunja

import android.content.Intent
import android.content.Intent.getIntent
import android.os.Bundle
import io.flutter.plugins.GeneratedPluginRegistrant

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private var launchMethod: String? = null
    private var sharedText: String? = null
    private val CHANNEL = "vikunja"

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.e("TAG","test");
        super.onCreate(savedInstanceState);
    }

    override fun onNewIntent(intent: Intent) {
        handleIntent(intent, flutterEngine!!, true);
        super.onResume()
    }

    private fun handleIntent(intent: Intent, flutterEngine: FlutterEngine, isNewIntent: Boolean) {
        val action: String? = intent.action
        val type: String? = intent.type
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        sharedText = intent.getStringExtra(Intent.EXTRA_TEXT);

        if ("ACTION_INSERT" == action && type != null && "ADD_NEW_TASK" == type) {
            if(isNewIntent)
                channel.invokeMethod("open_add_task", "")
            launchMethod = "open_add_task";
        } else if (Intent.ACTION_SEND == action && type != null && "text/plain" == type && sharedText != null) {
            if(isNewIntent)
                channel.invokeMethod("open_add_task_with_text", "$sharedText")
            launchMethod = "open_add_task_with_text"
        }

    }


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handleIntent(intent, flutterEngine, false)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler {
            call, result ->
            if (call.method!!.contentEquals("isQuickTile")) {
                val list: MutableList<String> = mutableListOf<String>();
                if(launchMethod != null) {
                    list.add(launchMethod.toString());
                }
                if (sharedText != null) {
                    list.add(sharedText.toString());
                }
                if(list.size > 0) {
                    result.success(list);
                } else {
                    result.error("UNAVAILABLE", "No Quick Tile", null);
                }

                launchMethod = null
                sharedText = null
            }
        }
    }

    fun handleSendText(intent: Intent) {
        //sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
    }

}
