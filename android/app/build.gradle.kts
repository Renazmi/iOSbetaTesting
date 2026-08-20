plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import com.android.build.gradle.internal.api.ApkVariantOutputImpl

android {
    namespace = "com.trackit.trackit_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.trackit.trackit_mobile"
        // Android 8.0+ Oreo (API 26). Blocks all Nougat (7.0/7.1) and below.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        checkReleaseBuilds = false
    }
}

@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    if (buildType.name == "release") {
        outputs.configureEach {
            (this as ApkVariantOutputImpl).outputFileName = "TrackIT.apk"
        }
    }
}

flutter {
    source = "../.."
}

val mobileProjectDir = rootProject.projectDir.parentFile!!
val releasesDir = mobileProjectDir.parentFile.resolve("releases")

tasks.register("exportTrackITApk") {
    dependsOn("assembleRelease")
    doLast {
        val outputDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        val namedApk = outputDir.resolve("TrackIT.apk")
        val legacyApk = outputDir.resolve("app-release.apk")
        val source = when {
            namedApk.exists() -> namedApk
            legacyApk.exists() -> legacyApk
            else -> throw GradleException("Release APK not found in ${outputDir.absolutePath}")
        }
        releasesDir.mkdirs()
        val releasesDest = releasesDir.resolve("TrackIT.apk")
        source.copyTo(releasesDest, overwrite = true)
        logger.lifecycle("Exported release APK to ${releasesDest.absolutePath}")
    }
}
