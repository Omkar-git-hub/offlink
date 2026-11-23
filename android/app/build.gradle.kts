plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.omkar_git_hub.offlink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.omkar_git_hub.offlink"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("OFFLINK_KEYSTORE_PATH")
            val keystorePassword = System.getenv("OFFLINK_KEYSTORE_PASSWORD")
            val keyAlias = System.getenv("OFFLINK_KEY_ALIAS")
            val keyPassword = System.getenv("OFFLINK_KEY_PASSWORD")

            if (!keystorePath.isNullOrEmpty() && file(keystorePath).exists()) {
                storeFile = file(keystorePath)
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter { task ->
        val name = task.name.lowercase()
        name.contains("release") && (name.contains("package") || name.contains("assemble") || name.contains("bundle"))
    }
    if (releaseTasks.isNotEmpty()) {
        val keystorePath = System.getenv("OFFLINK_KEYSTORE_PATH")
        val keystorePassword = System.getenv("OFFLINK_KEYSTORE_PASSWORD")
        val keyAlias = System.getenv("OFFLINK_KEY_ALIAS")
        val keyPassword = System.getenv("OFFLINK_KEY_PASSWORD")

        val missing = mutableListOf<String>()
        if (keystorePath.isNullOrBlank()) missing.add("OFFLINK_KEYSTORE_PATH")
        if (keystorePassword.isNullOrBlank()) missing.add("OFFLINK_KEYSTORE_PASSWORD")
        if (keyAlias.isNullOrBlank()) missing.add("OFFLINK_KEY_ALIAS")
        if (keyPassword.isNullOrBlank()) missing.add("OFFLINK_KEY_PASSWORD")

        if (missing.isNotEmpty()) {
            throw GradleException(
                "FAIL-CLOSED: Release signing credentials are missing: ${missing.joinToString(", ")}. " +
                "Production release APKs cannot be built without valid signing credentials. " +
                "Silent fallback to debug signing is disabled."
            )
        }

        val keystoreFile = file(keystorePath)
        if (!keystoreFile.exists() || !keystoreFile.isFile) {
            throw GradleException(
                "FAIL-CLOSED: Keystore file not found at OFFLINK_KEYSTORE_PATH: $keystorePath. " +
                "Production release APKs cannot be built without a valid keystore file."
            )
        }
    }
}


kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
}

flutter {
    source = "../.."
}
