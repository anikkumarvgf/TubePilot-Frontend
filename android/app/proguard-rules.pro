# Cashfree & PayU SDK rules
-keep class com.cashfree.** { *; }
-dontwarn com.cashfree.**
-keep class com.payu.** { *; }
-dontwarn com.payu.**

# Google Play Core & Play Services
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.apps.nbu.paisa.**

# AndroidX Window
-dontwarn androidx.window.**