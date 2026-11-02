package dev.coderoftime.rurana

import android.media.MediaMetadataRetriever
import androidx.exifinterface.media.ExifInterface
import dev.coderoftime.rurana.LocationRemoval.GPS_TAGS
import dev.coderoftime.rurana.LocationRemoval.LocationKept
import dev.coderoftime.rurana.LocationRemoval.Reason
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.BufferUnderflowException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32
import java.util.zip.InflaterInputStream

// Takes the location out of a photo or video in place, the way Android's
// MediaProvider hides it from apps without ACCESS_MEDIA_LOCATION: GPS
// values, GPS in XMP and a video's location boxes are blanked byte for byte
// where they are, after ExifInterface has written a JPEG's, PNG's or WebP's
// Exif again without its GPS tags; no image or video is encoded or muxed
// again. A file without a location is never written to. Where a location
// stays, this throws LocationKept, whose reason never names the file.
internal object LocationRemoval {
    class LocationKept(val reason: Reason) : Exception(reason.text)

    enum class Reason(val text: String) {
        GPS_TAGS("the GPS tags stayed"),
        GPS_TEXT("GPS in PNG text stayed"),
        XMP("GPS in XMP stayed"),
        COMPRESSED_XMP("GPS in compressed XMP"),
        UNREADABLE("some metadata could not be read"),
        XMP_TOO_LARGE("an XMP packet is too large to read"),
        BLOCK_TOO_LARGE("a metadata block is too large to read"),
        VIDEO_KEPT("the video kept a location"),
        VIDEO_ELSEWHERE("the video has a location outside the boxes looked at"),
    }

    val GPS_TAGS = listOf(
        ExifInterface.TAG_GPS_VERSION_ID,
        ExifInterface.TAG_GPS_LATITUDE_REF,
        ExifInterface.TAG_GPS_LATITUDE,
        ExifInterface.TAG_GPS_LONGITUDE_REF,
        ExifInterface.TAG_GPS_LONGITUDE,
        ExifInterface.TAG_GPS_ALTITUDE_REF,
        ExifInterface.TAG_GPS_ALTITUDE,
        ExifInterface.TAG_GPS_TIMESTAMP,
        ExifInterface.TAG_GPS_SATELLITES,
        ExifInterface.TAG_GPS_STATUS,
        ExifInterface.TAG_GPS_MEASURE_MODE,
        ExifInterface.TAG_GPS_DOP,
        ExifInterface.TAG_GPS_SPEED_REF,
        ExifInterface.TAG_GPS_SPEED,
        ExifInterface.TAG_GPS_TRACK_REF,
        ExifInterface.TAG_GPS_TRACK,
        ExifInterface.TAG_GPS_IMG_DIRECTION_REF,
        ExifInterface.TAG_GPS_IMG_DIRECTION,
        ExifInterface.TAG_GPS_MAP_DATUM,
        ExifInterface.TAG_GPS_DEST_LATITUDE_REF,
        ExifInterface.TAG_GPS_DEST_LATITUDE,
        ExifInterface.TAG_GPS_DEST_LONGITUDE_REF,
        ExifInterface.TAG_GPS_DEST_LONGITUDE,
        ExifInterface.TAG_GPS_DEST_BEARING_REF,
        ExifInterface.TAG_GPS_DEST_BEARING,
        ExifInterface.TAG_GPS_DEST_DISTANCE_REF,
        ExifInterface.TAG_GPS_DEST_DISTANCE,
        ExifInterface.TAG_GPS_PROCESSING_METHOD,
        ExifInterface.TAG_GPS_AREA_INFORMATION,
        ExifInterface.TAG_GPS_DATESTAMP,
        ExifInterface.TAG_GPS_DIFFERENTIAL,
        ExifInterface.TAG_GPS_H_POSITIONING_ERROR,
    )

    fun removeFrom(file: File) {
        when (val format = FileFormat.of(head(file))) {
            FileFormat.BOXES -> IsoLocation.removeFrom(file)
            else -> PhotoLocation.removeFrom(file, format)
        }
    }

    // What the device channel answers: nothing, the reason, or an unexpected
    // error's type, whose message could name the file.
    fun failureOf(remove: () -> Unit): String? = try {
        remove()
        null
    } catch (kept: LocationKept) {
        kept.reason.text
    } catch (error: Throwable) {
        error.javaClass.simpleName
    }

    private fun head(file: File): ByteArray = RandomAccessFile(file, "r").use { input ->
        ByteArray(minOf(input.length(), HEAD_BYTES.toLong()).toInt()).also(input::readFully)
    }

    private const val HEAD_BYTES = 64
}

// A photo keeps a location in the GPS IFD of its Exif and in XMP. JPEG, PNG
// and WebP are written again by ExifInterface without the GPS tags. Then, in
// every format, the GPS values left in any Exif are zeroed and GPS in XMP is
// blanked where they are, found by walking the file's own structure:
// ExifInterface's offsets are off for some files, and it reads HEIF only from
// Android 9 and AVIF only from Android 12. It still checks the result.
internal object PhotoLocation {
    private val REWRITTEN = setOf(FileFormat.JPEG, FileFormat.PNG, FileFormat.WEBP)

    fun removeFrom(file: File, format: FileFormat, rewrite: (File) -> Unit = ::rewriteWithoutGpsTags) {
        if (format in REWRITTEN && hasGpsTags(ExifInterface(file))) rewriteCopy(file, rewrite)
        val fills = RandomAccessFile(file, "r").use { input -> find(input, format).fills(input) }
        file.patch(fills)
        if (format == FileFormat.PNG && fills.isNotEmpty()) {
            file.patch(RandomAccessFile(file, "r").use { PngMetadata.crcPatches(it, fills) })
        }
        keptReason(file, format)?.let { throw LocationKept(it) }
    }

    // The version alone is no location.
    private fun hasGpsTags(exif: ExifInterface): Boolean = GPS_TAGS.any { tag ->
        tag != ExifInterface.TAG_GPS_VERSION_ID && exif.getAttributeBytes(tag)?.isZero() == false
    }

    // ExifInterface writes over the file it reads, and an error such as
    // OutOfMemoryError, as it holds a whole WebP in memory, leaves that cut
    // short; so it writes a copy, which takes the file's place once written.
    // Where it cannot, the GPS values are zeroed in place instead.
    private fun rewriteCopy(file: File, rewrite: (File) -> Unit) {
        val copy = File(file.absoluteFile.parentFile, "${file.name}.exif")
        try {
            file.copyTo(copy, overwrite = true)
            rewrite(copy)
            copy.renameTo(file)
        } catch (_: IOException) {
        } catch (_: OutOfMemoryError) {
        } finally {
            copy.delete()
        }
    }

