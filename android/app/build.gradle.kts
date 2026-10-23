import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.falaai.falaai_app"
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
        applicationId = "br.com.falaai.falaai_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// falaai-core (Rust): o cargo-ndk compila a crate do pacote falaai_core antes de cada build e
// as .so entram como jniLibs. Native Assets (ADR-0003) não está disponível no Flutter estável
// 3.35; ver tool/build_core.dart.
val appRoot = rootProject.projectDir.parentFile
val falaaiCoreOut = appRoot.resolve("build/falaai_core")
val localProperties = Properties()
rootProject.file("local.properties").inputStream().use { localProperties.load(it) }
val flutterSdk = requireNotNull(localProperties.getProperty("flutter.sdk")) { "flutter.sdk not set in local.properties" }

val buildFalaaiCore by tasks.registering(Exec::class) {
    description = "Compila o falaai-core para as ABIs do build"
    workingDir = appRoot
    commandLine(
        "$flutterSdk/bin/dart",
        "tool/build_core.dart",
        "--out",
        falaaiCoreOut.path,
        "--ndk",
        android.ndkDirectory.path,
        "--min-sdk",
        flutter.minSdkVersion.toString(),
        "--target-platform",
        project.findProperty("target-platform")?.toString() ?: "",
    )
}

android.sourceSets.getByName("main").jniLibs.srcDir(falaaiCoreOut.resolve("jniLibs"))

tasks.named("preBuild") { dependsOn(buildFalaaiCore) }
