# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Dart/Flutter SQLite (drift)
-keep class com.tekartik.sqflite.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep native crash info readable in stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
