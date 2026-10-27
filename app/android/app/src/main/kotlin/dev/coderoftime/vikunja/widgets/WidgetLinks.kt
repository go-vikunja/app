package dev.coderoftime.vikunja.widgets

import android.content.Context
import android.content.Intent
import android.net.Uri
import dev.coderoftime.vikunja.MainActivity

// The app's widget links (app/lib/core/links/widget_link.dart). They go to
// MainActivity in the app's own task, like the hop in TaskLinkActivity, and
// Flutter's deep linking hands them to the app.
internal object WidgetLinks {
    private const val SCHEME = "vikunja-dev.coderoftime.vikunja"
    private const val HOST = "widget"

    fun configure(appWidgetId: Int): Uri = Uri.parse(configureLink(appWidgetId))

    fun configureLink(appWidgetId: Int): String = "$SCHEME://$HOST/configure?appWidgetId=$appWidgetId"

    fun newTask(accountId: String?): Uri =
        base("new-task").apply { if (accountId != null) appendQueryParameter("account", accountId) }.build()

    fun open(accountId: String?): Uri =
        base("open").apply { if (accountId != null) appendQueryParameter("account", accountId) }.build()

    // Only the app's own widget links from a snapshot are opened.
    fun parse(link: String?): Uri? {
        val uri = link?.let(Uri::parse) ?: return null
        return uri.takeIf { it.scheme == SCHEME && it.host == HOST }
    }

    fun intent(context: Context, uri: Uri): Intent = Intent(context, MainActivity::class.java)
        .setAction(Intent.ACTION_VIEW)
        .setData(uri)
        .addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
        )

    private fun base(action: String): Uri.Builder = Uri.Builder().scheme(SCHEME).authority(HOST).appendPath(action)
}