    // Without the GPS tags ExifInterface writes no GPS IFD.
    private fun rewriteWithoutGpsTags(file: File) {
        val exif = ExifInterface(file)
        for (tag in GPS_TAGS) exif.setAttribute(tag, null)
        exif.saveAttributes()
    }

    private fun keptReason(file: File, format: FileFormat): Reason? {
        val exif = ExifInterface(file)
        if (hasGpsTags(exif)) return Reason.GPS_TAGS
        if (exif.getAttributeBytes(ExifInterface.TAG_XMP)?.let(XmpGps::isIn) == true) return Reason.XMP
        return RandomAccessFile(file, "r").use { input -> find(input, format).keptReason(input) }
    }

    private fun find(input: RandomAccessFile, format: FileFormat): Found = Found().also { found ->
        when (format) {
            FileFormat.JPEG -> JpegMetadata.read(input, 0, found)
            FileFormat.PNG -> PngMetadata.read(input, found)
            FileFormat.WEBP -> WebpMetadata.read(input, found)
            FileFormat.HEIF -> HeifMetadata.read(input, found)
            else -> RawMetadata.read(input, found)
        }
    }
}

internal class Found {
    val gpsValues = mutableListOf<FileRange>()
    val gpsTexts = mutableListOf<FileRange>()
    val xmp = mutableListOf<XmpPacket>()
    val compressedXmp = mutableListOf<FileRange>()
    var unreadable = false

    fun fills(input: RandomAccessFile): List<Fill> =
        gpsValues.map { Fill(it, ZERO) } + gpsTexts.filterNot { input.isBlank(it) }.map { Fill(it, SPACE) } +
            xmp.distinct().flatMap { it.gpsValues(input) }.map { Fill(it, SPACE) }

    fun keptReason(input: RandomAccessFile): Reason? = when {
        gpsValues.isNotEmpty() -> Reason.GPS_TAGS
        gpsTexts.any { !input.isBlank(it) } -> Reason.GPS_TEXT
        xmp.any { it.gpsValues(input).isNotEmpty() } -> Reason.XMP
        compressedXmp.any { XmpGps.isIn(inflate(input.bytesAt(it))) } -> Reason.COMPRESSED_XMP
        else -> unreadableReason
    }

    val unreadableReason: Reason? get() = when {
        xmp.any { it.tooLarge } -> Reason.XMP_TOO_LARGE
        unreadable -> Reason.UNREADABLE
        else -> null
    }
}

// A video's location boxes, blanked in place as MediaProvider redacts them:
// ©xyz, loci, gps and gps0 become free boxes, which ISO BMFF and QuickTime
// allow anywhere; the values of Apple's location keys are zeroed; GPS in XMP
// is blanked. Only metadata boxes are read; the media data is skipped. A GPS
// track, such as GoPro's gpmd, is not found. CR3 and JPEG XL photos keep
// their metadata in boxes too: a CR3 its GPS IFD in CMT4, in Canon's uuid
// box; a JPEG XL its Exif and XMP in boxes of their own, which brob may hold
// compressed.
internal object IsoLocation {
    private val LOCATION_BOXES = setOf("\u00A9xyz", "loci", "gps ", "gps0")
    private val CONTAINERS = setOf("moov", "trak", "udta")
    private val XMP_UUID = hex("BE7ACFCB97A942E89C71999491E3AFAC")
    private val CANON_UUID = hex("85C0B687820F11E08111F4CE462B6A48")
    private val METADATA_BOXES = setOf("Exif", "xml ")
    private val FREE = "free".latin1()

    fun removeFrom(file: File, hasLocation: (File) -> Boolean = ::hasRetrievedLocation) {
        val located = locate(file)
        file.patch(located.patches)
        val left = if (located.patches.isEmpty()) located else locate(file)
        when {
            left.patches.isNotEmpty() -> throw LocationKept(Reason.VIDEO_KEPT)
            left.unreadable != null -> throw LocationKept(left.unreadable)
            hasLocation(file) -> throw LocationKept(Reason.VIDEO_ELSEWHERE)
        }
    }

    private class Located(val patches: List<Patch>, val unreadable: Reason?)

    private fun locate(file: File): Located = RandomAccessFile(file, "r").use { input ->
        val walk = Walk(input).apply { visitAll(0, input.length(), depth = 0) }
        Located(walk.patches + walk.found.fills(input), walk.found.unreadableReason)
    }

