package io.vikunja.app

import android.content.ContentResolver
import android.net.Uri
import android.os.CancellationSignal
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import java.io.File
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

// Files other apps hand over by content URI, for shares and the document
// picker: what the provider says about them, and copies capped at a size,
// read in small pieces. Both run on a background thread; neither logs
// anything about the file.

class TooLargeException : IOException()

// Nothing arrived for the idle limit.
class StalledException : IOException()

class CopyStoppedException : IOException()

fun describeContent(
    resolver: ContentResolver,
    uri: Uri,
    signal: CancellationSignal? = null,
): Map<String, Any?> {
    var name: String? = null
    var size: Long? = null
    try {
        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
            signal,
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

// For a file another app sends, which may never deliver it: [signal]
// calls off the opening, and the copy gives up when nothing arrives for
// idleMillis or once [stopped]; [progressed] is told when the provider has
// opened the file and after each arrival. A failed copy leaves nothing
// behind.
fun copyArriving(
    resolver: ContentResolver,
    uri: Uri,
    target: File,
    maxBytes: Long,
    signal: CancellationSignal,
    idleMillis: Long,
    progressed: () -> Unit,
    stopped: () -> Boolean,
): Long {
    try {
        val descriptor = resolver.openAssetFileDescriptor(uri, "r", signal)
            ?: throw IOException("no descriptor")
        descriptor.use { file ->
            progressed()
            if (stopped()) throw CopyStoppedException()
            val fd = file.fileDescriptor
            return file.createInputStream().use { source ->
                FileOutputStream(target).use { sink ->
                    copyWhileArriving(
                        waitReadable = { millis -> isReadable(fd, millis) },
                        read = { buffer -> source.read(buffer) },
                        sink = sink,
                        maxBytes = maxBytes,
                        idleMillis = idleMillis,
                        stopped = stopped,
                        progressed = progressed,
                    )
                }
            }
        }
    } catch (error: Exception) {
        target.delete()
        throw error
    }
}

// The copy loop of copyArriving: waitReadable waits up to the given
// milliseconds for something to read and says whether it came, read reads
// what is there (-1 at the end). A regular or FUSE descriptor always counts
// as readable, so a read blocked in the kernel is caught only by the
// caller's own watch on [progressed].
internal fun copyWhileArriving(
    waitReadable: (Int) -> Boolean,
    read: (ByteArray) -> Int,
    sink: OutputStream,
    maxBytes: Long,
    idleMillis: Long,
    stopped: () -> Boolean,
    progressed: () -> Unit = {},
    now: () -> Long = { System.nanoTime() / 1_000_000 },
): Long {
    val buffer = ByteArray(COPY_BUFFER_BYTES)
    var copied = 0L
    var lastArrival = now()
    while (true) {
        if (stopped()) throw CopyStoppedException()
        val read = if (waitReadable(WAIT_SLICE_MILLIS)) read(buffer) else 0
        if (read < 0) return copied
        if (read == 0) {
            if (now() - lastArrival >= idleMillis) throw StalledException()
            continue
        }
        lastArrival = now()
        progressed()
        copied += read
        if (copied > maxBytes) throw TooLargeException()
        sink.write(buffer, 0, read)
    }
}

private fun isReadable(fd: FileDescriptor, millis: Int): Boolean {
    val poll = StructPollfd().apply {
        this.fd = fd
        events = OsConstants.POLLIN.toShort()
    }
    return try {
        Os.poll(arrayOf(poll), millis) > 0
    } catch (error: ErrnoException) {
        if (error.errno == OsConstants.EINTR) false else throw IOException(error)
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
private const val WAIT_SLICE_MILLIS = 250
