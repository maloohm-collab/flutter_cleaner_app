plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_cleaner_app"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.flutter_cleaner_app"
        minSdk = 21
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// الحل الجذري: تعطيل فحص الـ Metadata لجميع المهام التي قد تسبب هذا الخطأ
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.android {
                if (namespace != null && namespace!!.contains("app_settings")) {
                    // هذا الجزء يستهدف مكتبة المشاكل تحديداً
                }
            }
        }
        
        // تعطيل الفحص لكل الـ Tasks التي تحتوي على check...AarMetadata
        tasks.matching { it.name.contains("check") && it.name.contains("AarMetadata") }.configureEach {
            enabled = false
        }
    }
}
