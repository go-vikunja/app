package dev.coderoftime.rurana

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID

// Files other apps hand over by content URI, for shares and the document
// picker: what the provider says about them, and copies capped at a size,
// read in small pieces. Both run on a background thread; neither logs
// anything about the file.

class TooLargeException : IOException()

fun describeContent(resolver: ContentResolver, uri: Uri): Map<String, Any?> {
    var name: String? = null
    var size: Long? = null
    try {
        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameColumn >= 0 && !cursor.isNull(nameColumn)) {
                    name = cursor.getString(nameColumn)
                }
                val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) {
                    size = cursor.getLong(sizeColumn).takeIf { it >= 0 }
                }
            }
        }
    } catch (_: Exception) {
        // A provider that refuses the query still serves the bytes.
    }
    val mime = try {
        resolver.getType(uri)
    } catch (_: Exception) {
        null
    }
    return mapOf(
        "uri" to uri.toString(),
        "name" to (name ?: ""),
        "size" to size,
        "mime" to mime,
    )
}

// Returns the bytes copied; throws TooLargeException past maxBytes. A
// failed copy leaves nothing behind.
fun copyCapped(resolver: ContentResolver, uri: Uri, target: File, maxBytes: Long): Long {
    try {
        var copied = 0L
        val input = resolver.openInputStream(uri) ?: throw IOException("no stream")
        input.use { source ->
            FileOutputStream(target).use { sink ->
                val buffer = ByteArray(COPY_BUFFER_BYTES)
                while (true) {
                    val read = source.read(buffer)
                    if (read < 0) break
                    copied += read
                    if (copied > maxBytes) throw TooLargeException()
                    sink.write(buffer, 0, read)
                }
            }
        }
        return copied
    } catch (error: Exception) {
        target.delete()
        throw error
    }
}

fun randomFileName(): String = UUID.randomUUID().toString().replace("-", "")

// Every file in the directory, or only the ones older than olderThanMillis.
fun purgeFiles(directory: File, olderThanMillis: Long = 0) {
    val cutoff = System.currentTimeMillis() - olderThanMillis
    directory.listFiles()?.forEach { file ->
        if (olderThanMillis == 0L || file.lastModified() < cutoff) file.delete()
    }
}

private const val COPY_BUFFER_BYTES = 64 * 1024
