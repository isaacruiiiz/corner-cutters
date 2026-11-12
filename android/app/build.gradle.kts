import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.isaacruiiiz.cornercutters"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Lo necesitan las notificaciones locales (flutter_local_notifications).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.isaacruiiiz.cornercutters"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Firma de subida para Google Play: android/key.properties (lo crea tool/crear_firma.command).
    // Si no existe, se firma con la clave de depuración (vale para probar, no para Play).
    val keyProps = Properties()
    val keyFile = rootProject.file("key.properties")
    if (keyFile.exists()) keyProps.load(FileInputStream(keyFile))

    signingConfigs {
        if (keyFile.exists()) {
            create("upload") {
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyFile.exists()) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")
            // R8 borraba la base de datos de WorkManager (la usa el SDK de anuncios) y la app se cerraba al abrir.
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
