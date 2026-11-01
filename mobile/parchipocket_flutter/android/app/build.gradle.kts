import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Production release signing configuration loader
// Reads from android/key.properties (or android/app/key.properties) or environment variables.
val keystorePropertiesFile = listOf(
    rootProject.file("key.properties"),
    project.file("key.properties")
).firstOrNull { it.exists() && it.isFile }

val keyProperties = Properties()
if (keystorePropertiesFile != null) {
    FileInputStream(keystorePropertiesFile).use { keyProperties.load(it) }
}

fun getSigningProperty(key: String, envVar: String): String? {
    return keyProperties.getProperty(key)?.trim()?.takeIf { it.isNotEmpty() }
        ?: System.getenv(envVar)?.trim()?.takeIf { it.isNotEmpty() }
}

val storeFilePath = getSigningProperty("storeFile", "PP_UPLOAD_KEYSTORE_PATH")
val releaseStorePassword = getSigningProperty("storePassword", "PP_UPLOAD_KEYSTORE_PASSWORD")
val releaseKeyAlias = getSigningProperty("keyAlias", "PP_UPLOAD_KEY_ALIAS")
val releaseKeyPassword = getSigningProperty("keyPassword", "PP_UPLOAD_KEY_PASSWORD")

val isReleaseSigningConfigured = !storeFilePath.isNullOrEmpty() &&
        !releaseStorePassword.isNullOrEmpty() &&
        !releaseKeyAlias.isNullOrEmpty() &&
        !releaseKeyPassword.isNullOrEmpty()

android {
    namespace = "com.parchipocket.app.parchipocket"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.parchipocket.app.parchipocket"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (isReleaseSigningConfigured) {
            val resolvedStoreFile = if (File(storeFilePath!!).isAbsolute) {
                File(storeFilePath)
            } else {
                rootProject.file(storeFilePath)
            }
            create("release") {
                storeFile = resolvedStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
            tasks.configureEach {
                if (name == "validateSigningRelease") {
                    doFirst {
                        if (!resolvedStoreFile.exists()) {
                            throw GradleException(
                                "Production release signing failed: Keystore file not found at: '${resolvedStoreFile.absolutePath}'.\n" +
                                "Please verify 'storeFile' in android/key.properties or the PP_UPLOAD_KEYSTORE_PATH environment variable."
                            )
                        }
                    }
                }
            }
        }
    }

    buildTypes {
        release {
            if (isReleaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Strict security: Never silently fall back to debug signing for release builds.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Fail release and bundle tasks immediately if production signing is not configured.
gradle.taskGraph.whenReady {
    val isReleaseBuildRequested = allTasks.any { task ->
        val name = task.name
        name == "packageRelease" ||
            name == "bundleRelease" ||
            name == "assembleRelease"
    }
    if (isReleaseBuildRequested && !isReleaseSigningConfigured) {
        throw GradleException(
            "\n" +
            "========================================================================================\n" +
            "RELEASE SIGNING ERROR: Production release signing is not configured.\n" +
            "ParchiPocket strictly forbids using Android debug keys for release builds.\n\n" +
            "To configure release signing, provide credentials via either:\n\n" +
            "1. Local file (untracked): Create 'mobile/parchipocket_flutter/android/key.properties' with:\n" +
            "     storeFile=<path_to_upload_keystore>\n" +
            "     storePassword=<keystore_password>\n" +
            "     keyAlias=<key_alias>\n" +
            "     keyPassword=<key_password>\n\n" +
            "2. Environment variables (CI/CD):\n" +
            "     PP_UPLOAD_KEYSTORE_PATH=<path_to_upload_keystore>\n" +
            "     PP_UPLOAD_KEYSTORE_PASSWORD=<keystore_password>\n" +
            "     PP_UPLOAD_KEY_ALIAS=<key_alias>\n" +
            "     PP_UPLOAD_KEY_PASSWORD=<key_password>\n" +
            "========================================================================================\n"
        )
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
