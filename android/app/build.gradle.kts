android {
    compileSdkVersion 35 // تأكد من أنه 35 ليتوافق مع المتطلبات الحالية

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    defaultConfig {
        applicationId "com.example.stugrascan" // أو اسم الـ Package الخاص بك
        minSdkVersion 21
        targetSdkVersion 35
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            // تعطيل الحذف والضغط مؤقتاً لأنه يسبب انهيار المكاتب الخارجية عند الإقلاع
            minifyEnabled false
            shrinkResources false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
