package io.vikunja.app

import android.content.Context
import android.content.Intent

// Another app's activity that starts MainActivity without NEW_TASK puts it,
// and a second engine on the same data, into that app's task (R33), where the
// other app sits below the app's screens. Such a start goes to the app's own
// task instead. Not singleTask, which would clear the browser sign-in's custom
// tab whenever the launcher brings the app back.
internal object OwnTask {
    const val FLAGS =
        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP

    fun startedInAnotherTask(isTaskRoot: Boolean, flags: Int): Boolean =
        !isTaskRoot && flags and Intent.FLAG_ACTIVITY_NEW_TASK == 0

    fun restart(context: Context, intent: Intent): Intent =
        Intent(intent).setClass(context, MainActivity::class.java).setFlags(FLAGS).also { it.selector = null }
}
