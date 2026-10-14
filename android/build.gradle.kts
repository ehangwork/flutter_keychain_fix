import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
}

group = "com.ehangwork.flutterkeychainfix"
version = "1.0-SNAPSHOT"

// AGP and KGP are intentionally NOT declared here. They are provided by the
// host application's Gradle build, so pinning versions in a published plugin
// only creates classpath conflicts with the consuming app.
rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

android {
    namespace = "com.ehangwork.flutterkeychainfix"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 18
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    lint {
        disable += "InvalidPackage"
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

// Do not apply `kotlin-android` here and do not pin an AGP/KGP classpath: both come from
// the host application's Gradle build. Flutter 3.44 still ships `android.builtInKotlin=false`
// in its own template, so today Kotlin support arrives through the host's KGP — this block
// stays valid either way.
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.12.2")

    androidTestImplementation("androidx.test:runner:1.5.2")
    androidTestImplementation("androidx.test:rules:1.5.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
}