    private fun hasRetrievedLocation(file: File): Boolean = try {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.absolutePath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION) != null
        } finally {
            retriever.release()
        }
    } catch (_: Exception) {
        false
    }

    // Apple's mdta items are named by their 1-based index into keys.
    private val IsoBox.index get() = type.fold(0) { index, char -> index shl 8 or char.code }

    private fun IsoBox.freed(): List<Patch> = listOf(Overwrite(start + 4, FREE), Fill(payload, ZERO))

    private class Walk(private val input: RandomAccessFile) {
        val patches = mutableListOf<Patch>()
        val found = Found()
        private val boxes = IsoBoxes(input)

        fun visitAll(start: Long, end: Long, depth: Int) {
            if (depth > MAX_DEPTH) return
            for (box in boxes.children(start, end)) visit(box, depth)
            if (boxes.exhausted) found.unreadable = true
        }

        private fun visit(box: IsoBox, depth: Int) {
            when (box.type) {
                in LOCATION_BOXES -> if (!input.isZero(box.payload)) patches += box.freed()
                "XMP_", "xml " -> blankXmp(box.payload)
                "Exif" -> ExifTiff.readItem(input, box.payload, found)
                "CMT4" -> ExifTiff.read(input, box.payload, found, gpsFirst = true)
                "brob" -> if (box.payload.length >= 4 && input.typeAt(box.body) in METADATA_BOXES) {
                    found.unreadable = true
                }
                "uuid" -> when {
                    input.startsWith(box.payload, XMP_UUID) -> blankXmp(box.payload.after(XMP_UUID.size))
                    input.startsWith(box.payload, CANON_UUID) ->
                        visitAll(box.body + CANON_UUID.size, box.end, depth + 1)
                }
                "meta" -> visitMeta(box, depth + 1)
                in CONTAINERS -> visitAll(box.body, box.end, depth + 1)
            }
        }

        private fun visitMeta(meta: IsoBox, depth: Int) {
            if (depth > MAX_DEPTH) return
            val children = boxes.children(firstChildOf(meta), meta.end)
            val locationKeys = children.find { it.type == "keys" }?.let(::locationKeys).orEmpty()
            for (child in children) {
                when (child.type) {
                    "ilst" -> visitItems(child, locationKeys)
                    "xml " -> blankXmp(child.payload.after(4))
                    else -> visit(child, depth)
                }
            }
        }

        private fun visitItems(ilst: IsoBox, locationKeys: Set<Int>) {
            for (item in boxes.children(ilst.body, ilst.end)) {
                if (item.type in LOCATION_BOXES) {
                    if (values(item).isNotEmpty()) patches += item.freed()
                } else if (item.index in locationKeys) {
                    patches += values(item).map { Fill(it, ZERO) }
                }
            }
        }

        // The values of an item's data boxes that are not zero; a data box
        // starts with its type and locale.
        private fun values(item: IsoBox): List<FileRange> = boxes.children(item.body, item.end)
            .filter { it.type == "data" }
            .map { it.payload.after(8) }
            .filter { it.length > 0 && !input.isZero(it) }

        private fun blankXmp(range: FileRange) {
            if (range.length > 0) found.xmp += XmpPacket(listOf(range))
        }

        // QuickTime's meta starts with its children, ISO's with a version and
        // flags; either way the first child is hdlr.
        private fun firstChildOf(meta: IsoBox): Long {
            if (meta.payload.length < 8) return meta.body
            return if (input.typeAt(meta.body + 4) == "hdlr") meta.body else meta.body + 4
        }

        // After a version, flags and a count, each key: its size, namespace
        // and name.
        private fun locationKeys(keys: IsoBox): Set<Int> {
            if (keys.payload.length > MAX_KEYS_BYTES) {
                found.unreadable = true
                return emptySet()
            }
            val bytes = input.bytesAt(keys.payload)
            val buffer = ByteBuffer.wrap(bytes)
            val indices = mutableSetOf<Int>()
            var at = 8
            var index = 1
            while (bytes.size - at >= 8) {
                val size = buffer.getInt(at)
                if (size < 8 || size > bytes.size - at) break
                if (String(bytes, at + 8, size - 8, Charsets.ISO_8859_1).contains("location", ignoreCase = true)) {
                    indices += index
                }
                at += size
                index++
            }
            return indices
        }
    }

    private const val MAX_DEPTH = 8
    private const val MAX_KEYS_BYTES = 1024L * 1024
}

// ISO BMFF boxes, as MP4, QuickTime, HEIF and JPEG XL keep them: a 32-bit
// size and the type, then a 64-bit size where the first is 1; a size of 0
// runs to the end. A size that does not fit ends the list, and the boxes read
// are counted against a bound.
internal class IsoBoxes(private val input: RandomAccessFile) {
    private var read = 0

    val exhausted get() = read > MAX_BOXES

    fun children(start: Long, end: Long): List<IsoBox> {
        val children = mutableListOf<IsoBox>()
        var offset = start
        while (end - offset >= 8 && read++ < MAX_BOXES) {
            input.seek(offset)
            var size = input.readInt().toLong() and 0xFFFFFFFFL
            val type = input.readType()
            var header = 8L
            if (size == 1L) {
                if (end - offset < 16) break
                size = input.readLong()
                header = 16
            } else if (size == 0L) {
                size = end - offset
            }
            if (size < header || size > end - offset) break
            children += IsoBox(offset, type, offset + header, offset + size)
            offset += size
        }
        return children
    }

    private companion object {
        const val MAX_BOXES = 100_000
    }
}

internal class IsoBox(val start: Long, val type: String, val body: Long, val end: Long) {
    val payload get() = FileRange(body, end)
}

// A JPEG keeps Exif and XMP in APP1 segments ahead of the scan: Exif after
// its identifier, the standard XMP packet in one segment, and an extended
// packet split over others, each chunk after the packet's GUID, its full
// length and the chunk's offset in it.
internal object JpegMetadata {
    private val SOI = byteArrayOf(0xFF.toByte(), 0xD8.toByte())
    private val STANDARD = "http://ns.adobe.com/xap/1.0/\u0000".latin1()
    private val EXTENDED = "http://ns.adobe.com/xmp/extension/\u0000".latin1()
    private const val GUID_BYTES = 32
    private const val FILL: Byte = -1
    private const val APP1 = 0xE1
    private const val SOS = 0xDA
    private const val EOI = 0xD9

    fun read(input: RandomAccessFile, start: Long, into: Found) {
        if (!input.startsWith(FileRange(start, input.length()), SOI)) return
        val extended = mutableMapOf<String, MutableList<Pair<Long, FileRange>>>()
        var offset = start + 2
        while (input.length() - offset >= 4) {
            input.seek(offset)
            if (input.readByte() != FILL) break
            // Any number of fill bytes, each 0xFF, may come before a marker.
            offset = (input.indexOfFirst(FileRange(offset + 1, input.length())) { it != FILL } ?: break) - 1
            if (input.length() - offset < 4) break
            input.seek(offset + 1)
            val marker = input.readUnsignedByte()
            if (marker == SOS || marker == EOI) break
            val length = input.readUnsignedShort()
            val payload = FileRange(offset + 4, offset + 2 + length)
            if (length < 2 || payload.end > input.length()) break
            if (marker == APP1 && input.startsWith(payload, EXIF_HEADER)) {
                ExifTiff.read(input, payload.after(EXIF_HEADER.size), into)
            } else if (marker == APP1 && input.startsWith(payload, STANDARD)) {
                into.xmp += XmpPacket(listOf(payload.after(STANDARD.size)))
            } else if (marker == APP1 && input.startsWith(payload, EXTENDED) &&
                payload.length >= EXTENDED.size + GUID_BYTES + 8
            ) {
                input.seek(payload.start + EXTENDED.size)
                val guid = ByteArray(GUID_BYTES).also(input::readFully).toString(Charsets.ISO_8859_1)
                input.readInt()
                val chunkOffset = input.readInt().toLong() and 0xFFFFFFFFL
                extended.getOrPut(guid) { mutableListOf() } +=
                    chunkOffset to payload.after(EXTENDED.size + GUID_BYTES + 8)
            }
            offset = payload.end
        }
        into.xmp += extended.values.map { chunks -> XmpPacket(chunks.sortedBy { it.first }.map { it.second }) }
    }
}

