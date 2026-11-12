#!/bin/zsh -l
# Doble clic: instala el APK en el móvil conectado (o en el emulador), lo abre y guarda el logcat en tool/logcat.txt
cd "${0:A:h}/.."
[ -f ~/.zshrc ] && source ~/.zshrc >/dev/null 2>&1
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$SDK/platform-tools:$SDK/emulator:$PATH"
LOG=tool/logcat.txt
{
  echo "== $(date)"
  adb start-server
  if [ -z "$(adb devices | sed 1d | grep -w device)" ]; then
    AVD=$(emulator -list-avds | head -1)
    echo "== sin dispositivo; AVD: $AVD"
    if [ -n "$AVD" ]; then
      nohup emulator -avd "$AVD" -no-snapshot-save -no-audio >/dev/null 2>&1 &
      adb wait-for-device
      for i in $(seq 1 90); do [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break; sleep 2; done
    fi
  fi
  adb devices -l
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  adb logcat -c
  adb shell monkey -p com.isaacruiiiz.cornercutters -c android.intent.category.LAUNCHER 1
  sleep 12
  echo "== pid: $(adb shell pidof com.isaacruiiiz.cornercutters)"
  echo "== CRASH"
  adb logcat -d -b crash
  echo "== MAIN (filtrado)"
  adb logcat -d | grep -iE "AndroidRuntime|FATAL|flutter|cornercutters|Exception" | tail -200
  echo "== FIN"
} > "$LOG" 2>&1
date > tool/logcat.hecho
