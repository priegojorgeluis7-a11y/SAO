import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing properties from android/key.properties (excluded from VCS)
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

val compileSdkVersion = 36
val targetSdkVersion = 36
val javaVersion = JavaVersion.VERSION_17

android {
    namespace = "com.tmq.sao"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = javaVersion
        targetCompatibility = javaVersion
    }

    signingConfigs {
        create("release") {
            // getProperty(key, default) returns "" when key.properties is absent,
            // avoiding the null-cast NPE that crashes Gradle configuration phase.
            keyAlias      = keyProperties.getProperty("keyAlias",      "")
            keyPassword   = keyProperties.getProperty("keyPassword",   "")
            storeFile     = keyProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keyProperties.getProperty("storePassword", "")
        }
    }

    defaultConfig {
        applicationId = "com.tmq.sao"
        minSdk = flutter.minSdkVersion
        targetSdk = targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            keepDebugSymbols += setOf("**/*.so")
        }
    }

    buildTypes {
        release {
            // Use production signing only when key.properties is present.
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
