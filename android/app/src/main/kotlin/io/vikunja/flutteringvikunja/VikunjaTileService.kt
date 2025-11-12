package io.vikunja.flutteringvikunja


import android.content.Intent
import android.app.PendingIntent
import android.os.Build
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi

const val INTENT_TYPE_ADD_TASK = "ADD_NEW_TASK"

@RequiresApi(Build.VERSION_CODES.N)
class VikunjaTileService : TileService(){

    override fun onClick() {
        super.onClick()
        val addIntent = Intent(this,MainActivity::class.java)
        addIntent.action = Intent.ACTION_INSERT
        addIntent.type = INTENT_TYPE_ADD_TASK

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this,
                    0,
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        } else {
            startActivityAndCollapse(addIntent)
        }
    }
}