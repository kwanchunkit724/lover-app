# Supabase / Ktor / kotlinx-serialization reflection
-keepattributes *Annotation*, InnerClasses
-dontwarn kotlinx.serialization.**
-dontwarn io.ktor.**
-dontwarn io.github.jan.supabase.**

# Keep @Serializable generated companions (kotlinx-serialization)
-keepclasseswithmembers class **$$serializer { *; }
-keep,includedescriptorclasses class michel.kit.us.**$$serializer { *; }
-keepclassmembers class michel.kit.us.** {
    *** Companion;
}
-keepclasseswithmembers class michel.kit.us.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# BouncyCastle uses reflection in its provider bootstrap
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Coroutines internals
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.android.AndroidExceptionPreHandler {
    <init>();
}
