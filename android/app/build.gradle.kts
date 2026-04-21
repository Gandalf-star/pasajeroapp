plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    id("com.google.gms.google-services")
}

android {
    namespace = "click_express.project"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    
    // Configuración de lint para evitar errores en la compilación de release
    lint {
        checkReleaseBuilds = false
        disable.add("FullBackupContent")
        abortOnError = false
    }

    defaultConfig {
        applicationId = "click_express.project"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // IMPORTANTE: Para publicar en Play Store, debes generar un keystore
            // y configurar la firma de release. Ver guía en KEYSTORE_GUIDE.md
            
            // Temporalmente usa debug (SOLO PARA PRUEBAS INTERNAS)
            signingConfig = signingConfigs.getByName("debug")
            
            // Cuando tengas tu keystore, comenta la línea anterior y descomenta:
            // signingConfig = signingConfigs.getByName("release")
            
            // Optimizaciones para release
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Dependencia para core library desugaring (requerida por flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Dependencia del Firebase Android BoM (Bill of Materials)
    // Esto asegura que todas tus dependencias de Firebase usen versiones compatibles.
    // Usa la última versión del BoM.
    implementation(platform("com.google.firebase:firebase-bom:32.8.0")) // <-- VERIFICA LA ÚLTIMA VERSIÓN

    // Dependencias de Firebase específicas que estás usando en tu proyecto
    // (Asegúrate de agregar todas las que necesites, por ejemplo: analytics, auth, etc.)
    implementation("com.google.firebase:firebase-database") // <-- Para Firebase Realtime Database
    implementation("com.google.firebase:firebase-analytics-ktx") // <-- Recomendado para Firebase Analytics
    // Puedes añadir más aquí según los servicios de Firebase que utilices, por ejemplo:
    // implementation("com.google.firebase:firebase-auth-ktx") // Para autenticación
    // implementation("com.google.firebase:firebase-firestore-ktx") // Para Firestore
}
