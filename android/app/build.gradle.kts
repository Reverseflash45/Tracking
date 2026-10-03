import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis dari android/key.properties (tidak di-commit). Di laptop file ini
// menunjuk ke keystore di luar repo; di GitHub Actions file ini ditulis dari
// Secrets oleh workflow rilis. Tanpa file ini, build rilis jatuh ke debug key —
// cukup untuk mencoba, tapi APK-nya tidak bisa jadi update dari rilis resmi.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val punyaKunciRilis = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.rafifernandito.tracking"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Diwajibkan flutter_local_notifications supaya notifikasi terjadwal
        // tetap jalan di versi Android lama.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Bukan lagi com.example.*: Play Store menolak ID itu, dan ID ini tidak
        // bisa diganti lagi setelah app pertama kali dirilis.
        applicationId = "com.rafifernandito.tracking"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect (paket health) butuh Android 8.0 / API 26.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (punyaKunciRilis) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (punyaKunciRilis) "release" else "debug")

            // ML Kit text recognition merujuk pengenal aksara non-Latin yang
            // tidak ikut ditarik; tanpa aturan ini R8 menggagalkan build rilis.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Tema AppCompat untuk LaunchTheme: dialog sidik jari local_auth crash di
    // Android 8 kalau tema activity-nya bukan turunan AppCompat.
    implementation("androidx.appcompat:appcompat:1.7.1")
}
