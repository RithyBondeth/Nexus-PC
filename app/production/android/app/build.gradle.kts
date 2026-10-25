import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Tester release signing comes only from untracked local or CI secrets:
// android/key.properties (gitignored) or NEXUS_SIGNING_* environment
// variables. Without them the release APK stays unsigned, as before.
// This is a tester key, not the distribution-phase Play signing setup.
val signing = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.isFile) file.inputStream().use { load(it) }
    System.getenv("NEXUS_SIGNING_STORE_FILE")?.let { setProperty("storeFile", it) }
    System.getenv("NEXUS_SIGNING_STORE_PASSWORD")?.let { setProperty("storePassword", it) }
    System.getenv("NEXUS_SIGNING_KEY_ALIAS")?.let { setProperty("keyAlias", it) }
    System.getenv("NEXUS_SIGNING_KEY_PASSWORD")?.let { setProperty("keyPassword", it) }
}

fun git(vararg args: String): String = try {
    providers.exec {
        commandLine("git", *args)
        workingDir = rootProject.projectDir.parentFile
        isIgnoreExitValue = true
    }.standardOutput.asText.get().trim()
} catch (_: Exception) { "" }
val sourceRevision = git("rev-parse", "--short=12", "HEAD").ifEmpty { "unknown" } +
    if (git("status", "--porcelain", "--untracked-files=no", "--", ".").isNotEmpty()) "-dirty" else ""

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
        // Lets tester reports name the exact source; "-dirty" marks local edits.
        buildConfigField("String", "GIT_COMMIT", "\"$sourceRevision\"")
    }
    buildFeatures { buildConfig = true }

    val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    if (signingKeys.all { !signing.getProperty(it).isNullOrBlank() }) {
        signingConfigs.create("tester") {
            storeFile = rootProject.file(signing.getProperty("storeFile"))
            storePassword = signing.getProperty("storePassword")
            keyAlias = signing.getProperty("keyAlias")
            keyPassword = signing.getProperty("keyPassword")
        }
        buildTypes.getByName("release").signingConfig = signingConfigs.getByName("tester")
    } else if (signingKeys.any { !signing.getProperty(it).isNullOrBlank() }) {
        throw GradleException("Tester signing is partially configured; set all of ${signingKeys.joinToString()}.")
    }

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
