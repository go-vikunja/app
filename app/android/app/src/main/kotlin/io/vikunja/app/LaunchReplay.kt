package io.vikunja.app

import android.content.Intent
import android.os.Bundle

internal object LaunchReplay {
    fun isReplay(flags: Int, restored: Boolean, relaunchedForConfigChange: Boolean): Boolean =
        flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0 || restored && !relaunchedForConfigChange

    fun withoutLaunch(intent: Intent): Intent = Intent(intent)
        .setAction(Intent.ACTION_MAIN)
        .replaceExtras(Bundle())
        .setData(null)
        .also { it.clipData = null }
}