// A PNG keeps Exif in its eXIf chunk and XMP in a text chunk named
// XML:com.adobe.xmp: iTXt, as ExifInterface and most writers keep it,
// uncompressed or compressed, or tEXt and zTXt from older writers.
// ImageMagick also keeps each Exif and XMP property in a text chunk named
// after it, such as exif:GPSLatitude. Compressed text cannot be blanked in
// place, and a chunk changed in place needs its CRC again.
internal object PngMetadata {
    private const val XMP_KEYWORD = "XML:com.adobe.xmp"
    private val TEXT_CHUNKS = setOf("tEXt", "zTXt", "iTXt")

    // A keyword of 1 to 79 bytes and its NUL.
    private const val MAX_KEYWORD_BYTES = 80L

    fun read(input: RandomAccessFile, into: Found) {
        for (chunk in chunks(input)) {
            when (chunk.type) {
                "eXIf" -> ExifTiff.read(input, input.withoutExifHeader(chunk.data), into)
                in TEXT_CHUNKS -> readText(input, chunk, into)
            }
        }
    }

    fun crcPatches(input: RandomAccessFile, fills: List<Fill>): List<Patch> =
        chunks(input).filter { chunk -> fills.any { it.range.overlaps(chunk.data) } }.map { chunk ->
            val crc = CRC32().apply { update(chunk.type.latin1()) }
            input.inBlocks(chunk.data) { buffer, count ->
                crc.update(buffer, 0, count)
                true
            }
            Overwrite(chunk.data.end, ByteBuffer.allocate(4).putInt(crc.value.toInt()).array())
        }

    private class Chunk(val type: String, val data: FileRange)

    private fun chunks(input: RandomAccessFile): List<Chunk> {
        val chunks = mutableListOf<Chunk>()
        var offset = 8L
        while (input.length() - offset >= 12) {
            input.seek(offset)
            val length = input.readInt().toLong() and 0xFFFFFFFFL
            val chunk = Chunk(input.readType(), FileRange(offset + 8, offset + 8 + length))
            if (chunk.data.end + 4 > input.length()) break
            chunks += chunk
            if (chunk.type == "IEND") break
            offset = chunk.data.end + 4
        }
        return chunks
    }

    // After the keyword and its NUL: tEXt's text; zTXt's method and
    // compressed text; iTXt's compression flag, method, language, NUL,
    // translated keyword, NUL and text.
    private fun readText(input: RandomAccessFile, chunk: Chunk, into: Found) {
        val data = chunk.data
        val keywordEnd = input.indexOfFirst(FileRange(data.start, minOf(data.end, data.start + MAX_KEYWORD_BYTES))) {
            it == ZERO
        } ?: return
        val keyword = input.bytesAt(FileRange(data.start, keywordEnd)).toString(Charsets.ISO_8859_1)
        val isXmp = keyword == XMP_KEYWORD
        if (!isXmp && !XmpGps.namesLocation(keyword)) return
        val afterKeyword = keywordEnd + 1
        val (text, compressed) = when (chunk.type) {
            "tEXt" -> FileRange(afterKeyword, data.end) to false
            "zTXt" -> if (data.end > afterKeyword) FileRange(afterKeyword + 1, data.end) to true else return
            else -> {
                if (data.end - afterKeyword < 4) return
                input.seek(afterKeyword)
                val flag = input.readUnsignedByte()
                val language = input.indexOfFirst(FileRange(afterKeyword + 2, data.end)) { it == ZERO } ?: return
                val translated = input.indexOfFirst(FileRange(language + 1, data.end)) { it == ZERO } ?: return
                FileRange(translated + 1, data.end) to (flag != 0)
            }
        }
        when {
            isXmp && compressed -> into.compressedXmp += text
            isXmp -> into.xmp += XmpPacket(listOf(text))
            compressed -> into.unreadable = true
            else -> into.gpsTexts += text
        }
    }
}

// A WebP keeps Exif and XMP in chunks of their own. ExifInterface never reads
// the XMP chunk.
internal object WebpMetadata {
    fun read(input: RandomAccessFile, into: Found) {
        var offset = 12L
        while (input.length() - offset >= 8) {
            input.seek(offset)
            val type = input.readType()
            val size = Integer.reverseBytes(input.readInt()).toLong() and 0xFFFFFFFFL
            val data = FileRange(offset + 8, offset + 8 + size)
            if (data.end > input.length()) break
            when (type) {
                "EXIF" -> ExifTiff.read(input, input.withoutExifHeader(data), into)
                "XMP " -> into.xmp += XmpPacket(listOf(data))
            }
            offset = data.end + (size and 1)
        }
    }
}

// HEIF and AVIF keep Exif and XMP as items of the file's meta box: iinf gives
// each item's type, iloc where its bytes are, in the file or in idat. Every
// Exif and XMP item is read, not only those of the primary image.
internal object HeifMetadata {
    private val SIZES = setOf(0, 4, 8)
    private const val XMP_CONTENT_TYPE = "application/rdf+xml"

    private class Info(val type: String, contentType: String, val encoding: String) {
        // A MIME type ignores case and may carry parameters.
        val isXmp = type == "mime" &&
            contentType.substringBefore(';').trim().equals(XMP_CONTENT_TYPE, ignoreCase = true)
    }

    fun read(input: RandomAccessFile, into: Found) {
        val boxes = IsoBoxes(input)
        readItems(input, boxes, into)
        if (boxes.exhausted) into.unreadable = true
    }

    private fun readItems(input: RandomAccessFile, boxes: IsoBoxes, into: Found) {
        val meta = boxes.children(0, input.length()).find { it.type == "meta" } ?: return
        val children = boxes.children(meta.body + 4, meta.end)
        val items = children.find { it.type == "iinf" }?.let { infos(input, boxes, it) }.orEmpty()
            .filterValues { it.type == "Exif" || it.isXmp }
        val idat = children.find { it.type == "idat" }?.payload
        val locations = children.find { it.type == "iloc" }?.let { locations(input, it, idat, items.keys) }.orEmpty()
        for ((id, info) in items) {
            val item = locations[id]
            when {
                item == null -> into.unreadable = true
                !info.isXmp -> ExifTiff.readItem(input, item, into)
                info.encoding.isEmpty() -> into.xmp += XmpPacket(listOf(item))
                else -> into.compressedXmp += item
            }
        }
    }

