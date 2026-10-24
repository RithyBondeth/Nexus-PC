plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nexuspc.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nexuspc.app"
        minSdk = 31
        targetSdk = 36
        ndk { abiFilters += listOf("arm64-v8a") }
        externalNativeBuild { cmake { abiFilters += listOf("arm64-v8a") } }
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing is intentionally unconfigured until the distribution phase.
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    packaging { jniLibs { useLegacyPackaging = true } }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies { testImplementation("junit:junit:4.13.2") }

// Explicit experimental build; the ordinary app remains independently buildable.
if (providers.gradleProperty("nexusRuntime").orNull == "true") {
    require(rootProject.file("../../../runtime/vendor/production/assets/nexus-runtime-build.json").isFile) {
        "Prepare the experimental runtime first: python3 tools/prepare-production-runtime.py"
    }
    android.sourceSets.getByName("main").apply {
        java.srcDir("src/runtime/kotlin")
        manifest.srcFile("src/runtime/AndroidManifest.xml")
    }
    android.packaging.jniLibs.pickFirsts += setOf("**/libc++_shared.so")
    android.packaging.jniLibs.keepDebugSymbols += "**/libnexus_*.so"
    dependencies { implementation(project(":runtime")) }
}
