#!/bin/zsh -l
# Doble clic en Finder: genera capturas de los tableros nuevos en tool/capturas/out
cd "${0:A:h}/.."
[ -f ~/.zshrc ] && source ~/.zshrc >/dev/null 2>&1
export PATH="$HOME/development/flutter/bin:$HOME/flutter/bin:/opt/homebrew/bin:$HOME/.homebrew/bin:/usr/local/bin:$PATH"
flutter test tool/capturas/tableros_test.dart --update-goldens > tool/capturas/log.txt 2>&1
date > tool/capturas/hecho
osascript -e 'tell application "Terminal" to close (every window whose name contains "capturas")' >/dev/null 2>&1 &
