package io.vikunja.app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.sentry.Breadcrumb
import io.sentry.Sentry
import io.sentry.SentryEvent
import io.sentry.SentryOptions
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.android.core.cache.AndroidEnvelopeCache
import io.sentry.protocol.App
import io.sentry.protocol.Contexts
import io.sentry.protocol.Device
import io.sentry.protocol.OperatingSystem
import io.sentry.protocol.SentryException
import io.sentry.protocol.SentryRuntime
import io.sentry.protocol.SentryStackTrace
import java.io.File

// The app starts the Android SDK itself, once the user allowed crash reports
// (D113), so that every option is the app's and the scrubber is in place before
// the SDK processes anything. What the SDK builds itself (Java crashes, ANRs,
// NDK crashes) never passes the app's Dart scrubber; Dart's reports reach the
// SDK as envelopes, which this beforeSend never sees.
internal object NativeCrashReports {
    const val LOG_CATEGORY = "app.log"
    const val MAX_BREADCRUMBS = 50

    private val safeThreadName = Regex("[A-Za-z0-9 _#()-]{1,40}")
    private val versionKeys = listOf("dart", "flutter")

    // Android picks both random segments at each install and update, so they
    // would link one install's reports; symbolication goes by the debug and
    // code ids. The older form has the package and a number or one segment.
    private val installedAppFolder =
        Regex("(?:/data|/mnt/expand/[^/]+)/app/(?:~~[A-Za-z0-9_=-]+/)?([A-Za-z][A-Za-z0-9_.]*)-[A-Za-z0-9_=-]+/")

    fun start(context: Context, dsn: String, release: String, dist: String) {
        val now = markerTime(System.currentTimeMillis()) { newestExit(context) }
        var failure: Throwable? = null
        SentryAndroid.init(context) { options ->
            // SentryAndroid.init only logs what this throws.
            try {
                prepare(options, dsn, release, dist, now)
            } catch (error: Throwable) {
                failure = error
            }
        }
        failure?.let { throw IllegalStateException("Sentry could not be configured", it) }
        check(Sentry.isEnabled()) { "Sentry did not start" }
    }

    fun stop() = Sentry.close()

    // An exit's timestamp is wall-clock time too: once the clock was set back,
    // an exit from before the allow would be later than a marker of now.
    fun markerTime(now: Long, newestExit: () -> Long?): Long {
        val newest = try {
            newestExit()
        } catch (_: Exception) {
            null
        } catch (_: LinkageError) {
            null
        }
        return maxOf(now, newest ?: now)
    }

