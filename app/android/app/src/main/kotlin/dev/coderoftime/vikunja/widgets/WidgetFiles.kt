package dev.coderoftime.vikunja.widgets

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

// The layout shared with the app (plugins/rurana_widgets): the app writes
// snapshots, configs and host.json; Kotlin writes only the action queue and
// its own pending file.
internal class WidgetFiles(private val filesDir: File) {
    private val root = File(filesDir, "widgets")

    val host: File get() = File(root, "host.json")
    val pending: File get() = File(root, "android-pending.json")
    val queue: File get() = File(filesDir, QUEUE_NAME)

    fun snapshot(key: String): File? = if (keyPattern.matches(key)) File(root, "snapshots/$key.json") else null

    fun config(appWidgetId: Int): File = File(root, "configs/$appWidgetId.json")

    fun claimedQueues(): List<File> =
        filesDir.listFiles { _, name -> name.startsWith("widget_actions.") && name.endsWith(".claimed") }
            ?.toList()
            .orEmpty()

    fun readConfig(appWidgetId: Int): InstanceConfig? = config(appWidgetId).readTextOrNull()?.let(InstanceConfig::parse)

    fun readHost(): HostSettings? = host.readTextOrNull()?.let(HostSettings::parse)

    fun readSnapshot(key: String): Snapshot? = snapshot(key)?.readTextOrNull()?.let(Snapshot::parse)

    // Android 12+ places a list widget without its configuration step; it
    // shows the active account's Today list until configured (the plugin's
    // defaultSnapshotKey).
    fun defaultListKey(host: HostSettings?): String? = host?.activeAccountId?.let { "$it.today" }

    companion object {
        private const val QUEUE_NAME = "widget_actions.jsonl"
        private val keyPattern = Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,159}")

        fun of(context: Context) = WidgetFiles(context.filesDir)
    }
}

internal fun File.readTextOrNull(): String? = try {
    readText()
} catch (_: IOException) {
    null
}

internal fun File.writeAtomically(text: String) {
    val directory = parentFile ?: throw IOException("no directory for $name")
    directory.mkdirs()
    val temporary = File(directory, "$name.tmp")
    FileOutputStream(temporary).use { out ->
        out.write(text.toByteArray())
        out.fd.sync()
    }
    if (!temporary.renameTo(this)) {
        temporary.delete()
        throw IOException("could not replace $name")
    }
}
