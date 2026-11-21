package io.vikunja.app

import io.sentry.Breadcrumb
import io.sentry.Hint
import io.sentry.JsonSerializer
import io.sentry.SentryEvent
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.android.core.cache.AndroidEnvelopeCache
import io.sentry.protocol.App
import io.sentry.protocol.DebugImage
import io.sentry.protocol.DebugMeta
import io.sentry.protocol.Device
import io.sentry.protocol.Mechanism
import io.sentry.protocol.Message
import io.sentry.protocol.OperatingSystem
import io.sentry.protocol.Request
import io.sentry.protocol.SentryException
import io.sentry.protocol.SentryRuntime
import io.sentry.protocol.SentryStackFrame
import io.sentry.protocol.SentryStackTrace
import io.sentry.protocol.SentryThread
import io.sentry.protocol.User
import java.io.File
import java.io.StringWriter
import java.util.Date
import java.util.TimeZone
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class NativeCrashReportsTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val path = "/storage/emulated/0/Download/Bewerbung Max Mustermann.pdf"
    private val host = "tasks.example.org"
    private val dsn = "https://public@example.invalid/1"
    private val installed = "/data/app/~~R4nd0mT0k3n_-xYz12345==/io.vikunja.app-An0th3r-T0k3n_xyz9876==/"
    private val apk = "${installed}base.apk"
    private val libapp = "${installed}lib/arm64/libapp.so"

    private fun cache() = File(folder.root, "sentry")

    private fun options(cache: File = cache()) = SentryAndroidOptions().apply {
        cacheDirPath = cache.absolutePath
    }

    private fun configured() = options().also { NativeCrashReports.configure(it, "io.vikunja.app@1.0.0+7", "7") }

    private fun prepared(cache: File = cache(), now: Long = 1_000L) =
        options(cache).also { NativeCrashReports.prepare(it, dsn, "io.vikunja.app@1.0.0+7", "7", now) }

    private fun frame() = SentryStackFrame().apply {
        module = "io.vikunja.app.ShareInbox"
        function = "copy"
        lineno = 42
        vars = mapOf("name" to path)
        contextLine = "open(\"$path\")"
    }

    private fun nativeFrame() = SentryStackFrame().apply {
        `package` = "$apk!libflutter.so (offset 0x1000)"
        absPath = libapp
        filename = libapp
        function = "Dart_Invoke"
        instructionAddr = "0x7a1b2c3d4e"
        platform = "native"
    }

    private fun event() = SentryEvent().apply {
        user = User().apply { id = "installation-id" }
        request = Request().apply { url = "https://$host/api" }
        serverName = "a-phone"
        transaction = "/home/tasks/7"
        message = Message().apply { formatted = "open failed: $path" }
        exceptions = listOf(
            SentryException().apply {
                type = "FileNotFoundException"
                module = "java.io"
                value = "$path: open failed: ENOENT (No such file or directory)"
                stacktrace = SentryStackTrace(listOf(frame(), nativeFrame()))
                mechanism = Mechanism().apply {
                    type = "UncaughtExceptionHandler"
                    isHandled = false
                    synthetic = false
                    description = "for $host"
                    helpLink = "https://$host/help"
                    data = mapOf("path" to path)
                    meta = mapOf("signal" to mapOf("name" to path))
                }
            },
        )
        threads = listOf(
            SentryThread().apply {
                id = 1
                name = "OkHttp https://$host/..."
                stacktrace = SentryStackTrace(listOf(frame(), nativeFrame()))
            },
            SentryThread().apply { name = "main" },
            SentryThread().apply { name = "pool-3-thread-1" },
            SentryThread().apply { name = "DefaultDispatcher-worker-2 (io)" },
            SentryThread().apply { name = "Binder:1234_2" },
            SentryThread().apply { name = "worker for someone@example.org" },
            SentryThread().apply { name = "1.ui" },
            SentryThread().apply { name = "x".repeat(41) },
        )
        breadcrumbs = listOf(
            Breadcrumb().apply {
                category = NativeCrashReports.LOG_CATEGORY
                message = "Retrying https://<server>/api"
            },
            Breadcrumb().apply {
                category = "network.event"
                type = "system"
                setData("network_type", "wifi")
                setData("vpn_active", true)
            },
            Breadcrumb().apply { category = "ui.click" },
        )
        debugMeta = DebugMeta().apply {
            images = listOf(
                DebugImage().apply {
                    type = "elf"
                    codeFile = libapp
                    debugFile = libapp
                    codeId = "a1b2c3d4e5f60718293a4b5c6d7e8f90"
                    debugId = "d4c3b2a1-f6e5-1807-293a-4b5c6d7e8f90"
                    imageAddr = "0x7a00000000"
                },
                DebugImage().apply {
                    type = "elf"
                    codeFile = "/apex/com.android.runtime/lib64/bionic/libc.so"
                    imageAddr = "0x7b00000000"
                },
            )
        }
        setTag("event.origin", "android")
        setTag("server", host)
        setExtra("file", path)
        contexts.setApp(
            App().apply {
                appIdentifier = "io.vikunja.app"
                appName = "Vikunja"
                appVersion = "1.0.0"
                appBuild = "7"
                buildType = "release"
                appStartTime = Date(0)
                deviceAppHash = "hash"
                inForeground = true
                viewNames = listOf("MainActivity")
                permissions = mapOf("ACCESS_NETWORK_STATE" to "granted")
            },
        )
        contexts.setOperatingSystem(
            OperatingSystem().apply {
                name = "Android"
                version = "16"
                build = "BP2A.250605"
                kernelVersion = "6.1.0-android"
                isRooted = false
                rawDescription = "Linux localhost 6.1.0"
            },
        )
        contexts.setDevice(
            Device().apply {
                family = "Pixel"
                model = "Pixel 9"
                modelId = "AP4A"
                manufacturer = "Google"
                brand = "google"
                archs = arrayOf("arm64-v8a")
                isSimulator = false
                id = "installation-id"
                name = "Someone's phone"
                batteryLevel = 81f
                isCharging = true
                freeMemory = 123L
                freeStorage = 456L
                bootTime = Date(0)
                timezone = TimeZone.getTimeZone("Europe/Berlin")
                locale = "de_DE"
                connectionType = "wifi"
                screenDpi = 420
            },
        )
        contexts.setRuntime(
            SentryRuntime().apply {
                name = "Android"
                version = "16"
                rawDescription = "/apex/com.android.art/lib64/libart.so"
            },
        )
        contexts.put("dart", mapOf("name" to "Dart", "version" to "3.10.0", "raw_description" to "3.10.0 (stable)"))
        contexts.put("culture", mapOf("locale" to "de_DE", "timezone" to "Europe/Berlin"))
        contexts.put("accessibility", mapOf("bold_text" to true))
        contexts.put("battery", mapOf("level" to 81))
        contexts.put("flutter_context", mapOf("default_route_name" to "/home/tasks/7"))
        contexts.put("permissions", mapOf("ACCESS_NETWORK_STATE" to "granted"))
    }

    @Test
    fun `starts with every option set by the app`() {
        val options = configured()

        assertEquals("io.vikunja.app@1.0.0+7", options.release)
        assertEquals("7", options.dist)
        assertNull(options.dsn)
        assertFalse(options.isDebug)
        assertFalse(options.isAttachAnrThreadDump)
        assertFalse(options.isAttachRawTombstone)
        assertFalse(options.isEnableNdkAppHangTracking)
        assertFalse(options.isSendDefaultPii)
        assertFalse(options.isEnableAutoSessionTracking)
        assertFalse(options.isEnableActivityLifecycleBreadcrumbs)
        assertFalse(options.isEnableAppLifecycleBreadcrumbs)
        assertFalse(options.isEnableSystemEventBreadcrumbs)
        assertFalse(options.isEnableAppComponentBreadcrumbs)
        assertFalse(options.isEnableUserInteractionBreadcrumbs)
        assertFalse(options.isEnableNetworkEventBreadcrumbs)
        assertFalse(options.isAttachThreads)
        assertFalse(options.isAttachStacktrace)
        assertFalse(options.isAttachScreenshot)
        assertFalse(options.isAttachViewHierarchy)
        assertFalse(options.isSendClientReports)
        assertFalse(options.isSendModules)
        assertFalse(options.isCollectAdditionalContext)
        assertFalse(options.logs.isEnabled)
        assertFalse(options.metrics.isEnabled)
        assertNull(options.tracesSampleRate)
        assertNull(options.tracesSampler)
        assertNull(options.profilesSampleRate)
        assertNull(options.profileSessionSampleRate)
        assertFalse(options.isTracingEnabled)
        assertFalse(options.isEnableAutoActivityLifecycleTracing)
        assertFalse(options.isEnableFramesTracking)
        assertFalse(options.isEnableUserInteractionTracing)
        assertEquals(0.0, options.sessionReplay.sessionSampleRate!!, 0.0)
        assertEquals(0.0, options.sessionReplay.onErrorSampleRate!!, 0.0)
        assertFalse(options.sessionReplay.isSessionReplayEnabled)
        assertFalse(options.sessionReplay.isSessionReplayForErrorsEnabled)
        assertFalse(options.isTombstoneEnabled)
        assertFalse(options.isMemoryLimiterEnabled)
        assertFalse(options.isReportHistoricalAnrs)
        assertTrue(options.isAnrEnabled)
        assertTrue(options.isEnableUncaughtExceptionHandler)
        assertTrue(options.isEnableNdk)
        assertTrue(options.isEnableScopeSync)
        assertEquals(50, options.maxBreadcrumbs)
        assertNotNull(options.beforeSendTransaction)
    }

    // SentryAndroidOptions is final, so the order can't be recorded at setDsn;
    // the markers' test shows they come after the DSN.
    @Test
    fun `a prepared start has the DSN, the app's options and the SDK on`() {
        val options = prepared()

        assertEquals(dsn, options.dsn)
        assertTrue(options.isEnabled)
        assertFalse(options.isSendDefaultPii)
        assertFalse(options.isAttachAnrThreadDump)
        assertNotNull(options.beforeSend)
        assertEquals("io.vikunja.app@1.0.0+7", options.release)
    }

    @Test
    fun `the markers' time is never before the newest exit, so a clock set back cannot make an earlier exit new`() {
        assertEquals(5_000L, NativeCrashReports.markerTime(1_000L) { 5_000L })
        assertEquals(1_000L, NativeCrashReports.markerTime(1_000L) { 500L })
        assertEquals(1_000L, NativeCrashReports.markerTime(1_000L) { null })
    }

    @Test
    fun `the markers' time is now when the exit history cannot be read`() {
        assertEquals(1_000L, NativeCrashReports.markerTime(1_000L) { throw SecurityException("no history") })
        assertEquals(1_000L, NativeCrashReports.markerTime(1_000L) { throw NoSuchMethodError("no history") })
    }

    // Where the SDK reads them: the DSN's own folder, which a marker written
    // before the DSN misses.
    @Test
    fun `counts the exits from before the allow as reported where the SDK reads them, with the DSN set`() {
        val cache = cache()
        assertFalse(cache.exists())

        val options = prepared(cache, now = 1_000L)

        assertEquals(1_000L, AndroidEnvelopeCache.lastReportedAnr(options))
        assertEquals(1_000L, AndroidEnvelopeCache.lastReportedTombstone(options))
        assertEquals(1_000L, AndroidEnvelopeCache.lastReportedMemoryLimiter(options))
        val dsnFolder = File(options.cacheDirPath!!)
        assertEquals(cache.absoluteFile, dsnFolder.parentFile)
        assertTrue(dsnFolder.name.matches(Regex("[0-9a-f]{20,40}")))
        for (marker in listOf(
            AndroidEnvelopeCache.LAST_ANR_REPORT,
            AndroidEnvelopeCache.LAST_TOMBSTONE_REPORT,
            AndroidEnvelopeCache.LAST_MEMORY_LIMITER_REPORT,
        )) {
            assertTrue(marker, File(dsnFolder, marker).isFile)
            assertFalse(marker, File(cache, marker).exists())
        }
    }

    @Test
    fun `keeps a marker already there`() {
        val options = prepared(now = 1_000L)
        AndroidEnvelopeCache.markAnrReported(options, 1_500L)

        val again = prepared(now = 2_000L)

        assertEquals(1_500L, AndroidEnvelopeCache.lastReportedAnr(again))
        assertEquals(1_000L, AndroidEnvelopeCache.lastReportedTombstone(again))
        assertEquals(1_000L, AndroidEnvelopeCache.lastReportedMemoryLimiter(again))
    }

    @Test
    fun `turning reports off deletes the markers with the cache folder, so the next allow writes them again`() {
        prepared(now = 1_000L)

        assertTrue(cache().deleteRecursively())
        val again = prepared(now = 2_000L)

        assertEquals(2_000L, AndroidEnvelopeCache.lastReportedAnr(again))
    }

    @Test
    fun `a start whose markers cannot be written fails and leaves the SDK off without a DSN`() {
        val blocked = cache().apply { writeText("not a folder") }
        val options = options(blocked)

        val failure = runCatching {
            NativeCrashReports.prepare(options, dsn, "io.vikunja.app@1.0.0+7", "7", 1_000L)
        }.exceptionOrNull()

        assertTrue(failure is IllegalStateException)
        assertFalse(options.isEnabled)
        assertEquals("", options.dsn)
    }

    @Test
    fun `keeps only the app's breadcrumbs`() {
        val options = configured()
        val ours = Breadcrumb().apply { category = NativeCrashReports.LOG_CATEGORY }
        val network = Breadcrumb().apply { category = "network.event" }

        assertSame(ours, options.beforeBreadcrumb!!.execute(ours, Hint()))
        assertNull(options.beforeBreadcrumb!!.execute(network, Hint()))
    }

    @Test
    fun `leaves no user, request, server name, transaction, message, tags or extra`() {
        val sent = configured().beforeSend!!.execute(event(), Hint())!!

        assertNull(sent.user)
        assertNull(sent.request)
        assertNull(sent.serverName)
        assertNull(sent.transaction)
        assertNull(sent.message)
        assertEquals(mapOf("app.part" to "app"), sent.tags)
        assertTrue(sent.extras.isNullOrEmpty())
    }

    @Test
    fun `sends an exception by its type, module, frames and mechanism only`() {
        val exception = NativeCrashReports.scrub(event()).exceptions!!.single()

        assertNull(exception.value)
        assertEquals("FileNotFoundException", exception.type)
        assertEquals("java.io", exception.module)
        val mechanism = exception.mechanism!!
        assertEquals("UncaughtExceptionHandler", mechanism.type)
        assertEquals(false, mechanism.isHandled)
        assertEquals(false, mechanism.synthetic)
        assertNull(mechanism.description)
        assertNull(mechanism.helpLink)
        assertNull(mechanism.data)
        assertNull(mechanism.meta)
        val frame = exception.stacktrace!!.frames!!.first()
        assertEquals("io.vikunja.app.ShareInbox", frame.module)
        assertEquals(42, frame.lineno)
        assertNull(frame.vars)
        assertNull(frame.contextLine)
    }

    @Test
    fun `keeps a thread's name only when it cannot name a server, a file or a person`() {
        val threads = NativeCrashReports.scrub(event()).threads!!

        assertEquals(
            listOf(null, "main", "pool-3-thread-1", "DefaultDispatcher-worker-2 (io)", null, null, null, null),
            threads.map { it.name },
        )
        assertNull(threads.first().stacktrace!!.frames!!.first().vars)
    }

    @Test
    fun `native frames and debug images name the app's folder without the random segments of its install`() {
        val event = NativeCrashReports.scrub(event())
        val frames = event.exceptions!!.single().stacktrace!!.frames!! + event.threads!!.first().stacktrace!!.frames!!
        val native = frames.filter { it.platform == "native" }

        assertEquals(2, native.size)
        for (frame in native) {
            assertEquals("/data/app/io.vikunja.app/base.apk!libflutter.so (offset 0x1000)", frame.`package`)
            assertEquals("/data/app/io.vikunja.app/lib/arm64/libapp.so", frame.absPath)
            assertEquals("/data/app/io.vikunja.app/lib/arm64/libapp.so", frame.filename)
            assertEquals("0x7a1b2c3d4e", frame.instructionAddr)
        }
        val (app, libc) = event.debugMeta!!.images!!
        assertEquals("/data/app/io.vikunja.app/lib/arm64/libapp.so", app.codeFile)
        assertEquals("/data/app/io.vikunja.app/lib/arm64/libapp.so", app.debugFile)
        assertEquals("a1b2c3d4e5f60718293a4b5c6d7e8f90", app.codeId)
        assertEquals("d4c3b2a1-f6e5-1807-293a-4b5c6d7e8f90", app.debugId)
        assertEquals("0x7a00000000", app.imageAddr)
        assertEquals("/apex/com.android.runtime/lib64/bionic/libc.so", libc.codeFile)
    }

    @Test
    fun `the older install folders and adopted storage lose their random segments too`() {
        for ((given, expected) in listOf(
            "/data/app/io.vikunja.app-1/lib/arm64/libapp.so" to "/data/app/io.vikunja.app/lib/arm64/libapp.so",
            "/data/app/io.vikunja.app-Xy_z-12==/base.apk" to "/data/app/io.vikunja.app/base.apk",
            "/mnt/expand/0123abcd-4567-89ef-0123-456789abcdef/app/~~Ab==/io.vikunja.app-Cd==/base.apk" to
                "/data/app/io.vikunja.app/base.apk",
            "/data/app/~~Ab==/com.google.android.trichromelibrary_123-Cd==/base.apk" to
                "/data/app/com.google.android.trichromelibrary_123/base.apk",
            "/data/app/io.vikunja.app/base.apk" to "/data/app/io.vikunja.app/base.apk",
            "/system/lib64/libc++.so" to "/system/lib64/libc++.so",
        )) {
            assertEquals(given, expected, NativeCrashReports.withoutInstallFolder(given))
        }
        assertNull(NativeCrashReports.withoutInstallFolder(null))
    }

    @Test
    fun `drops the network breadcrumbs and every other but the app's`() {
        val breadcrumbs = NativeCrashReports.scrub(event()).breadcrumbs!!

        assertEquals(listOf(NativeCrashReports.LOG_CATEGORY), breadcrumbs.map { it.category })
    }

    @Test
    fun `keeps only the listed contexts and their listed fields`() {
        val contexts = NativeCrashReports.scrub(event()).contexts

        assertEquals(setOf("app", "os", "device", "runtime", "dart"), contexts.keys().toList().toSet())
        val app = contexts.app!!
        assertEquals("io.vikunja.app", app.appIdentifier)
        assertEquals("Vikunja", app.appName)
        assertEquals("1.0.0", app.appVersion)
        assertEquals("7", app.appBuild)
        assertEquals("release", app.buildType)
        assertNull(app.appStartTime)
        assertNull(app.deviceAppHash)
        assertNull(app.inForeground)
        assertNull(app.viewNames)
        assertNull(app.permissions)
        val os = contexts.operatingSystem!!
        assertEquals(listOf("Android", "16", "BP2A.250605"), listOf(os.name, os.version, os.build))
        assertNull(os.kernelVersion)
        assertNull(os.isRooted)
        assertNull(os.rawDescription)
        val device = contexts.device!!
        assertEquals(
            listOf("Pixel", "Pixel 9", "AP4A", "Google", "google"),
            listOf(device.family, device.model, device.modelId, device.manufacturer, device.brand),
        )
        assertArrayEquals(arrayOf("arm64-v8a"), device.archs)
        assertEquals(false, device.isSimulator)
        for (gone in listOf(
            device.id, device.name, device.batteryLevel, device.isCharging, device.freeMemory, device.freeStorage,
            device.bootTime, device.timezone, device.locale, device.connectionType, device.screenDpi,
        )) {
            assertNull(gone)
        }
        val runtime = contexts.runtime!!
        assertEquals("Android", runtime.name)
        assertNull(runtime.rawDescription)
        assertEquals(
            mapOf("name" to "Dart", "version" to "3.10.0", "raw_description" to "3.10.0 (stable)"),
            contexts["dart"],
        )
    }

    @Test
    fun `the report as it is sent names neither the file, the server, the device's id nor its state`() {
        val sent = configured().beforeSend!!.execute(event(), Hint())!!
        val json = StringWriter().also { JsonSerializer(SentryAndroidOptions()).serialize(sent, it) }.toString()

        assertTrue(json, "Pixel 9" in json)
        assertTrue(json, "/data/app/io.vikunja.app/lib/arm64/libapp.so" in json)
        val secrets = listOf(
            "Mustermann", host, "installation-id", "Someone", "wifi", "Berlin", "granted", "MainActivity",
            "R4nd0mT0k3n", "An0th3r",
        )
        for (secret in secrets) {
            assertFalse(secret, secret in json)
        }
    }
}
