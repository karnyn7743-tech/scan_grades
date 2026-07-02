plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // حل مشكلة الـ Manifest
    namespace = "com.baithi.stugrascan"
    compileSdk = 35 // تحديد رقم ثابت ومتوافق مباشرة لمنع خطأ المتغير غير المعرف
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    defaultConfig {
        applicationId = "com.baithi.stugrascan"
        minSdk = 21 
        targetSdk = 35 // رقم ثابت لتأمين عملية تجميع حزم الـ ML Kit
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            // تعديل الكود ليتناسب مع البنية القواعدية لـ Kotlin DSL
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // تحديث السطر ليعتمد على حزمة لغة كوتلن المدمجة تلقائياً لتجنب خطأ kotlin_version
    implementation(platform("org.jetbrains.kotlin:kotlin-bom"))
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
}
