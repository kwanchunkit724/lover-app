// app/build.gradle.kts — single Android application module.
//
// Bundle ID `michel.kit.us` is shared with the iOS app on purpose (same product
// name on Play Store + App Store). Play Store treats it as a separate listing.
//
// Encryption export: this app uses AES-GCM + X25519 ECDH for end-to-end
// message encryption. On iOS we ship ITSAppUsesNonExemptEncryption=true.
// Google Play has no equivalent manifest flag — the encryption disclosure is
// handled in the Play Console "App content" → "Government-grade encryption"
// questionnaire at upload time. Standard AES/X25519 qualifies as exempt under
// US BIS exception ENC (5D002.c.1). Document on first upload; no code needed.

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "michel.kit.us"
    // compileSdk 35 = Android 15 / V. AndroidX 1.15.0 (core, core-ktx,
    // lifecycle, activity-compose) hard-requires it; AGP otherwise fails
    // checkDebugAarMetadata with "Dependency requires a newer compileSdk".
    compileSdk = 35

    defaultConfig {
        applicationId = "michel.kit.us"
        minSdk = 26
        // targetSdk 35 keeps us aligned with Play Store's 2025+ floor.
        targetSdk = 35
        versionCode = 1
        versionName = "1.5.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }

        // Bundle the per-language string resources we actually ship.
        resourceConfigurations += listOf("zh-rHK", "zh-rTW", "en", "ja")
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs = listOf(
            "-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi",
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi"
        )
    }
    buildFeatures {
        compose = true
    }
    packaging {
        resources.excludes += setOf(
            "/META-INF/{AL2.0,LGPL2.1}",
            "/META-INF/versions/9/OSGI-INF/MANIFEST.MF",
            "/META-INF/INDEX.LIST",
            "/META-INF/io.netty.versions.properties"
        )
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }
}

// Pin a tested Supabase Kotlin SDK 3.x BOM. Newer BOMs are fine — adjust here.
val supabaseBom = "io.github.jan-tennert.supabase:bom:3.1.4"
val composeBom  = "androidx.compose:compose-bom:2024.11.00"

dependencies {
    // --- Compose ---
    implementation(platform(composeBom))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.navigation:navigation-compose:2.8.4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    // --- Core ---
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Material View library — supplies res/values/themes.xml parent
    // `Theme.Material3.DayNight.NoActionBar`. Compose itself doesn't
    // need it, but the host Activity theme does.
    implementation("com.google.android.material:material:1.12.0")

    // --- Coroutines ---
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.6.1")

    // --- Supabase ---
    implementation(platform(supabaseBom))
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")
    // Ktor engine — Supabase needs one; OkHttp is the Android-idiomatic pick.
    implementation("io.ktor:ktor-client-okhttp:3.0.1")

    // --- DataStore (for preferences — chat draft, theme, etc.) ---
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // --- Image loading ---
    implementation("io.coil-kt:coil-compose:2.7.0")

    // --- Crypto: BouncyCastle for X25519 raw key handling.
    //     AES-GCM uses platform javax.crypto (BouncyCastle would also work
    //     but JCA's SunJCE/AndroidOpenSSL provider is faster and audited).
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")

    // --- Encrypted prefs (for X25519 private key at rest) ---
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}