    // From version 2 on, an infe holds after its version and flags the item's
    // ID, protection index and type, then, each ending in a NUL, its name
    // and, for a mime item, its content type and encoding.
    private fun infos(input: RandomAccessFile, boxes: IsoBoxes, iinf: IsoBox): Map<Long, Info> {
        if (iinf.payload.length < 6) return emptyMap()
        input.seek(iinf.body)
        val first = iinf.body + if (input.readUnsignedByte() == 0) 6 else 8
        val infos = mutableMapOf<Long, Info>()
        for (infe in boxes.children(first, iinf.end)) {
            if (infe.type != "infe" || infe.payload.length < 12) continue
            val bytes = input.bytesAt(infe.payload)
            val buffer = ByteBuffer.wrap(bytes)
            val version = bytes[0].toInt()
            if (version < 2) continue
            val id = if (version == 2) {
                buffer.getShort(4).toLong() and 0xFFFF
            } else {
                buffer.getInt(4).toLong() and 0xFFFFFFFFL
            }
            val typeAt = if (version == 2) 8 else 10
            if (bytes.size < typeAt + 4) continue
            val strings = String(bytes, typeAt + 4, bytes.size - typeAt - 4, Charsets.ISO_8859_1).split('\u0000')
            infos[id] = Info(
                String(bytes, typeAt, 4, Charsets.ISO_8859_1),
                strings.getOrElse(1) { "" },
                strings.getOrElse(2) { "" },
            )
        }
        return infos
    }

    // After its version and flags, iloc gives the sizes of offsets, lengths,
    // base offsets and indices, then for each item its ID, construction
    // method, data reference, base offset and extents. Only the wanted items'
    // extents are read.
    private fun locations(
        input: RandomAccessFile,
        iloc: IsoBox,
        idat: FileRange?,
        wanted: Set<Long>,
    ): Map<Long, FileRange> {
        val locations = mutableMapOf<Long, FileRange>()
        if (iloc.payload.length < 8) return locations
        val bytes = ByteBuffer.wrap(input.bytesAt(iloc.payload))
        val version = bytes.get(0).toInt()
        val sizes = bytes.getShort(4).toInt()
        val offsetSize = sizes shr 12 and 0xF
        val lengthSize = sizes shr 8 and 0xF
        val baseOffsetSize = sizes shr 4 and 0xF
        val indexSize = if (version == 0) 0 else sizes and 0xF
        if (listOf(offsetSize, lengthSize, baseOffsetSize, indexSize).any { it !in SIZES }) return locations
        val extentBytes = indexSize + offsetSize + lengthSize
        bytes.position(6)
        try {
            var items = if (version < 2) bytes.short.toLong() and 0xFFFF else bytes.int.toLong() and 0xFFFFFFFFL
            while (items-- > 0) {
                val id = if (version < 2) bytes.short.toLong() and 0xFFFF else bytes.int.toLong() and 0xFFFFFFFFL
                val method = if (version == 0) 0 else bytes.short.toInt() and 0xF
                val reference = bytes.short.toInt()
                val base = bytes.sized(baseOffsetSize)
                val count = bytes.short.toInt() and 0xFFFF
                if (count * extentBytes > bytes.remaining()) break
                // Extents that take no bytes can only say the same again and
                // again; such an item is left unplaced.
                if (id !in wanted || extentBytes == 0 && count > 1) {
                    bytes.position(bytes.position() + count * extentBytes)
                    continue
                }
                val extents = List(count) {
                    bytes.sized(indexSize)
                    bytes.sized(offsetSize) to bytes.sized(lengthSize)
                }
                val origin = when {
                    reference != 0 -> null
                    method == 0 -> FileRange(0, input.length())
                    method == 1 -> idat
                    else -> null
                }
                origin?.let { range(it, base, extents) }?.let { locations[id] = it }
            }
        } catch (_: BufferUnderflowException) {
        }
        return locations
    }

    // The extents, one right after the other, inside what they point into; a
    // length of 0 runs to its end.
    private fun range(origin: FileRange, base: Long, extents: List<Pair<Long, Long>>): FileRange? {
        var range: FileRange? = null
        for ((offset, length) in extents) {
            if (base < 0 || offset < 0 || length < 0) return null
            val start = origin.start + base + offset
            val end = if (length == 0L) origin.end else start + length
            if (start < origin.start || start > end || end > origin.end) return null
            if (range != null && range.end != start) return null
            range = FileRange(range?.start ?: start, end)
        }
        return range
    }

    private fun ByteBuffer.sized(size: Int): Long = when (size) {
        4 -> int.toLong() and 0xFFFFFFFFL
        8 -> long
        else -> 0
    }
}

// TIFF-based raw formats, such as DNG, CR2, NEF, ARW, ORF and RW2, are Exif's
// TIFF structure as a whole; a Fujifilm RAF holds a JPEG, whose offset
// follows its header.
internal object RawMetadata {
    private val RAF = "FUJIFILMCCD-RAW".latin1()
    private const val RAF_JPEG_OFFSET = 84L

    fun read(input: RandomAccessFile, into: Found) {
        val file = FileRange(0, input.length())
        if (!input.startsWith(file, RAF)) return ExifTiff.read(input, file, into)
        if (input.length() < RAF_JPEG_OFFSET + 4) return
        input.seek(RAF_JPEG_OFFSET)
        JpegMetadata.read(input, input.readInt().toLong() and 0xFFFFFFFFL, into)
    }
}

// Exif's TIFF structure: the GPS IFD that IFD0, or an IFD after it, points
// to, and XMP in tag 700. Offsets count from the TIFF header; a value is read
// by its own type and count, and only where it lies inside the structure.
// ExifInterface instead reads by the type a tag should have, and can be far
// off. Only GPS tags are taken from a GPS IFD, so that a pointer gone wrong
// zeroes nothing else.
internal object ExifTiff {
    // By type: BYTE, ASCII, SHORT, LONG, RATIONAL, SBYTE, UNDEFINED, SSHORT,
    // SLONG, SRATIONAL, FLOAT, DOUBLE, IFD.
    private val TYPE_BYTES = intArrayOf(0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8, 4)

