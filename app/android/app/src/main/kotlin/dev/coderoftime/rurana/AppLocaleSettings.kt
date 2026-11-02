package dev.coderoftime.rurana

import android.content.Intent
import android.net.Uri
import android.os.Build

// Android 13's per-app language page for this app; older versions have none.
internal object AppLocaleSettings {
    // Settings.ACTION_APP_LOCALE_SETTINGS, from API 33.
    const val ACTION = "android.settings.APP_LOCALE_SETTINGS"

    fun supported(sdk: Int): Boolean = sdk >= Build.VERSION_CODES.TIRAMISU

    fun canOpen(sdk: Int, resolves: () -> Boolean): Boolean = supported(sdk) && resolves()

    fun intent(packageName: String): Intent =
        Intent(ACTION, Uri.fromParts("package", packageName, null))
}
