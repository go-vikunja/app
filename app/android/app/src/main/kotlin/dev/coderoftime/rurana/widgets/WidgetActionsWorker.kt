package dev.coderoftime.rurana.widgets

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.glance.appwidget.updateAll
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

// Runs the Dart entry point widgetActionsMain in a headless engine and
// stays until it reports back, so WorkManager keeps the process alive while
// Dart writes the Done and sends it (home_widget's worker returns at once).
// The Dart side takes the queued taps, then writes every snapshot again.
class WidgetActionsWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        try {
            val publish = inputData.getBoolean(KEY_PUBLISH, false)
            if (publish || WidgetActionQueue(WidgetFiles.of(applicationContext)).hasWork()) {
                withTimeoutOrNull(DART_TIMEOUT_MS) { runDart() } ?: Log.w(TAG, "widgetActionsMain did not finish in time")
            }
        } finally {
            withContext(NonCancellable) { TasksWidget().updateAll(applicationContext) }
        }
        return Result.success()
    }

    private suspend fun runDart() {
        val finished = CompletableDeferred<Unit>()
        val engine = withContext(Dispatchers.Main) { startEngine(finished) }
        try {
            finished.await()
        } finally {
            withContext(NonCancellable + Dispatchers.Main) { engine.destroy() }
        }
    }

    private suspend fun startEngine(finished: CompletableDeferred<Unit>): FlutterEngine {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) loader.startInitialization(applicationContext)
        suspendCoroutine { continuation ->
            loader.ensureInitializationCompleteAsync(applicationContext, null, Handler(Looper.getMainLooper())) {
                continuation.resume(Unit)
            }
        }
        val engine = FlutterEngine(applicationContext)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "finished") {
                result.success(null)
                finished.complete(Unit)
            } else {
                result.notImplemented()
            }
        }
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRY_LIBRARY, ENTRY_POINT),
        )
        return engine
    }

    companion object {
        private const val TAG = "RuranaWidgets"
        private const val WORK_NAME = "rurana_widget_actions"
        private const val KEY_PUBLISH = "publish"
        private const val CHANNEL = "dev.coderoftime.rurana/widget_worker"
        private const val ENTRY_LIBRARY = "package:vikunja_mobile/core/widgets/widget_entry_points.dart"
        private const val ENTRY_POINT = "widgetActionsMain"

        // Room for the headless engine's start and every queued tap with
        // its send timeout; below WorkManager's 10 min.
        private const val DART_TIMEOUT_MS = 3 * 60 * 1000L

        // [publish] runs the Dart side even without queued taps, to write
        // stale snapshots again. Below Android 12 expedited work needs a
        // foreground notification.
        fun enqueue(context: Context, publish: Boolean = false) {
            val request = OneTimeWorkRequestBuilder<WidgetActionsWorker>().apply {
                setInputData(workDataOf(KEY_PUBLISH to publish))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                }
            }.build()
            WorkManager.getInstance(context).enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.APPEND_OR_REPLACE, request)
        }
    }
}