    // TIFF's, and those of Olympus's ORF and Panasonic's RW2.
    private val MAGIC = setOf(0x2A, 0x4F52, 0x5352, 0x55)
    private const val SHORT = 3
    private const val SSHORT = 8
    private const val GPS_IFD = 0x8825
    private const val GPS_VERSION = 0
    private const val XMP = 0x02BC
    private const val LAST_GPS_TAG = 0x1F
    private const val MAX_IFDS = 8
    private const val MAX_GPS_VALUE_BYTES = 64L * 1024

    // HEIF's Exif item and JPEG XL's Exif box start with the TIFF header's
    // offset.
    fun readItem(input: RandomAccessFile, item: FileRange, into: Found) {
        if (item.length < 4) return
        input.seek(item.start)
        read(input, FileRange(item.start + 4 + (input.readInt().toLong() and 0xFFFFFFFFL), item.end), into)
    }

    // A CR3's CMT4 is a TIFF structure whose first IFD is the GPS IFD.
    fun read(input: RandomAccessFile, tiff: FileRange, into: Found, gpsFirst: Boolean = false) {
        if (tiff.length < 8) return
        val header = ByteBuffer.wrap(input.bytesAt(FileRange(tiff.start, tiff.start + 8)))
        val order = when (header.getShort(0).toInt()) {
            0x4949 -> ByteOrder.LITTLE_ENDIAN
            0x4D4D -> ByteOrder.BIG_ENDIAN
            else -> return
        }
        header.order(order)
        if ((header.getShort(2).toInt() and 0xFFFF) !in MAGIC) return
        val first = header.getInt(4).toLong() and 0xFFFFFFFFL
        if (gpsFirst) return readGps(input, tiff, first, order, into)
        val seen = mutableSetOf<Long>()
        var next = first
        while (next != 0L && seen.size < MAX_IFDS && seen.add(next)) {
            val ifd = ifd(input, tiff, next, order) ?: return
            for (entry in ifd.entries) {
                when (entry.tag) {
                    GPS_IFD -> entry.pointer().takeIf { it !in seen }?.let { readGps(input, tiff, it, order, into) }
                    XMP -> if (entry.unitBytes == 1) entry.value(tiff)?.let { into.xmp += XmpPacket(listOf(it)) }
                }
            }
            next = ifd.next
        }
    }

    // The version alone is no location.
    private fun readGps(input: RandomAccessFile, tiff: FileRange, offset: Long, order: ByteOrder, into: Found) {
        val ifd = ifd(input, tiff, offset, order) ?: return
        val values = mutableListOf<FileRange>()
        var located = false
        for (entry in ifd.entries) {
            if (entry.tag > LAST_GPS_TAG) continue
            val value = entry.value(tiff) ?: continue
            if (value.length > MAX_GPS_VALUE_BYTES) {
                into.unreadable = true
            } else if (!input.isZero(value)) {
                values += value
                located = located || entry.tag != GPS_VERSION
            }
        }
        if (located) into.gpsValues += values
    }

    private class Ifd(val entries: List<Entry>, val next: Long)

    // The entries that lie inside the structure; the next IFD's offset
    // follows them.
    private fun ifd(input: RandomAccessFile, tiff: FileRange, offset: Long, order: ByteOrder): Ifd? {
        val start = tiff.start + offset
        if (start + 2 > tiff.end) return null
        val count = ByteBuffer.wrap(input.bytesAt(FileRange(start, start + 2))).order(order).short.toInt() and 0xFFFF
        val bytes = ByteBuffer.wrap(input.bytesAt(FileRange(start, minOf(tiff.end, start + 6 + 12L * count))))
            .order(order)
        val entries = List(minOf(count, (bytes.capacity() - 2) / 12)) { Entry(bytes, 2 + 12 * it, start) }
        val nextAt = 2 + 12 * count
        return Ifd(entries, if (bytes.capacity() >= nextAt + 4) bytes.getInt(nextAt).toLong() and 0xFFFFFFFFL else 0)
    }

    private class Entry(private val ifd: ByteBuffer, private val at: Int, private val ifdStart: Long) {
        val tag = ifd.getShort(at).toInt() and 0xFFFF
        private val type = ifd.getShort(at + 2).toInt() and 0xFFFF
        val unitBytes = TYPE_BYTES.getOrElse(type) { 0 }

        // Up to four bytes are in the entry, more at the offset it holds.
        fun value(tiff: FileRange): FileRange? {
            if (unitBytes == 0) return null
            val length = (ifd.getInt(at + 4).toLong() and 0xFFFFFFFFL) * unitBytes
            if (length <= 4) return FileRange(ifdStart + at + 8, ifdStart + at + 8 + length)
            val start = tiff.start + (ifd.getInt(at + 8).toLong() and 0xFFFFFFFFL)
            return FileRange(start, start + length).takeIf { it.end <= tiff.end }
        }

        fun pointer(): Long = if (type == SHORT || type == SSHORT) {
            ifd.getShort(at + 8).toLong() and 0xFFFF
        } else {
            ifd.getInt(at + 8).toLong() and 0xFFFFFFFFL
        }
    }
}

// An XMP packet where a file keeps it: one range, or several that read as
// one, as the chunks of a JPEG's extended XMP do.
internal data class XmpPacket(val pieces: List<FileRange>) {
    val tooLarge: Boolean get() = pieces.sumOf { it.length } > MAX_READ_BYTES

    // Ranges of the file; a value across two pieces gives two. A packet too
    // large to read gives none and is reported.
    fun gpsValues(input: RandomAccessFile): List<FileRange> =
        if (tooLarge) emptyList() else XmpGps.values(read(input)).flatMap(::inFile)

    private fun read(input: RandomAccessFile): String {
        val bytes = ByteArray(pieces.sumOf { it.length }.toInt())
        var at = 0
        for (piece in pieces) {
            input.seek(piece.start)
            input.readFully(bytes, at, piece.length.toInt())
            at += piece.length.toInt()
        }
        return bytes.toString(Charsets.ISO_8859_1)
    }

    private fun inFile(value: IntRange): List<FileRange> {
        val ranges = mutableListOf<FileRange>()
        var pieceStart = 0L
        for (piece in pieces) {
            val from = maxOf(value.first.toLong(), pieceStart)
            val to = minOf(value.last + 1L, pieceStart + piece.length)
            if (from < to) ranges += FileRange(piece.start + from - pieceStart, piece.start + to - pieceStart)
            pieceStart += piece.length
        }
        return ranges
    }
}

