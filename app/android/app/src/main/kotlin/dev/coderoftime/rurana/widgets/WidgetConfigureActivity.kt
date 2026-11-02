package dev.coderoftime.rurana.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle

// The launcher's configuration step: accepts the widget at once and opens
// the app's own configuration page, so no second Flutter engine starts in
// the launcher's task (see TaskLinkActivity). Until the user saves there,
// the widget shows the active account's Today list.
class WidgetConfigureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val appWidgetId = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (!isOwnWidget(appWidgetId)) {
            setResult(RESULT_CANCELED)
            finish()
            return
        }
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        if (savedInstanceState == null) {
            // Below Android 12 the host sends no update after this step.
            sendBroadcast(
                Intent(this, TasksWidgetReceiver::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId)),
            )
            val key = WidgetFiles.of(this).readHost()?.linkKey
            startActivity(WidgetLinks.intent(this, WidgetLinks.configure(appWidgetId, key)))
        }
        finish()
    }

    // The activity is exported for the launcher; another app must not get
    // the configuration page opened for an id that is not one of ours.
    private fun isOwnWidget(appWidgetId: Int): Boolean =
        appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID &&
            AppWidgetManager.getInstance(this).getAppWidgetInfo(appWidgetId)?.provider?.packageName == packageName
}
