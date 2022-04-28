package io.vikunja.flutteringvikunja


import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class VikunjaTileService : TileService(){

    override fun onClick() {
        super.onClick()
        Log.e("VIKUNJA","Clicked")
        val addIntent = Intent(this,MainActivity::class.java)
        addIntent.action = "ACTION_INSERT"
        addIntent.type = "ADD_NEW_TASK"
        addIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivityAndCollapse(addIntent)

        // Called when the user click the tile
    }


    override fun onTileRemoved() {
        super.onTileRemoved()

        // Do something when the user removes the Tile
    }

    override fun onTileAdded() {
        super.onTileAdded()

        // Do something when the user add the Tile
    }

    override fun onStartListening() {
        super.onStartListening()

        // Called when the Tile becomes visible
    }

    override fun onStopListening() {
        super.onStopListening()

        // Called when the tile is no longer visible
    }
}