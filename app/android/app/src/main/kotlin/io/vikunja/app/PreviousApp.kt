package io.vikunja.app

import android.app.LocaleManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.LocaleList
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.work.WorkManager
import io.vikunja.app.widget.LegacyWidgets
import java.io.File
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONException

// What the previous official app, which this app updates on Play, left on
// the device: the first start reads its traces before anything of this app
// writes secure storage, then clears what this app does not share (D83).
internal object PreviousApp {
    // flutter_secure_storage's default file and key prefix, the same in
    // every version the previous app used.
    const val SECURE_PREFERENCES = "FlutterSecureStorage"
    const val SECURE_KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg"

    // flutter_local_notifications' file and key of its scheduled list.
    const val SCHEDULED_NOTIFICATIONS = "scheduled_notifications"
    val CHANNELS = listOf("Vikunja1", "Vikunja2")
    val UNIQUE_WORK = listOf("update-tasks", "refresh-token", "home_widget_background")
    const val WORK_TAG = "BackgroundDownloader"
    val PREFERENCE_FILES = listOf("HomeWidgetPreferences", "InternalHomeWidgetPreferences")
    const val DOWNLOADER_KEY_PREFIX = "com.bbflight.background_downloader"

    // The language tags of shippedLocales in app/lib/app/l10n/shipped_locales.dart;
    // app/test/l10n/shipped_locales_test.dart keeps them equal.
    val LANGUAGES = setOf("en", "de")

    private const val TAG = "Vikunja"
    private const val WORK_WAIT_SECONDS = 2L

    fun secureEntryCount(keys: Collection<String>): Int = keys.count { it.startsWith(SECURE_KEY_PREFIX) }

    // Text that is no JSON list still counts: only a stored empty list
    // proves there is nothing.
    fun hasScheduledNotifications(stored: String?): Boolean {
        if (stored.isNullOrBlank()) return false
        return try {
            JSONArray(stored).length() > 0
        } catch (_: JSONException) {
            true
        }
    }

    fun downloaderKeys(keys: Collection<String>): List<String> = keys.filter { it.startsWith(DOWNLOADER_KEY_PREFIX) }

    fun appLanguage(value: String?): String? = value?.takeIf { it in LANGUAGES }

    fun traces(context: Context): Map<String, Any> = linkedMapOf(
        "secureEntries" to read(0) {
            secureEntryCount(context.getSharedPreferences(SECURE_PREFERENCES, Context.MODE_PRIVATE).all.keys)
        },
        "legacyChannels" to read(false) {
            val notifications = NotificationManagerCompat.from(context)
            CHANNELS.any { notifications.getNotificationChannel(it) != null }
        },
        "legacyWidgets" to read(0) {
            AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, LegacyWidgets.RECEIVER)).size
        },
        // The file, not getSharedPreferences, which would keep an instance
        // of it in memory.
        "homeWidgetData" to read(false) {
            File(context.applicationInfo.dataDir, "shared_prefs/HomeWidgetPreferences.xml").exists()
        },
        "scheduledNotifications" to read(false) {
            hasScheduledNotifications(
                context.getSharedPreferences(SCHEDULED_NOTIFICATIONS, Context.MODE_PRIVATE)
                    .getString(SCHEDULED_NOTIFICATIONS, null),
            )
        },
    )

    // Dart cancels the previous app's alarms before this: a firing one would
    // create its channel again.
    fun clear(context: Context) {
        step {
            val work = WorkManager.getInstance(context)
            val cancels = UNIQUE_WORK.map(work::cancelUniqueWork) + work.cancelAllWorkByTag(WORK_TAG)
            // WorkManager cancels on a thread of its own. The cleanup runs
            // only until this start's purge marks the install, so it waits.
            for (cancel in cancels) cancel.result.get(WORK_WAIT_SECONDS, TimeUnit.SECONDS)
        }
        step {
            val notifications = NotificationManagerCompat.from(context)
            CHANNELS.forEach(notifications::deleteNotificationChannel)
        }
        for (name in PREFERENCE_FILES) {
            step {
                if (!context.deleteSharedPreferences(name)) Log.w(TAG, "A preference file of the previous app stays")
            }
        }
        step {
            val preferences = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
            val keys = downloaderKeys(preferences.all.keys)
            // An empty write would create the file.
            if (keys.isNotEmpty()) {
                val editor = preferences.edit()
                keys.forEach(editor::remove)
                if (!editor.commit()) Log.w(TAG, "The previous app's download state stays")
            }
        }
        LegacyWidgets.disableIfUnused(context)
    }

    fun setAppLanguage(context: Context, language: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        val tag = appLanguage(language) ?: return false
        return try {
            val locales = context.getSystemService(LocaleManager::class.java)
            if (!locales.applicationLocales.isEmpty) return false
            locales.applicationLocales = LocaleList.forLanguageTags(tag)
            true
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not set the app language: ${error.javaClass.simpleName}")
            false
        }
    }

    private inline fun <T : Any> read(fallback: T, block: () -> T): T = try {
        block()
    } catch (error: Exception) {
        Log.w(TAG, "Could not read a trace of the previous app: ${error.javaClass.simpleName}")
        fallback
    }

    private inline fun step(block: () -> Unit) {
        try {
            block()
        } catch (error: Exception) {
            Log.w(TAG, "Could not clear a leftover of the previous app: ${error.javaClass.simpleName}")
        }
    }
}
