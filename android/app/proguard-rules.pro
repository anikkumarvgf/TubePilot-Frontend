# Keep rules for release builds.
# Keep Firebase / Google / OneSignal / Flutter runtime classes that can be stripped
# by R8 when they are referenced indirectly.
-keep class com.google.firebase.** { *; }
-keep class com.onesignal.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class com.tubepilot.app.** { *; }
-keepattributes *Annotation*
