plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    // حل مشكلة الـ Manifest الجذري عبر تعريف اسم الحزمة هنا كـ namespace
    namespace "com.baithi.stugrascan"
    compileSdkVersion flutter.compileSdkVersion
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.baithi.stugrascan"
        // الحد الأدنى لدعم الأندرويد لكي تتوافق حزم ML Kit والأكواد بسلاسة
        minSdkVersion 21 
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            // إعدادات التوقيع الافتراضية للنسخة النهائية
            signingConfig signingConfigs.debug
            
            // تحسين الحجم وحماية التطبيق عند الرفع لـ Codemagic
            minifyEnabled false
            shrinkResources false
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
}
