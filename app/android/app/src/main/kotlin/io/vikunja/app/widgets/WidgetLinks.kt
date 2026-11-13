package io.vikunja.app.widgets

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.vikunja.app.MainActivity
import java.net.URLEncoder

// The app's widget links (app/lib/core/links/widget_link.dart). They go to
// MainActivity in the app's own task, like the hop in TaskLinkActivity, and
// Flutter's deep linking hands them to the app. The links built here carry
// the widget-link key from host.json as k (none before the app wrote it),
// so the app tells them from a forged link that may not switch accounts.
internal object WidgetLinks {
    private const val SCHEME = "vikunja-io.vikunja.app"
    private const val HOST = "widget"

    fun configure(appWidgetId: Int, key: String?): Uri = Uri.parse(configureLink(appWidgetId, key))

    fun newTask(accountId: String?, key: String?): Uri = Uri.parse(newTaskLink(accountId, key))

    fun open(accountId: String?, key: String?): Uri = Uri.parse(openLink(accountId, key))

    fun configureLink(appWidgetId: Int, key: String?): String =
        link("configure", "appWidgetId" to appWidgetId.toString(), key = key)

    fun newTaskLink(accountId: String?, key: String?): String = link("new-task", "account" to accountId, key = key)

    fun openLink(accountId: String?, key: String?): String = link("open", "account" to accountId, key = key)

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

    private fun link(action: String, vararg query: Pair<String, String?>, key: String?): String {
        val parameters = (query.toList() + ("k" to key)).mapNotNull { (name, value) ->
            value?.let { "$name=${URLEncoder.encode(it, "UTF-8")}" }
        }
        val base = "$SCHEME://$HOST/$action"
        return if (parameters.isEmpty()) base else parameters.joinToString("&", prefix = "$base?")
    }
}
