import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val isReleaseBuild = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (isReleaseBuild) {
    check(keystorePropertiesFile.exists()) {
        "Missing key.properties at: ${keystorePropertiesFile.absolutePath}"
    }

    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

android {
    namespace = "com.nus.clearhear"
    compileSdk = 36
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nus.clearhear"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (isReleaseBuild) {
            create("release") {
                keyAlias = requireNotNull(
                    keystoreProperties.getProperty("keyAlias")
                ) {
                    "Missing keyAlias in key.properties"
                }

                keyPassword = requireNotNull(
                    keystoreProperties.getProperty("keyPassword")
                ) {
                    "Missing keyPassword in key.properties"
                }

                storePassword = requireNotNull(
                    keystoreProperties.getProperty("storePassword")
                ) {
                    "Missing storePassword in key.properties"
                }

                val storeFileValue = requireNotNull(
                    keystoreProperties.getProperty("storeFile")
                ) {
                    "Missing storeFile in key.properties"
                }

                storeFile = file(storeFileValue)

                check(storeFile?.exists() == true) {
                    "Keystore not found at: ${storeFile?.absolutePath}"
                }
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (isReleaseBuild) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}