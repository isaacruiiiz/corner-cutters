#!/bin/zsh -l
# Doble clic: crea la clave de subida para Google Play y android/key.properties.
# La contraseña la escribes tú aquí; no se guarda en ningún otro sitio.
cd "${0:A:h}/.."
KS="$HOME/claves/corner-cutters-upload.jks"
if [ -f android/key.properties ] || [ -f "$KS" ]; then
  echo "Ya existe una clave ($KS o android/key.properties). No la piso."
  echo "Pulsa Intro para cerrar."; read; exit 0
fi
KT=""
for c in "$(command -v keytool 2>/dev/null)" \
  "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
  "/Applications/Android Studio.app/Contents/jre/Contents/Home/bin/keytool" \
  "$(/usr/libexec/java_home 2>/dev/null)/bin/keytool"; do
  [ -n "$c" ] && [ -x "$c" ] && KT="$c" && break
done
if [ -z "$KT" ]; then echo "No encuentro keytool (viene con Android Studio)."; read; exit 1; fi
echo "Clave de subida de Corner Cutters para Google Play"
echo "Elige una contraseña (mínimo 6 caracteres) y guárdala en tu gestor de contraseñas."
echo "Si la pierdes, Google puede restablecer la clave de subida, pero tarda unos días."
while true; do
  read -s "P1?Contraseña: "; echo
  read -s "P2?Repite la contraseña: "; echo
  [ "$P1" = "$P2" ] && [ ${#P1} -ge 6 ] && break
  echo "No coinciden o es demasiado corta. Otra vez."
done
mkdir -p "$HOME/claves"
"$KT" -genkeypair -v -keystore "$KS" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload -storepass "$P1" -keypass "$P1" -dname "CN=Corner Cutters, O=Isaac Ruiz, C=ES" || { echo "Ha fallado keytool."; read; exit 1; }
cat > android/key.properties <<PROPS
storePassword=$P1
keyPassword=$P1
keyAlias=upload
storeFile=$KS
PROPS
chmod 600 android/key.properties "$KS"
unset P1 P2
echo ""
echo "Hecho. Clave en $KS y configuración en android/key.properties."
echo "Haz copia de seguridad de $KS (por ejemplo en un USB o en tu gestor de contraseñas)."
echo "Pulsa Intro para cerrar."; read