// The values in XMP of properties that hold a location: those whose local
// name starts with GPS, as exif:GPSLatitude, or names a latitude, longitude
// or altitude, as DJI's drone-dji:Latitude and drone-dji:AbsoluteAltitude,
// ignoring case, or ends in Lat, Lon or Lng, in that case, as the target of
// DJI's laser rangefinder, drone-dji:LRFTargetLat. A value is such a
// property's attribute value, the text in its element, or an attribute value
// in its element, such as rdf:value. Spaces of the same length over them keep
// the packet well-formed. XMP is UTF-8, whose multi-byte characters hold no
// ASCII bytes, so it is read one char per byte and indices are byte offsets.
// Markup that is not well-formed ends the scan; an end tag that closes no
// open element is passed over.
internal object XmpGps {
    private val LOCATION_WORDS = listOf("latitude", "longitude", "altitude")
    private val LOCATION_ENDINGS = listOf("Lat", "Lon", "Lng")
    private val SYNTAX_PREFIXES = setOf("xmlns", "xml", "rdf")
    private val NO_LOCATION = setOf(VERSION, "GPSInfo")
    private const val VERSION = "GPSVersionID"
    private const val NAME_ENDS = " \t\r\n=/>\"'<"
    private const val CDATA = "<![CDATA["

    fun isIn(xmp: ByteArray): Boolean = values(xmp.toString(Charsets.ISO_8859_1)).isNotEmpty()

    // A name as ImageMagick gives a PNG text chunk after an Exif or XMP
    // property; the version and the GPS IFD's pointer hold no location.
    fun namesLocation(name: String): Boolean = holdsLocation(name) && name.substringAfter(':') !in NO_LOCATION

    fun values(xmp: String): List<IntRange> {
        val values = mutableListOf<Value>()
        val open = OpenElements()
        var at = 0
        while (at < xmp.length) {
            val property = open.property
            at = when {
                xmp[at] != '<' -> {
                    val end = xmp.indexOf('<', at).takeIf { it >= 0 } ?: xmp.length
                    if (property != null) values += Value(at until end, property)
                    end
                }
                xmp.startsWith("<!--", at) -> after(xmp, "-->", at + 4)
                xmp.startsWith("<?", at) -> after(xmp, "?>", at + 2)
                xmp.startsWith(CDATA, at) -> after(xmp, "]]>", at + CDATA.length)?.also { end ->
                    if (property != null) values += Value(at + CDATA.length until end - 3, property)
                }
                xmp.startsWith("<!", at) -> after(xmp, ">", at)
                xmp.startsWith("</", at) -> after(xmp, ">", at)?.also { end ->
                    open.close(xmp.substring(at + 2, end - 1).trim())
                }
                else -> afterStartTag(xmp, at, open, values)
            } ?: break
        }
        val located = values.filter { value -> value.range.any { !xmp[it].isXmlSpace() } }
        // The version alone is no location.
        if (located.all { it.property.substringAfter(':').equals(VERSION, ignoreCase = true) }) return emptyList()
        return located.map { it.range }
    }

    // A value and the location property it belongs to.
    private class Value(val range: IntRange, val property: String)

    private class Element(val name: String, val property: String?)

    // The open elements, innermost last, each with the location property it
    // holds or is in, and how many are open by each name, so that an end tag
    // that closes none costs nothing.
    private class OpenElements {
        private val elements = mutableListOf<Element>()
        private val counts = mutableMapOf<String, Int>()

        val property: String? get() = elements.lastOrNull()?.property

        fun open(name: String, property: String?) {
            elements += Element(name, property)
            counts[name] = (counts[name] ?: 0) + 1
        }

        fun close(name: String) {
            if ((counts[name] ?: 0) == 0) return
            val closed = elements.subList(elements.indexOfLast { it.name == name }, elements.size)
            for (element in closed) counts[element.name] = counts.getValue(element.name) - 1
            closed.clear()
        }
    }

    private fun afterStartTag(xmp: String, from: Int, open: OpenElements, values: MutableList<Value>): Int? {
        var at = nameEnd(xmp, from + 1)
        val name = xmp.substring(from + 1, at)
        if (name.isEmpty()) return null
        val property = name.takeIf { holdsLocation(it, element = true) } ?: open.property
        while (true) {
            at = skipSpace(xmp, at)
            if (xmp.startsWith("/>", at)) return at + 2
            if (xmp.startsWith(">", at)) {
                open.open(name, property)
                return at + 1
            }
            val attributeEnd = nameEnd(xmp, at)
            if (attributeEnd == at) return null
            val attribute = xmp.substring(at, attributeEnd)
            at = skipSpace(xmp, attributeEnd)
            if (xmp.getOrNull(at) != '=') return null
            at = skipSpace(xmp, at + 1)
            val quote = xmp.getOrNull(at)?.takeIf { it == '"' || it == '\'' } ?: return null
            val close = xmp.indexOf(quote, at + 1).takeIf { it >= 0 } ?: return null
            val valueOf = attribute.takeIf { holdsLocation(it) } ?: property?.takeIf { isValue(attribute) }
            if (valueOf != null) values += Value(at + 1 until close, valueOf)
            at = close + 1
        }
    }

    // An element without a prefix is in the default namespace; an attribute
    // without one is in none.
    private fun holdsLocation(name: String, element: Boolean = false): Boolean {
        val local = if (element && ':' !in name) name else name.substringAfter(':', "")
        return name.substringBefore(':') != "xmlns" && (
            local.startsWith("gps", ignoreCase = true) ||
                LOCATION_WORDS.any { local.contains(it, ignoreCase = true) } ||
                LOCATION_ENDINGS.any(local::endsWith)
            )
    }

    // In a location's element, an attribute is a value unless it declares a
    // namespace or is RDF's or XML's own; rdf:value is a value.
    private fun isValue(attribute: String): Boolean =
        attribute == "rdf:value" || attribute.contains(':') && attribute.substringBefore(':') !in SYNTAX_PREFIXES

    private fun after(xmp: String, end: String, from: Int): Int? =
        xmp.indexOf(end, from).takeIf { it >= 0 }?.plus(end.length)

    private fun nameEnd(xmp: String, from: Int): Int {
        var at = from
        while (at < xmp.length && xmp[at] !in NAME_ENDS) at++
        return at
    }

    private fun skipSpace(xmp: String, from: Int): Int {
        var at = from
        while (at < xmp.length && xmp[at].isXmlSpace()) at++
        return at
    }

