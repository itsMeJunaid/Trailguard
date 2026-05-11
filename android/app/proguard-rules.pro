-keep class io.flutter.** { *; }
-keep class com.trailguard.ai.** { *; }
-dontwarn io.flutter.embedding.**

# Google AI Edge LiteRT-LM (Gemma runtime)
-keep class com.google.ai.edge.litertlm.** { *; }
-keep class com.google.ai.edge.litert.** { *; }
-dontwarn com.google.ai.edge.**
-keepclassmembers class com.google.ai.edge.litertlm.** {
    native <methods>;
}

# kotlinx.coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# TensorFlow Lite — GPU delegate optional
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# flutter_downloader
-keep class vn.hunghd.flutterdownloader.** { *; }
-dontwarn vn.hunghd.flutterdownloader.**

# OkHttp / TLS shims (transitive)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# javax annotation-processor leftovers
-dontwarn javax.lang.model.**
-dontwarn javax.annotation.**

# Play Core
-dontwarn com.google.android.play.**
