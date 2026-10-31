#!/bin/zsh -l
# Doble clic: compila el .aab firmado para subir a Google Play. Log en tool/play.log
cd "${0:A:h}/.."
[ -f ~/.zshrc ] && source ~/.zshrc >/dev/null 2>&1
export PATH="$HOME/development/flutter/bin:$HOME/flutter/bin:/opt/homebrew/bin:$HOME/.homebrew/bin:/usr/local/bin:$PATH"
LOG=tool/play.log
{
  echo "== $(date)"
  if [ ! -f android/key.properties ]; then echo "== FALTA android/key.properties: abre antes tool/crear_firma.command"; exit 1; fi
  echo "== Version $(grep '^version:' pubspec.yaml)"
  flutter pub get
  flutter build appbundle --release && echo "== AAB OK"
  echo "== FIN codigo=$?"
} > "$LOG" 2>&1
date > tool/play.hecho
open build/app/outputs/bundle/release/ 2>/dev/null
