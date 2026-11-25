package io.vikunja.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

// FlutterFragmentActivity reads its launch configuration from the intent's
// extras without checking them, and any app can start MainActivity: a
// background_mode that is no mode, or dart_entrypoint_args that are no list,
// ends the app's process, and a transparent background would show the caller
// through the app.
internal object LaunchExtras {
    val backgroundMode = BackgroundMode.opaque

    fun dropped(intent: Intent): Intent = Intent(intent).replaceExtras(null as Bundle?)
}
