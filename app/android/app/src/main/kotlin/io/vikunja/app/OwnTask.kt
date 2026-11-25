package io.vikunja.app

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build

// Another app's activity that starts MainActivity without NEW_TASK puts it,
// and a second engine on the same data, into that app's task (R33), where the
// other app sits below the app's screens. Such a start goes to the app's own
// task instead. Not singleTask, which would clear the browser sign-in's custom
// tab whenever the launcher brings the app back.
//
// In the app's own task, Android also adds a second MainActivity above a
// picker, an opened attachment or a settings page when the start's intent
// differs from the one that started the task (a reminder tap, a shortcut, or
// the app icon after a reminder started the app). That copy hands its intent
// to the first one, or for the app icon just goes, so the task comes back as
// it was.
internal object OwnTask {
    const val FLAGS =
        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP

    data class Plan(val finishFirst: Boolean, val restart: Boolean)

    enum class Start(val plan: Plan?) {
        OWN(null),
        ANOTHER_TASK(Plan(finishFirst = false, restart = true)),

        // The restart's CLEAR_TOP takes the topmost MainActivity that is not
        // finishing, which would otherwise be this copy.
        AGAIN(Plan(finishFirst = true, restart = true)),
        AGAIN_FROM_LAUNCHER(Plan(finishFirst = true, restart = false)),
    }

    fun start(
        isTaskRoot: Boolean,
        flags: Int,
        restored: Boolean,
        launcher: Boolean,
        rootIsMainActivity: () -> Boolean,
    ): Start = when {
        isTaskRoot -> Start.OWN
        !restored && rootIsMainActivity() -> if (launcher) Start.AGAIN_FROM_LAUNCHER else Start.AGAIN
        flags and Intent.FLAG_ACTIVITY_NEW_TASK == 0 -> Start.ANOTHER_TASK
        else -> Start.OWN
    }

    // The restart carries the caller's extras; the fragment that the
    // activity's onCreate adds on the way out gets an engine of its own from
    // the activity's intent, and that one gets none of them.
    fun <I> handOver(
        plan: Plan,
        intent: I,
        finish: () -> Unit,
        restart: (I) -> I,
        start: (I) -> Unit,
        withoutExtras: (I) -> I,
        setIntent: (I) -> Unit,
        create: () -> Unit,
    ) {
        if (plan.finishFirst) finish()
        if (plan.restart) start(restart(intent))
        setIntent(withoutExtras(intent))
        create()
        finish()
    }

    fun isLauncherStart(action: String?, categories: Set<String>?): Boolean =
        action == Intent.ACTION_MAIN && categories?.contains(Intent.CATEGORY_LAUNCHER) == true

    fun rootIsMainActivity(activity: Activity): Boolean {
        val tasks = activity.getSystemService(ActivityManager::class.java)?.appTasks ?: return false
        return tasks.any { task ->
            val info = try {
                task.taskInfo
            } catch (_: IllegalArgumentException) {
                null
            }
            info != null && idOf(info) == activity.taskId &&
                info.baseActivity?.className == MainActivity::class.java.name
        }
    }

    fun restart(context: Context, intent: Intent): Intent =
        Intent(intent).setClass(context, MainActivity::class.java).setFlags(FLAGS).also { it.selector = null }

    private fun idOf(info: ActivityManager.RecentTaskInfo): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) info.taskId else @Suppress("DEPRECATION") info.id
}
