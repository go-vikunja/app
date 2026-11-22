pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Glance widgets; must match the Kotlin version above.
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.0" apply false
}

include(":app")

// sentry_flutter's build script puts the Android Gradle plugin 7.4.2 on its
// own classpath, which would fetch that plugin and its tools; like every
// plugin it runs on the app's version declared above.
gradle.beforeProject {
    if (name == "sentry_flutter") {
        buildscript.configurations.configureEach {
            withDependencies {
                removeIf { it.group == "com.android.tools.build" && it.name == "gradle" }
            }
        }
    }
}
