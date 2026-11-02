package dev.coderoftime.rurana

import androidx.exifinterface.media.ExifInterface
import dev.coderoftime.rurana.LocationRemoval.LocationKept
import dev.coderoftime.rurana.LocationRemoval.Reason
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.lang.reflect.Modifier
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32
import java.util.zip.DeflaterOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class LocationRemovalTest {
    @get:Rule
    val folder = TemporaryFolder()

    @Test
    fun `a JPEG loses its GPS tags and the GPS IFD, and keeps the other tags ExifInterface knows and its image data`() {
        val original = jpeg(app1(EXIF_HEADER + tiff(withLocation = true)))
        val file = write(original)
        assertNotNull(ExifInterface(file).latLong)
        assertTrue(GPS_INFO in ifd0Tags(tiffOf(original)))

        LocationRemoval.removeFrom(file)

        val stripped = file.readBytes()
        val exif = ExifInterface(file)
        assertNull(exif.latLong)
        assertTrue(LocationRemoval.GPS_TAGS.none(exif::hasAttribute))
        assertFalse(GPS_INFO in ifd0Tags(tiffOf(stripped)))
        assertEquals("Rurana", exif.getAttribute(ExifInterface.TAG_MAKE))
        assertEquals(6, exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, 0))
        assertArrayEquals(scanOf(original), scanOf(stripped))
        assertEquals(listOf("media"), file.parentFile?.list()?.toList())
    }

    @Test
    fun `what follows a JPEG's first image, another image or a motion photo's video, is kept as it was`() {
        val video = ftyp("mp42", "isom") +
            container("moov", container("udta", box("\u00A9xyz", "+52.5200+013.4050/".latin1())))
        val original = jpeg(app1(EXIF_HEADER + tiff(withLocation = true))) +
            jpeg(app1(EXIF_HEADER + tiff(withLocation = true))) + video
        val file = write(original)

        LocationRemoval.removeFrom(file)

        val stripped = file.readBytes()
        assertNull(ExifInterface(file).latLong)
        assertFalse(GPS_INFO in ifd0Tags(tiffOf(stripped)))
        assertArrayEquals(scanOf(original), scanOf(stripped))
    }

    @Test
    fun `GPS in a JPEG's XMP is blanked in place, and the GPS tags go as before`() {
        val original = jpeg(app1(EXIF_HEADER + tiff(withLocation = true)), xmpApp1(XMP_WITH_LOCATION))
        val file = write(original)

        LocationRemoval.removeFrom(file)

        val stripped = file.readBytes()
        assertNull(ExifInterface(file).latLong)
        assertFalse(GPS_INFO in ifd0Tags(tiffOf(stripped)))
        assertArrayEquals(blanked(XMP_WITH_LOCATION).utf8(), xmpOf(stripped))
        assertArrayEquals(scanOf(original), scanOf(stripped))
    }

    @Test
    fun `GPS in XMP inside a JPEG's Exif is blanked in place`() {
        val file = write(jpeg(app1(EXIF_HEADER + tiff(withLocation = true, xmp = XMP_WITH_LOCATION.utf8()))))

        LocationRemoval.removeFrom(file)

        val exif = ExifInterface(file)
        assertNull(exif.latLong)
        assertArrayEquals(blanked(XMP_WITH_LOCATION).utf8(), exif.getAttributeBytes(ExifInterface.TAG_XMP))
    }

    @Test
    fun `GPS in a JPEG's extended XMP is blanked across its chunks, and nothing else changes`() {
        val split = String(XMP_WITH_LOCATION.utf8(), Charsets.ISO_8859_1).indexOf("52,31.2N") + 3
        fun withExtended(xmp: String): ByteArray {
            val bytes = xmp.utf8()
            return jpeg(
                xmpApp1("<x:xmpmeta><rdf:Description xmpNote:HasExtendedXMP=\"$GUID\"/></x:xmpmeta>"),
                extendedXmpApp1(bytes, from = split, to = bytes.size),
                extendedXmpApp1(bytes, from = 0, to = split),
            )
        }
        val file = write(withExtended(XMP_WITH_LOCATION))

        LocationRemoval.removeFrom(file)

        assertArrayEquals(withExtended(blanked(XMP_WITH_LOCATION)), file.readBytes())
    }

    @Test
    fun `GPS in a JPEG's XMP after fill bytes is blanked in place`() {
        fun withXmp(xmp: String) = jpeg(FILL_BYTES, xmpApp1(xmp))
        val file = write(withXmp(XMP_WITH_LOCATION))

        LocationRemoval.removeFrom(file)

        assertArrayEquals(withXmp(blanked(XMP_WITH_LOCATION)), file.readBytes())
    }

    @Test
    fun `a DJI drone's position in XMP is blanked in place`() {
        fun withXmp(latitude: String, longitude: String, altitude: String) = jpeg(
            xmpApp1(
                "<x:xmpmeta><rdf:RDF><rdf:Description drone-dji:GpsLatitude=\"$latitude\" " +
                    "drone-dji:GpsLongtitude=\"$longitude\" drone-dji:AbsoluteAltitude=\"$altitude\" " +
                    "drone-dji:GimbalYawDegree=\"+90.00\"/></rdf:RDF></x:xmpmeta>",
            ),
        )
        val file = write(withXmp("+52.520000", "+13.405000", "+34.50"))

        LocationRemoval.removeFrom(file)

        assertArrayEquals(withXmp(" ".repeat(10), " ".repeat(10), " ".repeat(6)), file.readBytes())
    }

    @Test
    fun `a PNG loses its GPS tags, and its other chunks stay as they were`() {
        val original = pngWithExif(tiff(withLocation = true))
        val file = write(original)
        assertNotNull(ExifInterface(file).latLong)

        LocationRemoval.removeFrom(file)

        val stripped = file.readBytes()
        assertNull(ExifInterface(file).latLong)
        assertTrue(LocationRemoval.GPS_TAGS.none(ExifInterface(file)::hasAttribute))
        assertEquals(
            chunks(original).filter { it.first != "eXIf" },
            chunks(stripped).filter { it.first != "eXIf" },
        )
    }

    @Test
    fun `GPS in a PNG's uncompressed XMP is blanked in place, and the chunk's CRC is computed again`() {
        for (chunkOf in listOf<(String) -> ByteArray>({ itxt(it) }, { text(it) })) {
            val file = write(png(chunkOf(XMP_WITH_LOCATION)))

            LocationRemoval.removeFrom(file)

            assertArrayEquals(png(chunkOf(blanked(XMP_WITH_LOCATION))), file.readBytes())
        }
    }

    @Test
    fun `a PNG with GPS tags and GPS in XMP loses both, and every chunk's CRC holds`() {
        val file = write(png(chunk("eXIf", tiff(withLocation = true)), itxt(XMP_WITH_LOCATION)))

        LocationRemoval.removeFrom(file)

        val stripped = file.readBytes()
        assertNull(ExifInterface(file).latLong)
        assertArrayEquals(blanked(XMP_WITH_LOCATION).utf8(), ExifInterface(file).getAttributeBytes(ExifInterface.TAG_XMP))
        assertTrue(crcsHold(stripped))
    }

    // ExifInterface reads only the iTXt packet here.
    @Test
    fun `GPS in XMP inside a PNG's Exif is blanked beside a separate packet`() {
        fun withXmp(xmp: String) = png(chunk("eXIf", tiff(withLocation = false, xmp = xmp.utf8())), itxt(xmp))
        val file = write(withXmp(XMP_WITH_LOCATION))

        LocationRemoval.removeFrom(file)

        assertArrayEquals(withXmp(blanked(XMP_WITH_LOCATION)), file.readBytes())
    }

    // ImageMagick writes them beside eXIf; the version and the GPS IFD's
    // pointer are no location.
    @Test
    fun `GPS in PNG text chunks named after a GPS property is blanked in place, and every chunk's CRC holds`() {
        fun texts(latitude: String, reference: String, altitude: String) = arrayOf(
            namedText("date:create", "2026-11-02T15:03:15+00:00"),
            namedText("exif:GPSInfo", "26"),
            namedText("exif:GPSLatitude", latitude),
            namedText("exif:GPSLatitudeRef", reference),
            namedText("exif:GPSVersionID", "...."),
            chunk("iTXt", "xmp:GPSAltitude\u0000\u0000\u0000\u0000\u0000$altitude".latin1()),
        )
        val file = write(png(chunk("eXIf", tiff(withLocation = true)), *texts("52/1,31/1,12/1", "N", "34/1")))

        LocationRemoval.removeFrom(file)

        val stripped = file.readBytes()
        assertNull(ExifInterface(file).latLong)
        assertEquals(
            chunks(png(*texts(" ".repeat(14), " ", " ".repeat(4)))).filter { it.first != "eXIf" },
            chunks(stripped).filter { it.first != "eXIf" },
        )
        assertTrue(crcsHold(stripped))
    }

    @Test
    fun `GPS in a PNG's compressed XMP is reported as kept, and the file is left as it was`() {
        for (original in listOf(png(itxt(XMP_WITH_LOCATION, compressed = true)), png(ztxt(XMP_WITH_LOCATION)))) {
            val file = write(original).apply { setLastModified(MODIFIED) }

            val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(file) }

            assertEquals(Reason.COMPRESSED_XMP, kept.reason)
            assertNamesNoPath(kept, file)
            assertArrayEquals(original, file.readBytes())
            assertEquals(MODIFIED, file.lastModified())
        }
    }

    // The chunk's bytes are a hole in the file where the file system allows.
    @Test
    fun `a PNG chunk's CRC is computed again however large the chunk`() {
        val length = (64L shl 20) + 1
        val dataAt = 33L + 8
        val file = folder.newFile()
        RandomAccessFile(file, "rw").use { output ->
            output.write(png().copyOf(33))
            output.writeInt(length.toInt())
            output.write("eXIf".latin1())
            output.seek(dataAt + length)
            output.writeInt(0)
            output.write(chunk("IEND", ByteArray(0)))
        }
        val crc = CRC32().apply {
            update("eXIf".latin1())
            val zeros = ByteArray(1 shl 16)
            var left = length
            while (left > 0) {
                val count = minOf(left, zeros.size.toLong()).toInt()
                update(zeros, 0, count)
                left -= count
            }
        }

        val patches = RandomAccessFile(file, "r").use {
            PngMetadata.crcPatches(it, listOf(Fill(FileRange(dataAt, dataAt + 4), 0)))
        }

        RandomAccessFile(file, "rw").use { output ->
            patches.forEach { it.applyTo(output) }
            output.seek(dataAt + length)
            assertEquals(crc.value.toInt(), output.readInt())
        }
    }

    @Test
    fun `GPS in a WebP's own XMP chunk, which ExifInterface does not read, is blanked in place`() {
        fun withXmp(xmp: String) = webp(VP8X_WITH_XMP, riffChunk("VP8L", VP8L), riffChunk("XMP ", xmp.utf8()))
        val file = write(withXmp(XMP_WITH_LOCATION))

        LocationRemoval.removeFrom(file)

        assertArrayEquals(withXmp(blanked(XMP_WITH_LOCATION)), file.readBytes())
    }

    // ExifInterface's offsets miss the six bytes of "Exif\0\0" in a WebP.
    @Test
    fun `GPS in XMP inside a WebP's Exif chunk is blanked in place, with or without Exif's identifier`() {
        for (header in listOf(ByteArray(0), EXIF_HEADER)) {
            fun withXmp(xmp: String) = webp(
                VP8X_WITH_EXIF,
                riffChunk("VP8L", VP8L),
                riffChunk("EXIF", header + tiff(withLocation = false, xmp = xmp.utf8())),
            )
            val file = write(withXmp(XMP_WITH_LOCATION))

            LocationRemoval.removeFrom(file)

            assertArrayEquals(withXmp(blanked(XMP_WITH_LOCATION)), file.readBytes())
        }
    }

    @Test
    fun `a WebP loses its GPS tags, and its image and XMP chunks stay as they were`() {
        val xmp = riffChunk("XMP ", "<x:xmpmeta><dc:title>A walk</dc:title></x:xmpmeta>".latin1())
        val original =
            webp(VP8X_WITH_EXIF_AND_XMP, riffChunk("VP8L", VP8L), riffChunk("EXIF", tiff(withLocation = true)), xmp)
        val file = write(original)
        assertNotNull(ExifInterface(file).latLong)

        LocationRemoval.removeFrom(file)

        val stripped = file.readBytes()
        val exif = ExifInterface(file)
        assertTrue(LocationRemoval.GPS_TAGS.none(exif::hasAttribute))
        assertEquals("Rurana", exif.getAttribute(ExifInterface.TAG_MAKE))
        assertEquals(stripped.size - 8, ByteBuffer.wrap(stripped).order(ByteOrder.LITTLE_ENDIAN).getInt(4))
        assertEquals(
            riffChunks(original).filter { it.first in setOf("VP8L", "XMP ") },
            riffChunks(stripped).filter { it.first in setOf("VP8L", "XMP ") },
        )
    }

    // A thumbnail in strips apart from each other makes ExifInterface refuse
    // to write the file.
    @Test
    fun `where ExifInterface cannot write the file, the GPS values are zeroed in place, and a PNG's CRC holds`() {
        val containers = listOf<(ByteArray) -> ByteArray>(
            { jpeg(FILL_BYTES, app1(EXIF_HEADER + it)) },
            { png(chunk("eXIf", it)) },
            { webp(VP8X_WITH_EXIF, riffChunk("VP8L", VP8L), riffChunk("EXIF", EXIF_HEADER + it)) },
        )
        for (order in ORDERS) {
            val layout = TiffLayout(withLocation = true, xmp = null, thumbnailStrips = true, order = order)
            for (container in containers) {
                val file = write(container(layout.bytes()))
                assertNotNull(ExifInterface(file).latLong)

                LocationRemoval.removeFrom(file)

                assertArrayEquals(container(layout.zeroed()), file.readBytes())
                assertNull(ExifInterface(file).latLong)
            }
        }
    }

    // As ExifInterface's own write leaves a file when an OutOfMemoryError
    // stops it.
    @Test
    fun `a write that fails, even with an error, cuts nothing short, and the GPS values are zeroed in place`() {
        val layout = TiffLayout(withLocation = true, xmp = null)
        val containers = listOf<Pair<FileFormat, (ByteArray) -> ByteArray>>(
            FileFormat.JPEG to { jpeg(app1(EXIF_HEADER + it)) },
            FileFormat.PNG to { png(chunk("eXIf", it)) },
            FileFormat.WEBP to { webp(VP8X_WITH_EXIF, riffChunk("VP8L", VP8L), riffChunk("EXIF", EXIF_HEADER + it)) },
        )
        for ((format, container) in containers) {
            val file = write(container(layout.bytes()))

            PhotoLocation.removeFrom(file, format) { copy ->
                copy.writeBytes("RIFF".latin1())
                throw OutOfMemoryError("Java heap space")
            }

            assertArrayEquals(container(layout.zeroed()), file.readBytes())
            assertEquals(listOf("media"), file.parentFile?.list()?.toList())
        }
    }

    @Test
    fun `a TIFF-based photo has its GPS values zeroed and GPS in its XMP blanked, and nothing else changes`() {
        val blankedXmp = blanked(XMP_WITH_LOCATION).utf8()
        for (order in ORDERS) {
            val file = write(TiffLayout(withLocation = true, xmp = XMP_WITH_LOCATION.utf8(), order = order).bytes())
            assertNotNull(ExifInterface(file).latLong)

            LocationRemoval.removeFrom(file)

            val expected = TiffLayout(withLocation = true, xmp = blankedXmp, order = order).zeroed()
            assertArrayEquals(expected, file.readBytes())
            val exif = ExifInterface(file)
            assertNull(exif.latLong)
            assertTrue(LocationRemoval.GPS_TAGS.all { tag -> exif.getAttributeBytes(tag)?.all { it == 0.toByte() } ?: true })
        }
    }

    @Test
    fun `an ORF, a RW2 and a RAF's JPEG have their GPS values zeroed in place`() {
        for (magic in listOf(0x4F52, 0x5352, 0x55)) {
            val layout = TiffLayout(withLocation = true, xmp = null, order = ByteOrder.LITTLE_ENDIAN, magic = magic)
            val file = write(layout.bytes())

            LocationRemoval.removeFrom(file)

            assertArrayEquals(layout.zeroed(), file.readBytes())
        }
        val layout = TiffLayout(withLocation = true, xmp = null)
        val file = write(raf(jpeg(app1(EXIF_HEADER + layout.bytes()))))

        LocationRemoval.removeFrom(file)

        assertArrayEquals(raf(jpeg(app1(EXIF_HEADER + layout.zeroed()))), file.readBytes())
    }

    // The reader does not look into a RW2's JpgFromRaw (tag 0x2E).
    @Test
    fun `GPS that only ExifInterface still finds is reported as kept, and the file is left as it was`() {
        val jpeg = jpeg(app1(EXIF_HEADER + tiff(withLocation = true)))
        val original = ByteBuffer.allocate(26 + jpeg.size).order(ByteOrder.LITTLE_ENDIAN)
            .put("IIU\u0000".latin1()).putInt(8)
            .putShort(1).putShort(0x2E).putShort(7).putInt(jpeg.size).putInt(26).putInt(0)
            .put(jpeg).array()
        val file = write(original).apply { setLastModified(MODIFIED) }

        val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(file) }

        assertEquals(Reason.GPS_TAGS, kept.reason)
        assertArrayEquals(original, file.readBytes())
        assertEquals(MODIFIED, file.lastModified())
    }

    // ExifInterface reads a value by the size its tag should have and can be
    // far off: here 192 bytes from 68 for the latitude, and from offset 10
    // for the altitude, where the entry holds its four bytes itself. In 128
    // bytes it finds nothing there; in 300 it finds Make and the bytes after.
    @Test
    fun `a GPS value of an unexpected type is zeroed where it is, and reported where ExifInterface misreads it`() {
        val latitude = ByteBuffer.allocate(24).putInt(52).putInt(1).putInt(31).putInt(1).putInt(12).putInt(1).array()
        for (size in listOf(128, 300)) {
            val file = write(undefinedGps(latitude, altitude = byteArrayOf(0, 0, 0, 10), size))

            val failure = runCatching { LocationRemoval.removeFrom(file) }.exceptionOrNull()

            if (size == 128) assertNull(failure) else assertEquals(Reason.GPS_TAGS, (failure as LocationKept).reason)
            assertArrayEquals(undefinedGps(ByteArray(24), ByteArray(4), size), file.readBytes())
            assertEquals("Rurana", ExifInterface(file).getAttribute(ExifInterface.TAG_MAKE))
        }
    }

    @Test
    fun `only GPS values inside the Exif are zeroed, wherever IFD0 or IFD1 points to the GPS IFD and however`() {
        for (order in ORDERS) {
            for (layout in listOf(
                GpsTiff(order),
                GpsTiff(order, shortPointer = true),
                GpsTiff(order, pointerInIfd1 = true),
                GpsTiff(order, otherTag = true),
            )) {
                val file = write(layout.bytes())

                LocationRemoval.removeFrom(file)

                assertArrayEquals(layout.bytes(zeroed = true), file.readBytes())
            }
        }

        val outside = GpsTiff(latitudeAt = GpsTiff().size + 20)
        val next = ByteArray(64) { 0x41 }
        val file = write(heif("heic", 0, exifItem(outside.bytes(), header = true), next))

        LocationRemoval.removeFrom(file)

        val expected = heif("heic", 0, exifItem(outside.bytes(zeroed = true), header = true), next)
        assertArrayEquals(expected, file.readBytes())

        val large = GpsTiff(undefinedLatitude = ByteArray(64 * 1024 + 1) { 0x41 })
        val keeping = write(heif("heic", 0, exifItem(large.bytes(), header = true), "<x:xmpmeta/>".latin1()))
        val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(keeping) }
        assertEquals(Reason.UNREADABLE, kept.reason)
    }

    @Test
    fun `a HEIF or AVIF photo's Exif and XMP items are zeroed and blanked in place, wherever iloc puts them`() {
        fun located(
            header: Boolean = true,
            order: ByteOrder = ByteOrder.BIG_ENDIAN,
            build: (ByteArray, ByteArray) -> ByteArray,
        ): Pair<ByteArray, ByteArray> {
            val layout = TiffLayout(withLocation = true, xmp = null, order = order)
            return build(exifItem(layout.bytes(), header), XMP_WITH_LOCATION.utf8()) to
                build(exifItem(layout.zeroed(), header), blanked(XMP_WITH_LOCATION).utf8())
        }
        val cases = listOf(
            located { exif, xmp -> heif("heic", 0, exif, xmp) },
            located(header = false) { exif, xmp -> heif("avif", 0, exif, xmp) },
            located { exif, xmp -> heif("heic", 1, exif, xmp) },
            located(order = ByteOrder.LITTLE_ENDIAN) { exif, xmp -> heif("heic", 0, exif, xmp) },
            located { exif, xmp -> heif("heic", 0, exif, xmp, Iloc(version = 0)) },
            located { exif, xmp -> heif("heic", 0, exif, xmp, Iloc(version = 2), infeVersion = 3, firstId = 70_000) },
            located { exif, xmp -> heif("heic", 0, exif, xmp, Iloc(fieldBytes = 8, indexBytes = 4, splitExif = true)) },
            located { exif, xmp -> heif("heic", 0, exif, xmp, Iloc(baseBytes = 4)) },
            located { exif, xmp -> heif("heic", 1, exif, xmp, Iloc(baseBytes = 8)) },
            located { exif, xmp -> heif("heic", 0, exif, xmp, Iloc(lastToTheEnd = true)) },
            located { exif, xmp -> heif("heic", 0, exif, xmp, xmpType = "Application/RDF+XML; charset=utf-8") },
        )
        for ((original, expected) in cases) {
            val file = write(original)

            LocationRemoval.removeFrom(file)

            assertArrayEquals(expected, file.readBytes())
        }
    }

    @Test
    fun `a HEIF item iloc does not place, or compressed XMP with GPS, is reported, and the file is left as it was`() {
        val exif = exifItem(tiff(withLocation = true), header = true)
        val clean = exifItem(tiff(withLocation = false), header = true)
        val cases = listOf(
            Reason.UNREADABLE to heif("heic", method = 2, exif, "<x:xmpmeta/>".latin1()),
            Reason.UNREADABLE to heif("heic", 0, exif, "<x:xmpmeta/>".latin1(), Iloc(splitExif = true, gap = 1)),
            Reason.COMPRESSED_XMP to heif("heic", 0, clean, deflate(XMP_WITH_LOCATION.utf8()), xmpEncoding = "deflate"),
        )
        for ((reason, original) in cases) {
            val file = write(original).apply { setLastModified(MODIFIED) }

            val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(file) }

            assertEquals(reason, kept.reason)
            assertArrayEquals(original, file.readBytes())
            assertEquals(MODIFIED, file.lastModified())
        }
    }

    // Each extent of 0 bytes; read one by one, they would take minutes.
    @Test(timeout = 10_000)
    fun `an iloc whose extents take no bytes is reported at once`() {
        val iloc = ByteBuffer.allocate(8 + 8 * 65_535).putInt(0x01000000).putShort(0).putShort(-1)
        for (id in 1..65_535) iloc.putShort(id.toShort()).putShort(0).putShort(0).putShort(-1)
        val original = ftyp("heic", "mif1", "heic") + container(
            "meta",
            ByteArray(4),
            handler(),
            box("iinf", ByteBuffer.allocate(6).putInt(0).putShort(1).array() + infe(2, "Exif")),
            box("iloc", iloc.array()),
        )
        val file = write(original)

        val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(file) }

        assertEquals(Reason.UNREADABLE, kept.reason)
        assertArrayEquals(original, file.readBytes())
    }

    // Read one byte or one tag at a time, each would take far longer.
    @Test(timeout = 10_000)
    fun `long runs of fill bytes, of end tags that close nothing and of text without its NULs are read in time`() {
        val count = 100_000
        val strays = "<a>".repeat(count) + "</b>".repeat(count) + "<x exif:GPSLatitude=\"52,31.2N\"/>"
        assertEquals(listOf("52,31.2N"), XmpGps.values(strays).map { strays.substring(it) })

        fun withXmp(xmp: String) = jpeg(ByteArray(8 shl 20) { -1 }, xmpApp1(xmp))
        val filled = write(withXmp(XMP_WITH_LOCATION))
        LocationRemoval.removeFrom(filled)
        assertArrayEquals(withXmp(blanked(XMP_WITH_LOCATION)), filled.readBytes())

        val unterminated = png(chunk("iTXt", PNG_XMP_KEYWORD + ByteArray(16 shl 20) { 1 }))
        val file = write(unterminated)
        LocationRemoval.removeFrom(file)
        assertArrayEquals(unterminated, file.readBytes())
    }

    @Test
    fun `a CR3's GPS IFD in Canon's CMT4 box is zeroed in place`() {
        val file = write(cr3(gpsIfd(located = true)))

        LocationRemoval.removeFrom(file)

        assertArrayEquals(cr3(gpsIfd(located = false)), file.readBytes())
    }

    @Test
    fun `a JPEG XL's Exif and XMP boxes are zeroed and blanked in place, and compressed ones are reported`() {
        val layout = TiffLayout(withLocation = true, xmp = null)
        val file = write(
            jxl(box("Exif", exifItem(layout.bytes(), header = true)), box("xml ", XMP_WITH_LOCATION.utf8())),
        )

        LocationRemoval.removeFrom(file)

        assertArrayEquals(
            jxl(box("Exif", exifItem(layout.zeroed(), header = true)), box("xml ", blanked(XMP_WITH_LOCATION).utf8())),
            file.readBytes(),
        )

        val compressed = jxl(box("brob", "Exif".latin1() + ByteArray(32) { 1 }))
        val keeping = write(compressed).apply { setLastModified(MODIFIED) }
        val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(keeping) }
        assertEquals(Reason.UNREADABLE, kept.reason)
        assertArrayEquals(compressed, keeping.readBytes())
        assertEquals(MODIFIED, keeping.lastModified())
    }

    @Test
    fun `a file without a location is not written to`() {
        val noLocation = blanked(XMP_WITH_LOCATION)
        for (original in listOf(
            jpeg(app1(EXIF_HEADER + tiff(withLocation = false))),
            jpeg(app1(EXIF_HEADER + TiffLayout(withLocation = true, xmp = null).zeroed())),
            jpeg(app1(EXIF_HEADER + TiffLayout(withLocation = true, xmp = null).zeroed(keepVersion = true))),
            jpeg(),
            jpeg(xmpApp1(noLocation)),
            jpeg(app1(XMP_HEADER + "<x:xmpmeta><dc:title>\u00C4</dc:title></x:xmpmeta>".utf8())),
            jpeg(xmpApp1("<x:xmpmeta><rdf:Description dc:source=\"Bob's x:GPSnote='\" dc:format='a'/></x:xmpmeta>")),
            jpeg(xmpApp1("<x:xmpmeta><rdf:Description exif:GPSVersionID=\"2.3.0.0\"/></x:xmpmeta>")),
            pngWithExif(tiff(withLocation = false)),
            png(),
            png(itxt(noLocation)),
            png(itxt(noLocation, compressed = true)),
            png(namedText("exif:GPSVersionID", "...."), namedText("exif:GPSInfo", "26")),
            webp(VP8X_WITH_XMP, riffChunk("VP8L", VP8L), riffChunk("XMP ", "<x:xmpmeta/>".latin1())),
            tiff(withLocation = false, xmp = noLocation.utf8()),
            TiffLayout(withLocation = true, xmp = null).zeroed(keepVersion = true),
            heif("heic", 0, exifItem(tiff(withLocation = false), header = true), noLocation.utf8()),
            cr3(gpsIfd(located = false)),
            jxl(box("brob", "jumb".latin1() + ByteArray(32) { 1 })),
            ftyp("isom", "isom", "mp41") + container("moov", container("udta", box("\u00A9nam", "A walk".latin1()))) +
                box("mdat", ByteArray(64)),
            ftyp("qt  ", "qt  ") + container("moov", appleMeta(APPLE_LOCATION_KEY to ByteArray(18))),
            ftyp("isom", "isom") + container(
                "moov",
                container("udta", box("\u00A9xyz", ByteArray(18)), box("loci", ByteArray(0))),
                container("meta", ByteArray(4), handler(), box("ilst", item("\u00A9xyz", ByteArray(18)))),
            ) + box("gps ", ByteArray(16)) + box("mdat", ByteArray(16)),
            "GIF89a".latin1() + ByteArray(32),
        )) {
            val file = write(original).apply { setLastModified(MODIFIED) }

            LocationRemoval.removeFrom(file)

            assertArrayEquals(original, file.readBytes())
            assertEquals(MODIFIED, file.lastModified())
        }
    }

    @Test
    fun `every GPS tag ExifInterface knows is removed`() {
        val known = ExifInterface::class.java.fields
            .filter { Modifier.isStatic(it.modifiers) && it.name.startsWith("TAG_GPS_") }
            .map { it.get(null) as String }

        assertEquals(known.toSet(), LocationRemoval.GPS_TAGS.toSet())
        assertEquals(32, LocationRemoval.GPS_TAGS.size)
    }

    @Test
    fun `formats are told apart by their first bytes, not by a name`() {
        assertEquals(FileFormat.JPEG, FileFormat.of(jpeg()))
        assertEquals(FileFormat.PNG, FileFormat.of(png()))
        assertEquals(FileFormat.WEBP, FileFormat.of("RIFF\u0000\u0000\u0000\u0000WEBPVP8 ".latin1()))
        assertEquals(FileFormat.HEIF, FileFormat.of(ftyp("heic", "mif1", "heic")))
        assertEquals(FileFormat.HEIF, FileFormat.of(ftyp("mif1", "heic")))
        assertEquals(FileFormat.HEIF, FileFormat.of(ftyp("avif", "mif1", "miaf")))
        assertEquals(FileFormat.BOXES, FileFormat.of(ftyp("isom", "isom", "iso2", "avc1", "mp41")))
        assertEquals(FileFormat.BOXES, FileFormat.of(ftyp("qt  ", "qt  ")))
        assertEquals(FileFormat.BOXES, FileFormat.of(ftyp("3gp4", "isom", "3gp4")))
        assertEquals(FileFormat.BOXES, FileFormat.of(box("wide", ByteArray(0)) + box("mdat", ByteArray(4))))
        assertEquals(FileFormat.BOXES, FileFormat.of(ftyp("crx ", "crx ", "isom")))
        assertEquals(FileFormat.BOXES, FileFormat.of(jxl()))
        assertEquals(FileFormat.OTHER, FileFormat.of("MM\u0000\u002A".latin1()))
        assertEquals(FileFormat.OTHER, FileFormat.of("GIF89a".latin1()))
        assertEquals(FileFormat.OTHER, FileFormat.of(ByteArray(0)))
    }

    @Test
    fun `a video's location boxes, Apple location keys and GPS in XMP are blanked in place, and nothing else changes`() {
        val xyz = "\u0000\u0012\u0015\u00C7+52.5200+013.4050/".latin1()
        val loci = ByteArray(24) { 7 }
        val iso6709 = "+52.5200+013.4050+034.000/".latin1()
        fun video(
            xyzBox: ByteArray,
            lociBox: ByteArray,
            gpsBox: ByteArray,
            location: ByteArray,
            xmp: String,
        ): ByteArray = ftyp("qt  ", "qt  ") +
            container(
                "moov",
                container("udta", xyzBox, box("\u00A9nam", "A walk".latin1()), box("XMP_", xmp.utf8())),
                appleMeta(APPLE_LOCATION_KEY to location, "com.apple.quicktime.make" to "Apple".latin1()),
                container("trak", container("udta", lociBox), container("mdia", box("mdhd", ByteArray(24) { 3 }))),
            ) +
            gpsBox + box("uuid", XMP_UUID + xmp.utf8()) + box("mdat", ByteArray(64) { 9 })
        val file = write(
            video(box("\u00A9xyz", xyz), box("loci", loci), box("gps ", ByteArray(16) { 1 }), iso6709, XMP_WITH_LOCATION),
        )

        LocationRemoval.removeFrom(file)

        val blankedXmp = blanked(XMP_WITH_LOCATION)
        val free = { size: Int -> box("free", ByteArray(size)) }
        assertArrayEquals(
            video(free(xyz.size), free(loci.size), free(16), ByteArray(iso6709.size), blankedXmp),
            file.readBytes(),
        )
    }

    @Test
    fun `a location in ISO metadata, a 64-bit box and a last box sized to the end of the file is blanked too`() {
        val xyz = "+52.5200+013.4050/".latin1()
        val files = listOf<(Boolean) -> ByteArray>(
            { blank ->
                ftyp("isom", "isom") + box64("mdat", ByteArray(16) { 9 }) +
                    box64("moov", container("udta", if (blank) box("free", ByteArray(xyz.size)) else box("\u00A9xyz", xyz)))
            },
            { blank ->
                ftyp("isom", "isom") + box64(if (blank) "free" else "gps ", if (blank) ByteArray(8) else ByteArray(8) { 1 }) +
                    box("mdat", ByteArray(16) { 9 })
            },
            { blank ->
                ftyp("isom", "isom") + box("mdat", ByteArray(16) { 9 }) +
                    boxToTheEnd("moov", container("udta", if (blank) box("free", ByteArray(xyz.size)) else box("\u00A9xyz", xyz)))
            },
            { blank ->
                val xmp = if (blank) blanked(XMP_WITH_LOCATION) else XMP_WITH_LOCATION
                ftyp("mp42", "isom") + container(
                    "moov",
                    container(
                        "meta",
                        ByteArray(4),
                        handler(),
                        box("xml ", ByteArray(4) + xmp.utf8()),
                        box("ilst", if (blank) box("free", ByteArray(item("\u00A9xyz", xyz).size - 8)) else item("\u00A9xyz", xyz)),
                    ),
                )
            },
        )
        for (video in files) {
            val file = write(video(false))

            LocationRemoval.removeFrom(file)

            assertArrayEquals(video(true), file.readBytes())
        }
    }

    @Test
    fun `a video's location is found in QuickTime, 3GPP, Apple and XMP boxes`() {
        val located = listOf(
            container("moov", container("udta", box("\u00A9xyz", "+52.5200+013.4050/".latin1()))),
            container("moov", container("trak", container("udta", box("loci", ByteArray(20) { 1 })))),
            container("moov", appleMeta(APPLE_LOCATION_KEY to "+52.5200+013.4050/".latin1())),
            container("moov", appleMeta("com.apple.quicktime.location.accuracy.horizontal" to "5.0".latin1())),
            container("moov", isoMeta(APPLE_LOCATION_KEY to "+52.5200+013.4050/".latin1())),
            container("moov", container("udta", box("XMP_", XMP_WITH_LOCATION.utf8()))),
            box("uuid", XMP_UUID + XMP_WITH_LOCATION.utf8()),
            box("gps ", ByteArray(8) { 1 }),
            container("moov", container("gps0", ByteArray(8) { 1 })),
            container(
                "moov",
                container(
                    "udta",
                    container("meta", ByteArray(4), box("ilst", item("\u00A9xyz", "+52.5200+013.4050/".latin1()))),
                ),
            ),
        )
        for (boxes in located) {
            assertTrue(removalChanges(ftyp("isom", "isom") + boxes + box("mdat", ByteArray(16))))
        }
    }

    @Test
    fun `media data and boxes without a location are no location`() {
        val unlocated = listOf(
            box("mdat", "\u00A9xyz loci GPSLatitude".latin1()),
            container("moov", container("udta", box("\u00A9nam", "A walk".latin1()))),
            container("moov", appleMeta("com.android.version" to "14".latin1())),
            container("moov", appleMeta(APPLE_LOCATION_KEY to ByteArray(18))),
            container("moov", container("meta", handler(), keys(APPLE_LOCATION_KEY))),
            container("moov", container("trak", container("mdia", box("\u00A9xyz", ByteArray(8) { 1 })))),
            container("moov", container("udta", box("\u00A9xyz", ByteArray(8)), box("loci", ByteArray(0)))),
            container("moov", container("udta", box("XMP_", blanked(XMP_WITH_LOCATION).utf8()))),
            box("uuid", XMP_UUID + "<x:xmpmeta/>".latin1()),
        )
        for (boxes in unlocated) {
            assertFalse(removalChanges(ftyp("isom", "isom") + boxes))
        }
    }

    @Test
    fun `large boxes, boxes to the end of the file and broken sizes are walked safely`() {
        val large = box64("mdat", ByteArray(8))
        val location = container("moov", container("udta", box("\u00A9xyz", ByteArray(8) { 1 })))
        val toTheEnd = boxToTheEnd("mdat", ByteArray(8))
        val tooLong = ByteBuffer.allocate(8).putInt(4096).put("moov".latin1()).array()

        assertTrue(removalChanges(ftyp("isom") + large + location))
        assertFalse(removalChanges(ftyp("isom") + toTheEnd + location))
        assertFalse(removalChanges(ftyp("isom") + tooLong + location))
        assertFalse(removalChanges(ftyp("isom") + ByteArray(3)))
    }

    @Test
    fun `more boxes than the walk reads, or an Apple keys box too large to read, is reported as kept`() {
        val frees = ByteArrayOutputStream().apply { repeat(100_001) { write(box("free", ByteArray(0))) } }.toByteArray()
        val location = container("moov", container("udta", box("\u00A9xyz", "+52.5200+013.4050/".latin1())))
        val heif = heif("heic", 0, exifItem(tiff(withLocation = true), header = true), "<x:xmpmeta/>".latin1())
        val ftypBytes = ftyp("heic", "mif1", "heic").size
        for (original in listOf(
            ftyp("isom", "isom") + frees + location,
            ftyp("qt  ", "qt  ") + container(
                "moov",
                container(
                    "meta",
                    handler(),
                    keys("x".repeat(1 shl 20), APPLE_LOCATION_KEY),
                    container("ilst", item(2, "+52.5200+013.4050/".latin1())),
                ),
            ),
            heif.copyOf(ftypBytes) + frees + heif.copyOfRange(ftypBytes, heif.size),
        )) {
            val file = write(original)

            val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(file) }

            assertEquals(Reason.UNREADABLE, kept.reason)
            assertArrayEquals(original, file.readBytes())
        }
    }

    @Test
    fun `a video's location that only MediaMetadataRetriever finds is reported, with the rest blanked`() {
        fun video(xyz: ByteArray) = ftyp("isom", "isom") + container("moov", container("udta", xyz))
        val file = write(video(box("\u00A9xyz", "+52.5200+013.4050/".latin1())))

        val kept = assertThrows(LocationKept::class.java) { IsoLocation.removeFrom(file) { true } }

        assertEquals(Reason.VIDEO_ELSEWHERE, kept.reason)
        assertArrayEquals(video(box("free", ByteArray(18))), file.readBytes())
    }

    // The packet's bytes are a hole in the file where the file system allows.
    @Test
    fun `an XMP packet too large to read is reported, and the rest is blanked`() {
        val xyz = box("\u00A9xyz", "+52.5200+013.4050/".latin1())
        val xmpLength = (64L shl 20) + 1
        val head = ftyp("isom", "isom")
        fun moovHeader(xyzBox: ByteArray): ByteArray =
            ByteBuffer.allocate(16).putInt((16 + xyzBox.size + 8 + xmpLength).toInt()).put("moov".latin1())
                .putInt((8 + xyzBox.size + 8 + xmpLength).toInt()).put("udta".latin1()).array() +
                xyzBox + ByteBuffer.allocate(8).putInt((8 + xmpLength).toInt()).put("XMP_".latin1()).array()
        val start = head + moovHeader(xyz)
        val file = folder.newFile()
        RandomAccessFile(file, "rw").use { output ->
            output.write(start)
            output.setLength(start.size + xmpLength)
        }

        val kept = assertThrows(LocationKept::class.java) { LocationRemoval.removeFrom(file) }

        assertEquals(Reason.XMP_TOO_LARGE, kept.reason)
        val expected = head + moovHeader(box("free", ByteArray(18)))
        RandomAccessFile(file, "r").use { input ->
            assertArrayEquals(expected, ByteArray(expected.size).also(input::readFully))
        }
    }

    @Test
    fun `GPS values are found as attributes and as elements, and nothing else`() {
        val xmp = "<!DOCTYPE x>" +
            "<rdf:Description xmlns:GPSx=\"urn:x\" exif:GPSLatitude = '52,31.2N' dc:note=\"exif:GPS\">" +
            "<exif:GPSLongitude rdf:parseType=\"Resource\"><rdf:value>13,24.3E</rdf:value><!-- a > b --></exif:GPSLongitude>" +
            "<exif:GPSAltitude><![CDATA[34/1]]></exif:GPSAltitude><exif:GPSSpeed>  \n </exif:GPSSpeed></b>" +
            "<exif:GPSTrack/><exif:GPSDOP a=\">\">2</exif:GPSDOP><exif:GPSStatus exif:GPSMapDatum=\"\"/>" +
            "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">A walk</rdf:li></rdf:Alt></dc:title>" +
            "<rdf:Description xmlns=\"http://ns.adobe.com/exif/1.0/\"><GPSDestLatitude>48,8.5N</GPSDestLatitude>" +
            "</rdf:Description></rdf:Description>"

        assertEquals(
            listOf("52,31.2N", "13,24.3E", "34/1", "2", "48,8.5N"),
            XmpGps.values(xmp).map { xmp.substring(it) },
        )
    }

    @Test
    fun `a location's values are found in DJI's names, in rdf value and in a structure, and only in attributes`() {
        val xmp = "<rdf:Description drone-dji:GpsLatitude=\"+52.520000\" drone-dji:Longitude=\"+13.405000\" " +
            "drone-dji:AbsoluteAltitude=\"+34.50\" drone-dji:LRFTargetDistance=\"123.4\" " +
            "drone-dji:LRFTargetLat=\"52.521234\" drone-dji:GimbalYawDegree=\"+90.00\" " +
            "dc:source=\"Bob's x:GPSnote='\" dc:format='image/png'>" +
            "<exif:GPSLatitude rdf:value=\"52,31.2N\" xml:lang=\"x-default\"/>" +
            "<Iptc4xmpExt:LocationCreated><rdf:Bag><rdf:li Iptc4xmpExt:GPSLongitude=\"13,24.3E\" " +
            "Iptc4xmpExt:City=\"Berlin\"/></rdf:Bag></Iptc4xmpExt:LocationCreated>" +
            "<exif:GPSAltitude><rdf:Description exif:Value=\"34/1\" rdf:about=\"\"/></exif:GPSAltitude>" +
            "</rdf:Description>"

        assertEquals(
            listOf("+52.520000", "+13.405000", "+34.50", "52.521234", "52,31.2N", "13,24.3E", "34/1"),
            XmpGps.values(xmp).map { xmp.substring(it) },
        )
    }

    @Test
    fun `the version alone is no location in XMP either`() {
        val version = "<rdf:Description exif:GPSVersionID=\"2.3.0.0\"><exif:GPSVersionID>2.3.0.0</exif:GPSVersionID>" +
            "</rdf:Description>"
        val located =
            version.replace("</rdf:Description>", "<exif:GPSLatitude>52,31.2N</exif:GPSLatitude></rdf:Description>")

        assertEquals(emptyList<IntRange>(), XmpGps.values(version))
        assertEquals(
            listOf("2.3.0.0", "2.3.0.0", "52,31.2N"),
            XmpGps.values(located).map { located.substring(it) },
        )
    }

    @Test
    fun `the device channel's answer names the reason or an unexpected error's type, and nothing more`() {
        assertNull(LocationRemoval.failureOf {})
        assertEquals("GPS in compressed XMP", LocationRemoval.failureOf { throw LocationKept(Reason.COMPRESSED_XMP) })
        val errors = listOf(IOException("/data/media"), OutOfMemoryError("Java heap space"), StackOverflowError())
        for (error in errors) {
            assertEquals(error.javaClass.simpleName, LocationRemoval.failureOf { throw error })
        }
    }

    private fun write(bytes: ByteArray): File = File(folder.newFolder(), "media").apply { writeBytes(bytes) }

    // The removal writes to a file only where it finds a location.
    private fun removalChanges(bytes: ByteArray): Boolean {
        val file = write(bytes)
        LocationRemoval.removeFrom(file)
        return !file.readBytes().contentEquals(bytes)
    }

    private fun assertNamesNoPath(kept: Exception, file: File) {
        val message = kept.message!!
        assertFalse(message.contains(file.name) || message.contains("/") || message.contains(folder.root.name))
    }

    private companion object {
        const val GPS_INFO = 0x8825
        const val MODIFIED = 1_600_000_000_000L
        val ORDERS = listOf(ByteOrder.BIG_ENDIAN, ByteOrder.LITTLE_ENDIAN)
        val EXIF_HEADER = "Exif\u0000\u0000".latin1()
        val XMP_HEADER = "http://ns.adobe.com/xap/1.0/\u0000".latin1()
        val EXTENDED_XMP_HEADER = "http://ns.adobe.com/xmp/extension/\u0000".latin1()
        const val GUID = "0123456789ABCDEF0123456789ABCDEF"
        val XMP_UUID = hex("BE7ACFCB97A942E89C71999491E3AFAC")
        val CANON_UUID = hex("85C0B687820F11E08111F4CE462B6A48")
        val XMP_WITH_LOCATION =
            "<?xpacket begin=\"\uFEFF\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?><x:xmpmeta xmlns:x=\"adobe:ns:meta/\">" +
                "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"><rdf:Description " +
                "xmlns:exif=\"http://ns.adobe.com/exif/1.0/\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n" +
                "  exif:GPSLatitude=\"52,31.2N\" exif:GPSLongitude='13,24.3E' dc:format=\"image/jpeg\">\n" +
                "<exif:GPSAltitude>34/1</exif:GPSAltitude><dc:title>\u00C4 walk in Berlin</dc:title>" +
                "</rdf:Description></rdf:RDF></x:xmpmeta><?xpacket end=\"w\"?>"
        val GPS_VALUES = listOf("52,31.2N", "13,24.3E", "34/1")
        const val APPLE_LOCATION_KEY = "com.apple.quicktime.location.ISO6709"

        fun String.latin1(): ByteArray = toByteArray(Charsets.ISO_8859_1)

        fun String.utf8(): ByteArray = toByteArray(Charsets.UTF_8)

        fun hex(digits: String): ByteArray = digits.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

        fun blanked(xmp: String): String =
            GPS_VALUES.fold(xmp) { text, value -> text.replace(value, " ".repeat(value.length)) }

        fun deflate(bytes: ByteArray): ByteArray =
            ByteArrayOutputStream().also { out -> DeflaterOutputStream(out).use { it.write(bytes) } }.toByteArray()

        // Entropy-coded data without 0xFF, which ExifInterface copies as it is.
        val SCAN = ByteArray(32) { (it * 7 + 1).toByte() }

        // JPEG's fill bytes, which may come before any marker.
        val FILL_BYTES = ByteArray(3) { -1 }

        fun segment(marker: Int, payload: ByteArray): ByteArray =
            ByteBuffer.allocate(4 + payload.size).put(0xFF.toByte()).put(marker.toByte())
                .putShort((2 + payload.size).toShort()).put(payload).array()

        fun app1(payload: ByteArray): ByteArray = segment(0xE1, payload)

        fun xmpApp1(xmp: String): ByteArray = app1(XMP_HEADER + xmp.utf8())

        fun extendedXmpApp1(xmp: ByteArray, from: Int, to: Int): ByteArray = app1(
            EXTENDED_XMP_HEADER + GUID.latin1() + ByteBuffer.allocate(8).putInt(xmp.size).putInt(from).array() +
                xmp.copyOfRange(from, to),
        )

        // A 16 x 16 grey baseline JPEG's structure: the segments, then SOF0,
        // SOS, the scan and EOI.
        fun jpeg(vararg segments: ByteArray): ByteArray =
            byteArrayOf(0xFF.toByte(), 0xD8.toByte()) + segments.fold(ByteArray(0), ByteArray::plus) +
                segment(0xC0, byteArrayOf(8, 0, 16, 0, 16, 1, 1, 0x11, 0)) +
                segment(0xDA, byteArrayOf(1, 1, 0, 0, 63, 0)) + SCAN +
                byteArrayOf(0xFF.toByte(), 0xD9.toByte())

        fun chunk(type: String, data: ByteArray): ByteArray {
            val crc = CRC32().apply { update(type.latin1()); update(data) }
            return ByteBuffer.allocate(12 + data.size).putInt(data.size).put(type.latin1()).put(data)
                .putInt(crc.value.toInt()).array()
        }

        val PNG_XMP_KEYWORD = "XML:com.adobe.xmp\u0000".latin1()

        // Without a language or a translated keyword, as ExifInterface reads it.
        fun itxt(xmp: String, compressed: Boolean = false): ByteArray = chunk(
            "iTXt",
            PNG_XMP_KEYWORD + byteArrayOf(if (compressed) 1 else 0, 0, 0, 0) +
                xmp.utf8().let { if (compressed) deflate(it) else it },
        )

        fun ztxt(xmp: String): ByteArray = chunk("zTXt", PNG_XMP_KEYWORD + byteArrayOf(0) + deflate(xmp.utf8()))

        fun text(xmp: String): ByteArray = chunk("tEXt", PNG_XMP_KEYWORD + xmp.utf8())

        fun namedText(keyword: String, text: String): ByteArray = chunk("tEXt", "$keyword\u0000$text".latin1())

        // A 2 x 2 RGB PNG; the chunks go right after IHDR.
        fun png(vararg chunks: ByteArray): ByteArray {
            val header = ByteBuffer.allocate(13).putInt(2).putInt(2).put(8).put(2).put(0).put(0).put(0).array()
            val rows = byteArrayOf(0, -1, 0, 0, 0, -1, 0, 0, 0, 0, -1, -1, -1, -1)
            return "\u0089PNG\r\n\u001A\n".latin1() + chunk("IHDR", header) +
                chunks.fold(ByteArray(0), ByteArray::plus) + chunk("IDAT", deflate(rows)) + chunk("IEND", ByteArray(0))
        }

        fun pngWithExif(tiff: ByteArray): ByteArray = png(chunk("eXIf", tiff))

        fun tiff(withLocation: Boolean, xmp: ByteArray? = null): ByteArray = TiffLayout(withLocation, xmp).bytes()

        // Big-endian: IFD0 at 8 with Make and the GPS IFD's pointer; the GPS
        // IFD at 38 with the latitude as 24 UNDEFINED bytes at 68 and the
        // altitude as 4 UNDEFINED bytes in its entry; Make's value at 92.
        fun undefinedGps(latitude: ByteArray, altitude: ByteArray, size: Int): ByteArray {
            val buffer = ByteBuffer.allocate(size)
            buffer.put("MM".latin1()).putShort(42).putInt(8)
            buffer.putShort(2)
            buffer.putShort(0x010F).putShort(2).putInt(7).putInt(92)
            buffer.putShort(GPS_INFO.toShort()).putShort(4).putInt(1).putInt(38)
            buffer.putInt(0)
            buffer.putShort(2)
            buffer.putShort(2).putShort(7).putInt(24).putInt(68)
            buffer.putShort(6).putShort(7).putInt(4).put(altitude)
            buffer.putInt(0)
            buffer.put(latitude).put("Rurana\u0000".latin1())
            while (buffer.hasRemaining()) buffer.put(0x55)
            return buffer.array()
        }

        // Little-endian, as a CR3's CMT4: a TIFF header and right after it
        // the GPS IFD, with the latitude's reference in its entry and the
        // latitude after the IFD.
        fun gpsIfd(located: Boolean): ByteArray {
            val buffer = ByteBuffer.allocate(62).order(ByteOrder.LITTLE_ENDIAN)
            buffer.put("II".latin1()).putShort(42).putInt(8)
            buffer.putShort(2)
            buffer.putShort(1).putShort(2).putInt(2).put((if (located) "N" else "\u0000").latin1()).put(ByteArray(3))
            buffer.putShort(2).putShort(5).putInt(3).putInt(38)
            buffer.putInt(0)
            if (located) buffer.putInt(52).putInt(1).putInt(31).putInt(1).putInt(12).putInt(1)
            return buffer.array()
        }

        fun cr3(gps: ByteArray): ByteArray = ftyp("crx ", "crx ", "isom") +
            container(
                "moov",
                box("uuid", CANON_UUID + box("CMT1", tiff(withLocation = false)) + box("CMT4", gps)),
                box("mvhd", ByteArray(100) { 2 }),
            ) +
            box("mdat", ByteArray(64) { 9 })

        fun jxl(vararg boxes: ByteArray): ByteArray =
            box("JXL ", byteArrayOf(0x0D, 0x0A, 0x87.toByte(), 0x0A)) + ftyp("jxl ", "jxl ") +
                boxes.fold(ByteArray(0), ByteArray::plus) + box("jxlc", ByteArray(32) { 3 })

        // A Fujifilm RAF: its header, the JPEG's offset and length at 84,
        // and the JPEG at 160.
        fun raf(jpeg: ByteArray): ByteArray {
            val header = ByteBuffer.allocate(160).put("FUJIFILMCCD-RAW 0201FF383501".latin1())
            header.position(84)
            header.putInt(160).putInt(jpeg.size)
            return header.array() + jpeg
        }

        // HEIF's Exif item and JPEG XL's Exif box: the TIFF header's offset,
        // then the Exif data, which Apple's start with Exif's identifier.
        fun exifItem(tiff: ByteArray, header: Boolean): ByteArray =
            ByteBuffer.allocate(4).putInt(if (header) 6 else 0).array() +
                (if (header) EXIF_HEADER else ByteArray(0)) + tiff

        // The image, Exif and XMP as items in mdat, or in idat for
        // construction method 1, each located by iloc, with IDs from firstId
        // on.
        fun heif(
            brand: String,
            method: Int,
            exif: ByteArray,
            xmp: ByteArray,
            iloc: Iloc = Iloc(),
            infeVersion: Int = 2,
            firstId: Int = 1,
            xmpType: String = "application/rdf+xml",
            xmpEncoding: String? = null,
        ): ByteArray {
            val items = listOf(ByteArray(16) { 5 }, exif, xmp)
            val ids = items.indices.map { firstId + it }
            val data = items.fold(ByteArray(0), ByteArray::plus)
            val infos = listOf(
                infe(ids[0], "hvc1", version = infeVersion),
                infe(ids[1], "Exif", version = infeVersion),
                infe(ids[2], "mime", xmpType, xmpEncoding, infeVersion),
            )
            val iinf = box(
                "iinf",
                ByteBuffer.allocate(6).putInt(0).putShort(3).array() + infos.fold(ByteArray(0), ByteArray::plus),
            )
            fun file(dataAt: Int): ByteArray {
                val bytes = ByteArrayOutputStream()
                DataOutputStream(bytes).run {
                    writeInt(iloc.version shl 24)
                    writeShort(
                        iloc.fieldBytes shl 12 or (iloc.fieldBytes shl 8) or (iloc.baseBytes shl 4) or iloc.indexBytes,
                    )
                    if (iloc.version < 2) writeShort(items.size) else writeInt(items.size)
                    var at = dataAt
                    for ((index, item) in items.withIndex()) {
                        if (iloc.version < 2) writeShort(ids[index]) else writeInt(ids[index])
                        if (iloc.version > 0) writeShort(method)
                        writeShort(0)
                        val base = if (iloc.baseBytes > 0) at / 2 else 0
                        sized(iloc.baseBytes, base)
                        val extents = when {
                            index == 1 && iloc.splitExif ->
                                listOf(at to 5, at + 5 + iloc.gap to item.size - 5 - iloc.gap)
                            index == items.lastIndex && iloc.lastToTheEnd -> listOf(at to 0)
                            else -> listOf(at to item.size)
                        }
                        writeShort(extents.size)
                        for ((offset, length) in extents) {
                            sized(iloc.indexBytes, 1)
                            sized(iloc.fieldBytes, offset - base)
                            sized(iloc.fieldBytes, length)
                        }
                        at += item.size
                    }
                }
                val idat = if (method == 1) arrayOf(box("idat", data)) else emptyArray()
                val meta = container("meta", ByteArray(4), handler(), iinf, box("iloc", bytes.toByteArray()), *idat)
                return ftyp(brand, "mif1", brand) + meta + if (method == 1) ByteArray(0) else box("mdat", data)
            }
            return if (method == 1) file(0) else file(file(0).size - data.size)
        }

        fun DataOutputStream.sized(bytes: Int, value: Int) {
            when (bytes) {
                4 -> writeInt(value)
                8 -> writeLong(value.toLong())
            }
        }

        fun infe(
            id: Int,
            type: String,
            contentType: String? = null,
            encoding: String? = null,
            version: Int = 2,
        ): ByteArray {
            val head = if (version == 2) {
                ByteBuffer.allocate(8).putInt(0x02000000).putShort(id.toShort()).putShort(0)
            } else {
                ByteBuffer.allocate(10).putInt(0x03000000).putInt(id).putShort(0)
            }
            val strings = listOfNotNull(contentType, encoding).joinToString("") { "$it\u0000" }
            return box("infe", head.array() + type.latin1() + "\u0000$strings".latin1())
        }

        fun segments(jpeg: ByteArray): List<Pair<Int, Int>> {
            val found = mutableListOf<Pair<Int, Int>>()
            var offset = 2
            while (offset + 4 <= jpeg.size) {
                val marker = jpeg[offset + 1].toInt() and 0xFF
                found += marker to offset
                if (marker == 0xDA) break
                offset += 2 + ((jpeg[offset + 2].toInt() and 0xFF) shl 8 or (jpeg[offset + 3].toInt() and 0xFF))
            }
            return found
        }

        fun scanOf(jpeg: ByteArray): ByteArray {
            val start = segments(jpeg).single { it.first == 0xDA }.second
            return jpeg.copyOfRange(start, jpeg.size)
        }

        fun app1Payload(jpeg: ByteArray, header: ByteArray): ByteArray {
            for ((marker, offset) in segments(jpeg)) {
                if (marker != 0xE1) continue
                val length = (jpeg[offset + 2].toInt() and 0xFF) shl 8 or (jpeg[offset + 3].toInt() and 0xFF)
                val payload = jpeg.copyOfRange(offset + 4, offset + 2 + length)
                if (payload.copyOfRange(0, header.size).contentEquals(header)) {
                    return payload.copyOfRange(header.size, payload.size)
                }
            }
            error("no such APP1 segment")
        }

        fun tiffOf(jpeg: ByteArray): ByteArray = app1Payload(jpeg, EXIF_HEADER)

        fun xmpOf(jpeg: ByteArray): ByteArray = app1Payload(jpeg, XMP_HEADER)

        fun ifd0Tags(tiff: ByteArray): List<Int> {
            val order = if (tiff[0] == 'M'.code.toByte()) ByteOrder.BIG_ENDIAN else ByteOrder.LITTLE_ENDIAN
            val buffer = ByteBuffer.wrap(tiff).order(order)
            val ifd0 = buffer.getInt(4)
            val count = buffer.getShort(ifd0).toInt()
            return (0 until count).map { buffer.getShort(ifd0 + 2 + 12 * it).toInt() and 0xFFFF }
        }

        fun chunks(png: ByteArray): List<Pair<String, List<Byte>>> {
            val buffer = ByteBuffer.wrap(png)
            var offset = 8
            val found = mutableListOf<Pair<String, List<Byte>>>()
            while (offset + 12 <= png.size) {
                val length = buffer.getInt(offset)
                val type = String(png, offset + 4, 4, Charsets.ISO_8859_1)
                found += type to png.copyOfRange(offset + 8, offset + 8 + length).toList()
                offset += 12 + length
            }
            return found
        }

        fun crcsHold(png: ByteArray): Boolean {
            val buffer = ByteBuffer.wrap(png)
            var offset = 8
            while (offset + 12 <= png.size) {
                val length = buffer.getInt(offset)
                val crc = CRC32().apply { update(png, offset + 4, 4 + length) }
                if (buffer.getInt(offset + 8 + length) != crc.value.toInt()) return false
                offset += 12 + length
            }
            return true
        }

        // A 1 x 1 VP8X canvas flagged as having XMP, Exif or both, and a
        // lossless bitstream of odd length, so that the next chunk follows a
        // pad byte.
        val VP8X_WITH_XMP = riffChunk("VP8X", byteArrayOf(0x04, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        val VP8X_WITH_EXIF = riffChunk("VP8X", byteArrayOf(0x08, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        val VP8X_WITH_EXIF_AND_XMP = riffChunk("VP8X", byteArrayOf(0x0C, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        val VP8L = byteArrayOf(0x2F, 0, 0, 0, 0)

        fun riffChunk(type: String, data: ByteArray): ByteArray {
            val padded = if (data.size % 2 == 1) data + 0 else data
            return ByteBuffer.allocate(8 + padded.size).order(ByteOrder.LITTLE_ENDIAN).put(type.latin1())
                .putInt(data.size).put(padded).array()
        }

        fun webp(vararg chunks: ByteArray): ByteArray {
            val body = "WEBP".latin1() + chunks.fold(ByteArray(0), ByteArray::plus)
            return ByteBuffer.allocate(8 + body.size).order(ByteOrder.LITTLE_ENDIAN).put("RIFF".latin1())
                .putInt(body.size).put(body).array()
        }

        fun riffChunks(webp: ByteArray): List<Pair<String, List<Byte>>> {
            val buffer = ByteBuffer.wrap(webp).order(ByteOrder.LITTLE_ENDIAN)
            var offset = 12
            val found = mutableListOf<Pair<String, List<Byte>>>()
            while (offset + 8 <= webp.size) {
                val size = buffer.getInt(offset + 4)
                found += String(webp, offset, 4, Charsets.ISO_8859_1) to
                    webp.copyOfRange(offset + 8, offset + 8 + size).toList()
                offset += 8 + size + (size and 1)
            }
            return found
        }

        fun box(type: String, payload: ByteArray): ByteArray =
            ByteBuffer.allocate(8 + payload.size).putInt(8 + payload.size).put(type.latin1()).put(payload).array()

        fun box64(type: String, payload: ByteArray): ByteArray =
            ByteBuffer.allocate(16 + payload.size).putInt(1).put(type.latin1()).putLong(16L + payload.size)
                .put(payload).array()

        fun boxToTheEnd(type: String, payload: ByteArray): ByteArray =
            ByteBuffer.allocate(8 + payload.size).putInt(0).put(type.latin1()).put(payload).array()

        fun container(type: String, vararg children: ByteArray): ByteArray =
            box(type, children.fold(ByteArray(0), ByteArray::plus))

        fun ftyp(major: String, vararg compatible: String): ByteArray =
            box("ftyp", (listOf(major, "\u0000\u0000\u0000\u0000") + compatible).joinToString("").latin1())

        fun keys(vararg names: String): ByteArray = box(
            "keys",
            ByteBuffer.allocate(8).putInt(0).putInt(names.size).array() + names.fold(ByteArray(0)) { all, name ->
                all + ByteBuffer.allocate(8).putInt(8 + name.length).put("mdta".latin1()).array() + name.latin1()
            },
        )

        // A data box: type 1, UTF-8, and a locale, which stays as it is,
        // then the value.
        fun item(name: String, value: ByteArray): ByteArray =
            container(name, box("data", ByteBuffer.allocate(8).putInt(1).putInt(0x00550009).array() + value))

        fun item(index: Int, value: ByteArray): ByteArray =
            item(String(ByteBuffer.allocate(4).putInt(index).array(), Charsets.ISO_8859_1), value)

        fun handler(): ByteArray = box("hdlr", ByteArray(8) + "mdta".latin1() + ByteArray(13))

        fun appleItems(entries: Array<out Pair<String, ByteArray>>): Array<ByteArray> = arrayOf(
            handler(),
            keys(*entries.map { it.first }.toTypedArray()),
            container("ilst", *entries.mapIndexed { index, entry -> item(index + 1, entry.second) }.toTypedArray()),
        )

        fun appleMeta(vararg entries: Pair<String, ByteArray>): ByteArray = container("meta", *appleItems(entries))

        fun isoMeta(vararg entries: Pair<String, ByteArray>): ByteArray =
            container("meta", ByteArray(4), *appleItems(entries))
    }

    // How iloc places the items: its version; the bytes of each offset and
    // length, of an extent's index and of a base offset; the Exif item in two
    // extents, a gap of as many bytes between them; the last item's length
    // as 0, which runs to the end.
    private class Iloc(
        val version: Int = 1,
        val fieldBytes: Int = 4,
        val indexBytes: Int = 0,
        val baseBytes: Int = 0,
        val splitExif: Boolean = false,
        val gap: Int = 0,
        val lastToTheEnd: Boolean = false,
    )

    // TIFF: IFD0 with Make, Orientation and, as asked, XMP (tag 700) and the
    // GPS IFD's pointer; then Make, the XMP and the GPS IFD with version,
    // latitude and longitude, whose values gpsValues names; then, as asked,
    // IFD1 with an uncompressed RGB thumbnail in two strips apart from each
    // other. The magic number may be ORF's or RW2's instead.
    private class TiffLayout(
        private val withLocation: Boolean,
        private val xmp: ByteArray?,
        private val thumbnailStrips: Boolean = false,
        private val order: ByteOrder = ByteOrder.BIG_ENDIAN,
        private val magic: Int = 42,
    ) {
        private val ifd0Entries = 2 + (if (xmp != null) 1 else 0) + (if (withLocation) 1 else 0)
        private val makeAt = 8 + 2 + 12 * ifd0Entries + 4
        private val xmpAt = makeAt + MAKE.size + 1
        private val gpsAt = (xmpAt + (xmp?.size ?: 0) + 1) and 1.inv()
        private val gpsDataAt = gpsAt + 2 + 12 * 5 + 4
        private val ifd1At = if (withLocation) gpsDataAt + 48 else gpsAt
        private val ifd1DataAt = ifd1At + 2 + 12 * 4 + 4

        val gpsValues: List<IntRange> = listOf(
            entryValue(0) until entryValue(0) + 4,
            entryValue(1) until entryValue(1) + 2,
            gpsDataAt until gpsDataAt + 24,
            entryValue(3) until entryValue(3) + 2,
            gpsDataAt + 24 until gpsDataAt + 48,
        )

        private fun entryValue(entry: Int) = gpsAt + 2 + 12 * entry + 8

        fun zeroed(keepVersion: Boolean = false): ByteArray = bytes().also { bytes ->
            for (range in gpsValues.drop(if (keepVersion) 1 else 0)) bytes.fill(0, range.first, range.last + 1)
        }

        fun bytes(): ByteArray {
            val buffer = ByteBuffer.allocate(if (thumbnailStrips) ifd1DataAt + 29 else ifd1At).order(order)
            buffer.put((if (order == ByteOrder.BIG_ENDIAN) "MM" else "II").latin1()).putShort(magic.toShort()).putInt(8)
            buffer.putShort(ifd0Entries.toShort())
            buffer.putShort(0x010F).putShort(2).putInt(MAKE.size).putInt(makeAt)
            buffer.putShort(0x0112).putShort(3).putInt(1).putShort(6).putShort(0)
            if (xmp != null) buffer.putShort(0x02BC).putShort(1).putInt(xmp.size).putInt(xmpAt)
            if (withLocation) buffer.putShort(GPS_INFO.toShort()).putShort(4).putInt(1).putInt(gpsAt)
            buffer.putInt(if (thumbnailStrips) ifd1At else 0)
            buffer.put(MAKE).put(0)
            if (xmp != null) buffer.put(xmp)
            if (withLocation) {
                buffer.position(gpsAt)
                buffer.putShort(5)
                buffer.putShort(0).putShort(1).putInt(4).put(byteArrayOf(2, 2, 0, 0))
                buffer.putShort(1).putShort(2).putInt(2).put("N\u0000\u0000\u0000".latin1())
                buffer.putShort(2).putShort(5).putInt(3).putInt(gpsDataAt)
                buffer.putShort(3).putShort(2).putInt(2).put("E\u0000\u0000\u0000".latin1())
                buffer.putShort(4).putShort(5).putInt(3).putInt(gpsDataAt + 24)
                buffer.putInt(0)
                for ((degrees, minutes) in listOf(52 to 31, 13 to 24)) {
                    buffer.putInt(degrees).putInt(1).putInt(minutes).putInt(1).putInt(12).putInt(1)
                }
            }
            if (thumbnailStrips) {
                val strips = ifd1DataAt + 22
                buffer.position(ifd1At)
                buffer.putShort(4)
                buffer.putShort(0x0102).putShort(3).putInt(3).putInt(ifd1DataAt)
                buffer.putShort(0x0103).putShort(3).putInt(1).putShort(1).putShort(0)
                buffer.putShort(0x0111).putShort(4).putInt(2).putInt(ifd1DataAt + 6)
                buffer.putShort(0x0117).putShort(4).putInt(2).putInt(ifd1DataAt + 14)
                buffer.putInt(0)
                buffer.putShort(8).putShort(8).putShort(8).putInt(strips).putInt(strips + 4).putInt(3).putInt(3)
                buffer.put(byteArrayOf(1, 2, 3, 0, 4, 5, 6))
            }
            return buffer.array()
        }

        private companion object {
            val MAKE = "Rurana\u0000".toByteArray(Charsets.ISO_8859_1)
        }
    }

    // TIFF: IFD0 with Make and the GPS IFD's pointer, as a LONG or a SHORT,
    // or with Make alone and the pointer in IFD1; the GPS IFD with the
    // latitude's reference in its entry, the latitude after the IFD or at
    // latitudeAt, as RATIONALs or as UNDEFINED bytes, and, as asked, tag
    // 0x100 with its value in its entry.
    private class GpsTiff(
        private val order: ByteOrder = ByteOrder.BIG_ENDIAN,
        private val shortPointer: Boolean = false,
        private val pointerInIfd1: Boolean = false,
        private val otherTag: Boolean = false,
        private val latitudeAt: Int? = null,
        private val undefinedLatitude: ByteArray? = null,
    ) {
        private val ifd1At = 8 + 2 + 12 * (if (pointerInIfd1) 1 else 2) + 4
        private val gpsAt = if (pointerInIfd1) ifd1At + 2 + 12 + 4 else ifd1At
        private val latitudeDataAt = gpsAt + 2 + 12 * (if (otherTag) 3 else 2) + 4
        private val latitude = undefinedLatitude
            ?: ByteBuffer.allocate(24).putInt(52).putInt(1).putInt(31).putInt(1).putInt(12).putInt(1).array()
        private val makeAt = latitudeDataAt + latitude.size
        val size = makeAt + 8

        fun bytes(zeroed: Boolean = false): ByteArray {
            val buffer = ByteBuffer.allocate(size).order(order)
            buffer.put((if (order == ByteOrder.BIG_ENDIAN) "MM" else "II").latin1()).putShort(42).putInt(8)
            buffer.putShort((if (pointerInIfd1) 1 else 2).toShort())
            buffer.putShort(0x010F).putShort(2).putInt(7).putInt(makeAt)
            if (!pointerInIfd1) gpsPointer(buffer)
            buffer.putInt(if (pointerInIfd1) ifd1At else 0)
            if (pointerInIfd1) {
                buffer.putShort(1)
                gpsPointer(buffer)
                buffer.putInt(0)
            }
            buffer.putShort((if (otherTag) 3 else 2).toShort())
            buffer.putShort(1).putShort(2).putInt(2).put((if (zeroed) "\u0000" else "N").latin1()).put(ByteArray(3))
            buffer.putShort(2).putShort(if (undefinedLatitude == null) 5 else 7)
                .putInt(if (undefinedLatitude == null) 3 else latitude.size).putInt(latitudeAt ?: latitudeDataAt)
            if (otherTag) buffer.putShort(0x0100).putShort(4).putInt(1).putInt(0x01020304)
            buffer.putInt(0)
            buffer.put(if (zeroed || latitudeAt != null) ByteArray(latitude.size) else latitude)
            buffer.put("Rurana\u0000\u0000".latin1())
            return buffer.array()
        }

        private fun gpsPointer(buffer: ByteBuffer) {
            buffer.putShort(GPS_INFO.toShort())
            if (shortPointer) {
                buffer.putShort(3).putInt(1).putShort(gpsAt.toShort()).putShort(0)
            } else {
                buffer.putShort(4).putInt(1).putInt(gpsAt)
            }
        }
    }
}
