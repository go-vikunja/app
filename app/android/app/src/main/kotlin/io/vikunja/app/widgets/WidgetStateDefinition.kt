package io.vikunja.app.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.datastore.core.DataStore
import androidx.glance.state.GlanceStateDefinition
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext

// A running Glance session reads its state again on every update, but runs
// provideGlance only once; reading the app's files here is what makes a new
// snapshot show at once.
internal class FileWidgetStateDefinition<T>(
    private val load: (Context, Int) -> T,
) : GlanceStateDefinition<T> {
    override suspend fun getDataStore(context: Context, fileKey: String): DataStore<T> =
        FileWidgetState(context.applicationContext, appWidgetIdOf(fileKey), load)

    // Glance deletes this file when the widget is removed, so the instance's
    // config goes with it.
    override fun getLocation(context: Context, fileKey: String): File =
        WidgetFiles.of(context).config(appWidgetIdOf(fileKey))

    private fun appWidgetIdOf(fileKey: String): Int =
        fileKey.substringAfter(SESSION_KEY_PREFIX).toIntOrNull() ?: AppWidgetManager.INVALID_APPWIDGET_ID

    private companion object {
        const val SESSION_KEY_PREFIX = "appWidget-"
    }
}

private class FileWidgetState<T>(
    private val context: Context,
    private val appWidgetId: Int,
    private val load: (Context, Int) -> T,
) : DataStore<T> {
    override val data: Flow<T> = flow { emit(withContext(Dispatchers.IO) { load(context, appWidgetId) }) }

    // Only the app writes the files; there is nothing to store here.
    override suspend fun updateData(transform: suspend (t: T) -> T): T = transform(data.first())
}
