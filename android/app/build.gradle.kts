plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.felix.depstream"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.felix.depstream"
        // Etapa 0: el piso es 24, como en el plan. No se baja.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Firma estable (Etapa 0): si el CI restauró el keystore dedicado y
    // exportó sus credenciales, el build debug usa esa clave; si no hay
    // ninguna variable, no se toca nada y Gradle usa su debug keystore
    // por defecto (comportamiento previo). Si hay alguna variable pero
    // falta otra o el keystore, se falla cerrado: nunca se firma en
    // silencio con una clave distinta a la pedida. Las credenciales
    // llegan solo por variables de entorno (secretos de GitHub Actions
    // en CI) y nunca se escriben en el repo.
    signingConfigs {
        getByName("debug") {
            val storePassword = System.getenv("DEPSTREAM_DEBUG_KEYSTORE_PASSWORD")
            val keyAlias = System.getenv("DEPSTREAM_DEBUG_KEY_ALIAS")
            val keyPassword = System.getenv("DEPSTREAM_DEBUG_KEY_PASSWORD")
            if (storePassword != null || keyAlias != null || keyPassword != null) {
                val keystorePath = System.getenv("DEPSTREAM_DEBUG_KEYSTORE_PATH")
                    ?: "${System.getProperty("user.home")}/.android/debug.keystore"
                val keystoreFile = File(keystorePath)
                check(storePassword != null && keyAlias != null && keyPassword != null) {
                    "Firma estable: faltan variables DEPSTREAM_DEBUG_KEYSTORE_PASSWORD, " +
                        "DEPSTREAM_DEBUG_KEY_ALIAS o DEPSTREAM_DEBUG_KEY_PASSWORD"
                }
                check(keystoreFile.exists()) {
                    "Firma estable: no existe el keystore en $keystorePath"
                }
                storeFile = keystoreFile
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Solo para las pruebas unitarias Kotlin (PermissionStateResolverTest).
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
