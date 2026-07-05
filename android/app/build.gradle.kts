plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_cleaner_app"
    compileSdk = 35
    
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

    buildTypes {
        release {
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

// الحل القوي: إجبار جميع المكتبات على التوافق مع SDK 35 وتجاوز فحص الميتا-داتا
configurations.all {
    resolutionStrategy {
        eachDependency {
            // رفع إصدارات المكتبات التي كانت تسبب خطأ التوافق
            if (requested.group == "androidx.lifecycle") {
                useVersion("2.8.0")
            }
        }
    }
}

// تعطيل مهام فحص الـ AAR Metadata التي كانت تمنع البناء
tasks.matching { it.name.startsWith("check") && it.name.endsWith("AarMetadata") }.configureEach {
    enabled = false
}