    private fun Char.isXmlSpace(): Boolean = this == ' ' || this == '\t' || this == '\r' || this == '\n'
}

internal enum class FileFormat {
    JPEG,
    PNG,
    WEBP,
    HEIF, // and AVIF
    BOXES, // MP4, 3GP and QuickTime videos, and CR3 and JPEG XL photos
    OTHER;

    companion object {
        private val HEIF_BRANDS = setOf(
            "heic", "heix", "heim", "heis", "hevc", "hevx", "mif1", "mif2", "msf1", "avif", "avis",
        )

        // QuickTime files older than ftyp start with one of these.
        private val QUICKTIME_BOXES = setOf("moov", "mdat", "wide", "free", "skip", "pnot")

        fun of(head: ByteArray): FileFormat {
            fun text(offset: Int, length: Int): String? =
                if (head.size >= offset + length) String(head, offset, length, Charsets.ISO_8859_1) else null

            return when {
                text(0, 3) == "\u00FF\u00D8\u00FF" -> JPEG
                text(0, 8) == "\u0089PNG\r\n\u001A\n" -> PNG
                text(0, 4) == "RIFF" && text(8, 4) == "WEBP" -> WEBP
                text(4, 4) == "ftyp" -> {
                    val boxEnd = minOf(head.size, ByteBuffer.wrap(head).getInt(0))
                    val brands = listOfNotNull(text(8, 4)) + (16..boxEnd - 4 step 4).mapNotNull { text(it, 4) }
                    if (brands.any { it in HEIF_BRANDS }) HEIF else BOXES
                }
                text(4, 4) == "JXL " || text(4, 4) in QUICKTIME_BOXES -> BOXES
                else -> OTHER
            }
        }
    }
}

internal data class FileRange(val start: Long, val end: Long) {
    val length: Long get() = end - start

    fun after(bytes: Int) = FileRange(start + bytes, end)

    fun overlaps(other: FileRange) = start < other.end && other.start < end
}

// A change in place, which keeps the file's length.
internal sealed interface Patch {
    fun applyTo(output: RandomAccessFile)
}

internal class Fill(val range: FileRange, private val byte: Byte) : Patch {
    override fun applyTo(output: RandomAccessFile) {
        val buffer = ByteArray(minOf(range.length, BLOCK_BYTES).toInt()) { byte }
        output.seek(range.start)
        var left = range.length
        while (left > 0) {
            val count = minOf(left, buffer.size.toLong()).toInt()
            output.write(buffer, 0, count)
            left -= count
        }
    }
}

internal class Overwrite(private val at: Long, private val bytes: ByteArray) : Patch {
    override fun applyTo(output: RandomAccessFile) {
        output.seek(at)
        output.write(bytes)
    }
}

private fun File.patch(patches: List<Patch>) {
    if (patches.isEmpty()) return
    RandomAccessFile(this, "rw").use { output -> patches.forEach { it.applyTo(output) } }
}

private fun RandomAccessFile.bytesAt(range: FileRange): ByteArray {
    if (range.length > MAX_READ_BYTES) throw LocationKept(Reason.BLOCK_TOO_LARGE)
    seek(range.start)
    return ByteArray(range.length.toInt()).also(::readFully)
}

private inline fun RandomAccessFile.inBlocks(range: FileRange, take: (ByteArray, Int) -> Boolean) {
    val buffer = ByteArray(minOf(range.length, BLOCK_BYTES).toInt())
    seek(range.start)
    var left = range.length
    while (left > 0) {
        val count = minOf(left, buffer.size.toLong()).toInt()
        readFully(buffer, 0, count)
        if (!take(buffer, count)) return
        left -= count
    }
}

// Read in blocks that grow from a few bytes, as most searches end at once.
private inline fun RandomAccessFile.indexOfFirst(range: FileRange, matches: (Byte) -> Boolean): Long? {
    var at = range.start
    var block = 16L
    while (at < range.end) {
        val bytes = bytesAt(FileRange(at, minOf(range.end, at + block)))
        val index = bytes.indexOfFirst(matches)
        if (index >= 0) return at + index
        at += bytes.size
        block = minOf(block * 2, BLOCK_BYTES)
    }
    return null
}

private inline fun RandomAccessFile.all(range: FileRange, matches: (Byte) -> Boolean): Boolean {
    var all = true
    inBlocks(range) { buffer, count -> (0 until count).all { matches(buffer[it]) }.also { all = it } }
    return all
}

private fun RandomAccessFile.isZero(range: FileRange): Boolean = all(range) { it == ZERO }

private fun RandomAccessFile.isBlank(range: FileRange): Boolean = all(range) { it.toInt().toChar() in " \t\r\n" }

private fun RandomAccessFile.startsWith(range: FileRange, prefix: ByteArray): Boolean =
    range.length >= prefix.size && bytesAt(FileRange(range.start, range.start + prefix.size)).contentEquals(prefix)

// Some writers put JPEG's Exif identifier ahead of the TIFF header in a PNG
// or WebP as well.
private fun RandomAccessFile.withoutExifHeader(range: FileRange): FileRange =
    if (startsWith(range, EXIF_HEADER)) range.after(EXIF_HEADER.size) else range

private fun RandomAccessFile.readType(): String = ByteArray(4).also(::readFully).toString(Charsets.ISO_8859_1)

private fun RandomAccessFile.typeAt(at: Long): String {
    seek(at)
    return readType()
}

// A stream cut short still gives what it held up to there.
private fun inflate(compressed: ByteArray): ByteArray {
    val inflated = ByteArrayOutputStream()
    val buffer = ByteArray(8192)
    try {
        InflaterInputStream(compressed.inputStream()).use { stream ->
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                inflated.write(buffer, 0, read)
                if (inflated.size() > MAX_READ_BYTES) throw LocationKept(Reason.XMP_TOO_LARGE)
            }
        }
    } catch (_: IOException) {
    }
    return inflated.toByteArray()
}

private fun ByteArray.isZero(): Boolean = all { it == ZERO }

private fun String.latin1(): ByteArray = toByteArray(Charsets.ISO_8859_1)

private fun hex(digits: String): ByteArray = digits.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

private val EXIF_HEADER = "Exif\u0000\u0000".latin1()
private const val ZERO: Byte = 0
private const val SPACE: Byte = 0x20
private const val BLOCK_BYTES = 64L * 1024
private const val MAX_READ_BYTES = 64L * 1024 * 1024
