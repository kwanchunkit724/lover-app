// Top-level build file — wires plugin versions for all modules.
//
// We use Kotlin 2.0+ which moved the Compose compiler out of the AGP-bundled
// kotlinCompilerExtensionVersion and into a standalone plugin
// (org.jetbrains.kotlin.plugin.compose). All three versions are declared
// `apply false` here and turned on per-module in app/build.gradle.kts.

plugins {
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.0.21" apply false
    // Phase B Round 2 — Firebase services. Reads app/google-services.json and
    // generates the values resources Firebase SDKs need at runtime. Applied
    // in app/build.gradle.kts.
    id("com.google.gms.google-services") version "4.4.2" apply false
}
