# Flutter ProGuard rules
# Flutter does not need additional ProGuard rules.
# Add project-specific rules here if needed.

# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep SQLite / Drift
-keep class com.almworks.sqlite4java.** { *; }
