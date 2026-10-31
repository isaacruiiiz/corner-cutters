#!/bin/zsh -l
# Doble clic en Finder: pub get + análisis + tests (rápido). Log en tool/analisis.log
cd "${0:A:h}/.."
[ -f ~/.zshrc ] && source ~/.zshrc >/dev/null 2>&1
export PATH="$HOME/development/flutter/bin:$HOME/flutter/bin:/opt/homebrew/bin:$HOME/.homebrew/bin:/usr/local/bin:$PATH"
LOG=tool/analisis.log
{
  echo "== $(date)"
  flutter pub get
  flutter analyze --no-fatal-infos --no-fatal-warnings
  echo "== ANALYZE codigo=$?"
  flutter test
  echo "== TEST codigo=$?"
  echo "== FIN"
} > "$LOG" 2>&1
date > tool/analisis.hecho
osascript -e 'tell application "Terminal" to close (every window whose name contains "analizar")' >/dev/null 2>&1 &
