import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

android {
    namespace = "com.clearhear.transcribe_summarize_clearhear"
    compileSdk = 36
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.clearhear.transcribe_summarize_clearhear"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            val keyAliasValue = requireNotNull(keystoreProperties.getProperty("keyAlias")) {
                "Missing keyAlias in key.properties"
            }
            val keyPasswordValue = requireNotNull(keystoreProperties.getProperty("keyPassword")) {
                "Missing keyPassword in key.properties"
            }
            val storeFileValue = requireNotNull(keystoreProperties.getProperty("storeFile")) {
                "Missing storeFile in key.properties"
            }
            val storePasswordValue = requireNotNull(keystoreProperties.getProperty("storePassword")) {
                "Missing storePassword in key.properties"
            }
            create("release") {
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                storeFile = file(storeFileValue)
                storePassword = storePasswordValue
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}
