# WorkManager / Room: R8 quitaba WorkDatabase_Impl y la app se cerraba al arrancar
# ("Failed to create an instance of androidx.work.impl.WorkDatabase").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }
-keep class androidx.startup.** { *; }

# Anuncios, compras y consentimiento
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.google.android.play.core.**
