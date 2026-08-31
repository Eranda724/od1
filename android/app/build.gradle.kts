import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envFile = rootProject.file("../.env")
val envProperties = Properties()
if (envFile.exists()) {
    envProperties.load(FileInputStream(envFile))
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.ghiolabs.potato60secondroutine"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = rootProject.file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.ghiolabs.potato60secondroutine"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["ADMOB_APP_ID_ANDROID"] = envProperties.getProperty("ADMOB_APP_ID_ANDROID", "ca-app-pub-3940256099942544~3347511713").toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Ensure all Kotlin plugin compilations finish before app's Java compilation.
// Fixes: GeneratedPluginRegistrant.java referencing Kotlin plugin classes (e.g. audioplayers)
afterEvaluate {
    tasks.matching { it.name.startsWith("compileRelease") && it.name.endsWith("JavaWithJavac") }.configureEach {
        dependsOn(
            rootProject.subprojects
                .filter { it.name != "app" && it.name != "gradle" }
                .mapNotNull { sub ->
                    sub.tasks.findByName("compileReleaseKotlin")
                        ?: sub.tasks.findByName("compileKotlin")
                }
        )
    }
}
