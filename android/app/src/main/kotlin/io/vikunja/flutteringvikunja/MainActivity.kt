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
    private var isQuickTile: Boolean? = false
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
        Log.e("VIKUNJA", "Action: $action")
        Log.e("VIKUNJA", "Type: $type")
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        if ("ACTION_INSERT" == action && type != null && "ADD_NEW_TASK" == type) {
            Log.e("VIKUNJA","Is ACTION_INSERT");
            if(isNewIntent)
                channel.invokeMethod("open_add_task", "")
            isQuickTile = true;
        }
        else {
            isQuickTile = false;
        }
    }


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handleIntent(intent, flutterEngine, false)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler {
            call, result ->
            if (call.method!!.contentEquals("isQuickTile")) {
                result.success(isQuickTile)
            }
        }
    }

    fun handleSendText(intent: Intent) {
        //sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
    }

}