    private fun newestExit(context: Context): Long? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val activities = context.getSystemService(ActivityManager::class.java) ?: return null
        return activities.getHistoricalProcessExitReasons(context.packageName, 0, 1).firstOrNull()?.timestamp
    }

    // SentryAndroid.init's callback. The SDK starts with what was set when it
    // throws, so a failure leaves the SDK disabled without a DSN. A setter
    // another SDK version lacks throws an Error, not an Exception. The markers
    // come after the DSN, which names the folder the SDK reads them from.
    fun prepare(options: SentryAndroidOptions, dsn: String, release: String, dist: String, now: Long) {
        try {
            configure(options, release, dist)
            options.dsn = dsn
            markEarlierExitsReported(options, now)
        } catch (error: Throwable) {
            options.isEnabled = false
            options.dsn = ""
            throw error
        }
    }

    fun configure(options: SentryAndroidOptions, release: String, dist: String) {
        options.release = release
        options.dist = dist
        options.isSendDefaultPii = false
        options.isEnableAutoSessionTracking = false
        options.isEnableActivityLifecycleBreadcrumbs = false
        options.isEnableAppLifecycleBreadcrumbs = false
        options.isEnableSystemEventBreadcrumbs = false
        options.isEnableSystemEventBreadcrumbsExtras = false
        options.isEnableAppComponentBreadcrumbs = false
        options.isEnableUserInteractionBreadcrumbs = false
        options.isEnableNetworkEventBreadcrumbs = false
        options.isAttachThreads = false
        options.isAttachStacktrace = false
        options.isAttachScreenshot = false
        options.isAttachViewHierarchy = false
        options.isSendClientReports = false
        options.isSendModules = false
        options.isCollectAdditionalContext = false
        options.isEnableRootCheck = false
        options.isEnableSpotlight = false
        options.feedbackOptions.isUseShakeGesture = false
        options.logs.isEnabled = false
        options.metrics.isEnabled = false
        options.tracesSampleRate = null
        options.tracesSampler = null
        options.profilesSampleRate = null
        options.profileSessionSampleRate = null
        options.anrProfilingSampleRate = null
        options.isStartProfilerOnAppStart = false
        options.isEnableAppStartProfiling = false
        options.isEnableAutoActivityLifecycleTracing = false
        options.isEnableFramesTracking = false
        options.isEnableUserInteractionTracing = false
        options.isEnableTimeToFullDisplayTracing = false
        options.isEnablePerformanceV2 = false
        options.isEnableStandaloneAppStartTracing = false
        options.sessionReplay.sessionSampleRate = 0.0
        options.sessionReplay.onErrorSampleRate = 0.0
        options.isTombstoneEnabled = false
        options.isMemoryLimiterEnabled = false
        options.isReportHistoricalAnrs = false
        options.isReportHistoricalTombstones = false
        options.isReportHistoricalMemoryLimiterExits = false
        // Attachments never pass beforeSend.
        options.isAttachAnrThreadDump = false
        options.isAttachRawTombstone = false
        options.isEnableNdkAppHangTracking = false
        options.isDebug = false
        options.isAnrEnabled = true
        options.isEnableUncaughtExceptionHandler = true
        options.isEnableNdk = true
        // The app's breadcrumbs, which Dart adds to this scope, also reach
        // the NDK's reports.
        options.isEnableScopeSync = true
        options.maxBreadcrumbs = MAX_BREADCRUMBS
        options.beforeBreadcrumb = SentryOptions.BeforeBreadcrumbCallback { breadcrumb, _ -> appsOwn(breadcrumb) }
        options.beforeSend = SentryOptions.BeforeSendCallback { event, _ -> scrub(event) }
        options.beforeSendTransaction = SentryOptions.BeforeSendTransactionCallback { _, _ -> null }
    }

    // The integrations report the latest ANR, tombstone or memory-limit exit
    // of the process history (91 days, the previous app's included) unless a
    // marker in the cache folder says it was reported: from before the user
    // allowed reports, none may be. With a DSN that folder is the DSN's own
    // inside <cache>/sentry. Turning reports off deletes <cache>/sentry, so the
    // next allow writes the markers again; an exit while allowed is later than
    // the marker and still reported at the next start.
    private fun markEarlierExitsReported(options: SentryAndroidOptions, now: Long) {
        val cache = File(checkNotNull(options.cacheDirPath) { "Sentry has no cache folder" })
        check(cache.isDirectory || cache.mkdirs()) { "Sentry's cache folder could not be made" }
        if (AndroidEnvelopeCache.lastReportedAnr(options) == null) AndroidEnvelopeCache.markAnrReported(options, now)
        if (AndroidEnvelopeCache.lastReportedTombstone(options) == null) {
            AndroidEnvelopeCache.markTombstoneReported(options, now)
        }
        if (AndroidEnvelopeCache.lastReportedMemoryLimiter(options) == null) {
            AndroidEnvelopeCache.markMemoryLimiterReported(options, now)
        }
        check(
            AndroidEnvelopeCache.lastReportedAnr(options) != null &&
                AndroidEnvelopeCache.lastReportedTombstone(options) != null &&
                AndroidEnvelopeCache.lastReportedMemoryLimiter(options) != null,
        ) { "Sentry's markers could not be written" }
    }

    fun appsOwn(breadcrumb: Breadcrumb): Breadcrumb? = breadcrumb.takeIf { it.category == LOG_CATEGORY }

    fun scrub(event: SentryEvent): SentryEvent {
        event.user = null
        event.request = null
        event.serverName = null
        event.transaction = null
        event.message = null
        event.unknown = null
        event.exceptions?.forEach(::scrubException)
        event.threads?.forEach { thread ->
            thread.name = thread.name?.takeIf(safeThreadName::matches)
            scrubFrames(thread.stacktrace)
        }
        event.debugMeta?.images?.forEach { image ->
            image.codeFile = withoutInstallFolder(image.codeFile)
            image.debugFile = withoutInstallFolder(image.debugFile)
        }
        event.breadcrumbs = event.breadcrumbs?.filter { it.category == LOG_CATEGORY }
        event.tags = mapOf("app.part" to "app")
        event.extras = null
        scrubContexts(event.contexts)
        return event
    }

    // A Java exception's message may quote a file, a server or content: only
    // where it happened goes.
    private fun scrubException(exception: SentryException) {
        exception.value = null
        exception.unknown = null
        exception.mechanism?.let { mechanism ->
            mechanism.description = null
            mechanism.helpLink = null
            mechanism.data = null
            mechanism.meta = null
            mechanism.unknown = null
        }
        scrubFrames(exception.stacktrace)
    }

    private fun scrubFrames(stacktrace: SentryStackTrace?) {
        stacktrace?.frames?.forEach { frame ->
            frame.vars = null
            frame.contextLine = null
            frame.preContext = null
            frame.postContext = null
            frame.`package` = withoutInstallFolder(frame.`package`)
            frame.absPath = withoutInstallFolder(frame.absPath)
            frame.filename = withoutInstallFolder(frame.filename)
        }
    }

    fun withoutInstallFolder(path: String?): String? =
        path?.replace(installedAppFolder) { "/data/app/${it.groupValues[1]}/" }

    // The same allowlist as crash_report_scrubber.dart's _scrubContexts.
    private fun scrubContexts(contexts: Contexts) {
        val app = contexts.app?.let { from ->
            App().apply {
                appIdentifier = from.appIdentifier
                appName = from.appName
                appVersion = from.appVersion
                appBuild = from.appBuild
                buildType = from.buildType
            }
        }
        val os = contexts.operatingSystem?.let { from ->
            OperatingSystem().apply {
                name = from.name
                version = from.version
                build = from.build
            }
        }
        val device = contexts.device?.let { from ->
            Device().apply {
                family = from.family
                model = from.model
                modelId = from.modelId
                manufacturer = from.manufacturer
                brand = from.brand
                archs = from.archs?.copyOf()
                isSimulator = from.isSimulator
            }
        }
        val runtime = contexts.runtime?.let { from ->
            SentryRuntime().apply {
                name = from.name
                version = from.version
                rawDescription = from.rawDescription?.takeUnless(::hasPath)
            }
        }
        val versions = versionKeys.mapNotNull { key ->
            (contexts[key] as? Map<*, *>)?.let { key to versionOnly(it) }
        }
        contexts.clear()
        app?.let(contexts::setApp)
        os?.let(contexts::setOperatingSystem)
        device?.let(contexts::setDevice)
        runtime?.let(contexts::setRuntime)
        for ((key, value) in versions) contexts.put(key, value)
    }

    private fun versionOnly(context: Map<*, *>): Map<String, String> = buildMap {
        for (key in listOf("name", "version", "raw_description")) {
            val value = context[key] as? String ?: continue
            if (key != "raw_description" || !hasPath(value)) put(key, value)
        }
    }

    private fun hasPath(text: String) = '/' in text || '\\' in text
}
