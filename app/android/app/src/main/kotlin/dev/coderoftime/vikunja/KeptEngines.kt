package dev.coderoftime.vikunja

import java.util.UUID

// Each MainActivity keeps its Flutter engine across its own relaunches:
// Android relaunches the activity for changes an app cannot opt out of
// (system colours, contrast, wallpaper), and a new engine would restart the
// app at its first screen. Another MainActivity gets an engine of its own and
// never takes over the first one's.
internal object KeptEngines {
    private val windows = HashMap<String, WindowState>()

    fun newId(): String = UUID.randomUUID().toString()

    fun window(id: String): WindowState = windows.getOrPut(id, ::WindowState)

    fun forget(id: String) {
        windows.remove(id)
    }
}

// What Dart last asked of the window. It stays with the engine, because the
// running app does not repeat it to a relaunched activity.
internal class WindowState {
    var secure = false
    var recentsScreenshotEnabled: Boolean? = null
    var backMovesTaskToBack = false
}
