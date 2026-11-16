import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (D86): CI builds unsigned with VIKUNJA_APP_UNSIGNED=true,
// and tool/ci/release_sign.sh signs the files afterwards. A local release
// build uses all four keys of android/key.properties (never committed);
// otherwise the debug key signs.
val unsigned = providers.environmentVariable("VIKUNJA_APP_UNSIGNED").orNull == "true"
val releaseSigning: Map<String, String>? = run {
    val keyProperties = rootProject.file("key.properties")
    if (unsigned || !keyProperties.isFile) {
        null
    } else {
        val keys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        val properties = Properties().apply { keyProperties.inputStream().use { load(it) } }
        val values = keys.associateWith { properties.getProperty(it)?.takeIf(String::isNotEmpty) }
        val missing = values.filterValues { it == null }.keys
        if (missing.isNotEmpty()) {
            throw GradleException("$keyProperties needs storeFile, storePassword, keyAlias and keyPassword; missing: ${missing.joinToString()}")
        }
        values.mapValues { it.value!! }
    }
}

android {
    namespace = "io.vikunja.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules through java.time.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.vikunja.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        compose = true
    }

    signingConfigs {
        if (releaseSigning != null) {
            create("release") {
                // A relative path is relative to android/, like key.properties.
                storeFile = rootProject.file(releaseSigning.getValue("storeFile"))
                storePassword = releaseSigning.getValue("storePassword")
                keyAlias = releaseSigning.getValue("keyAlias")
                keyPassword = releaseSigning.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (unsigned) null else signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            proguardFiles("proguard-rules.pro")
        }
    }
}

// Flutter runs Gradle with -q, which shows quiet messages only.
if (!unsigned && releaseSigning == null) {
    tasks.matching { it.name == "packageRelease" || it.name == "signReleaseBundle" }.configureEach {
        doFirst {
            logger.quiet(
                "warning: this release build is signed with the debug key: no android/key.properties " +
                    "and no VIKUNJA_APP_UNSIGNED=true (docs/releasing.md)",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// gradle.lockfile, for the vulnerability scan. After a plugin or Flutter
// upgrade: ./gradlew :app:dependencies --write-locks
// Locks only what ships and the JVM tests: the tooling classpaths (lint, test
// platform, Kotlin compiler) change with every AGP update and never ship.
configurations.configureEach {
    if (name.endsWith("RuntimeClasspath")) {
        resolutionStrategy.activateDependencyLocking()
    }
}

// The engine artifacts change with every Flutter version.
dependencyLocking {
    ignoredDependencies.add("io.flutter:*")
}

// Embedded Cronet instead of Google Play services Cronet, so that Cronet
// works on every device without Play services, the app holds no proprietary
// code and F-Droid stays possible (D5). cronet_http picks Play services
// unless built with --dart-define=cronetHttpNoPlay=true; excluding it here
// makes every build, test and CI run embedded without that define.
// cronet-bundled's POMs also pull Google's empty transitional Cronet
// artifacts (no classes, under the Android SDK licence), and that define
// would pull the old cronet-embedded; nothing needs them.
configurations.configureEach {
    exclude(group = "com.google.android.gms", module = "play-services-cronet")
    for (module in listOf(
        "cronet-api", "cronet-common", "cronet-embedded", "cronet-fallback", "cronet-shared",
        "httpengine-native-provider",
    )) {
        exclude(group = "org.chromium.net", module = module)
    }
}

dependencies {
    // A build of a Chrome stable release, with org.chromium.net:cronet of
    // the same build. Raise it with each new version on Google's Maven, then
    // run tool/build_android_notices.py --refresh-cronet (docs/releasing.md).
    implementation("org.chromium.net:cronet-bundled:500.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FileProvider and IntentCompat for attachments and shares; declared
    // here rather than relied on through the plugins.
    implementation("androidx.core:core:1.18.0")
    // Location removal; the version image_picker_android resolves to.
    implementation("androidx.exifinterface:exifinterface:1.4.2")
    // Home-screen widgets. The Compose compiler plugin above fails the build
    // without the Compose runtime that Glance brings.
    implementation("androidx.glance:glance-appwidget:1.2.0")
    // Already in the app through workmanager; declared for the widget worker.
    // Below 2.11.2, R8 stripped Glance's RemoteViews translator.
    implementation("androidx.work:work-runtime:2.11.2")
    // The AppCompat themes MainActivity needs for local_auth; biometric
    // 1.1.0 would otherwise pull in 1.2.0.
    implementation("androidx.appcompat:appcompat:1.8.0")

    testImplementation("junit:junit:4.13.2")
    // The JVM tests parse with the real org.json; android.jar has stubs.
    testImplementation("org.json:json:20260814")
}
