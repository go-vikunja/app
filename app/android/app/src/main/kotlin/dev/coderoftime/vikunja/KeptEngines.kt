package dev.coderoftime.vikunja

import android.net.Uri
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

// Each MainActivity keeps its Flutter engine across its own relaunches:
// Android relaunches the activity for changes an app cannot opt out of
// (system colours, contrast, wallpaper), and a new engine would restart the
// app at its first screen. Another MainActivity gets an engine of its own and
// never takes over the first one's.
internal object KeptEngines {
    private val engines = HashMap<String, EngineState>()

    fun newId(): String = UUID.randomUUID().toString()

    fun state(id: String): EngineState = engines.getOrPut(id, ::EngineState)

    fun forget(id: String) {
        engines.remove(id)
    }
}

// What stays with the engine when Android relaunches its activity: the running
// app does not repeat what it asked of the window, and a call waiting for an
// activity result is answered by the relaunched activity, which gets the result.
internal class EngineState {
    val window = WindowState()
    val pick = PendingCall<MethodChannel.Result> { it.success(emptyList<Any>()) }
    val saveAs = PendingCall<Pair<File, MethodChannel.Result>> { (_, result) -> result.success(false) }

    @Volatile
    var picked: Set<Uri> = emptySet()
}

internal class WindowState {
    var secure = false
    var recentsScreenshotEnabled: Boolean? = null
    var backMovesTaskToBack = false
}

internal class PendingCall<T : Any>(private val answerWithNothing: (T) -> Unit) {
    private var call: T? = null

    val isPending: Boolean
        get() = call != null

    fun start(call: T) {
        this.call = call
    }

    fun take(): T? = call.also { call = null }

    // Kept, the call waits for the next activity's channel; otherwise it is
    // answered with nothing.
    fun release(keep: Boolean) {
        if (!keep) take()?.let(answerWithNothing)
    }
}
