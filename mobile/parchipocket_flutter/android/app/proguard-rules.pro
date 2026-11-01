# Flutter ProGuard / R8 rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter deferred components (Play Core is optional when not using deferred components)
-dontwarn com.google.android.play.core.**

# Preserve Line Numbers and Source File attributes for mapping production stack traces
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Preserve Annotations and Reflection signatures used by Firebase & Flutter plugins
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Firebase & Google Play Services
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
-keep class com.google.firebase.appcheck.** { *; }

# Firebase Crashlytics: preserve custom exceptions for intelligible crash categorization
-keep public class * extends java.lang.Exception

# Speech to Text plugin (uses Android SpeechRecognizer via reflection)
-keep class cs.com.speech_to_text.** { *; }

# Mobile Scanner plugin (uses MLKit Vision and CameraX)
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**
