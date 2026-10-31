#!/bin/zsh -l
# Doble clic en Finder: analiza, pasa los tests, compila la web (servida en http://localhost:8765) y el APK release. Log en tool/ultimo.log
cd "${0:A:h}/.."
[ -f ~/.zshrc ] && source ~/.zshrc >/dev/null 2>&1
export PATH="$HOME/development/flutter/bin:$HOME/flutter/bin:/opt/homebrew/bin:$HOME/.homebrew/bin:/usr/local/bin:$PATH"
LOG=tool/ultimo.log
{
  echo "== $(date)"
  if [ ! -d android ] || [ ! -d ios ] || [ ! -d web ]; then
    flutter create --org com.isaacruiiiz --project-name corner_cutters --platforms android,ios,web .
  fi
  flutter pub get
  flutter analyze --no-fatal-infos --no-fatal-warnings
  echo "== TEST"
  flutter test
  echo "== WEB"
  flutter build web --release && echo "== WEB OK"
  echo "== APK"
  flutter build apk --release && echo "== APK OK"
  echo "== FIN codigo=$?"
} > "$LOG" 2>&1
pkill -f "http.server 8765"
nohup python3 -m http.server 8765 --directory build/web >/dev/null 2>&1 &
date > tool/hecho
