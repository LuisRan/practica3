#!/usr/bin/env bash
# Genera las carpetas de plataforma (android/ e ios/) con `flutter create` y aplica
# la configuración que necesita la app: permisos, minSdk e Info.plist.
# Es idempotente: se puede ejecutar varias veces.
#
# Uso (desde la carpeta camara_mic_flutter):
#   ./tool/setup_platforms.sh            # solo configura
#   ./tool/setup_platforms.sh --build    # configura y compila APK (+ iOS sin firma en macOS)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter create (solo genera lo que falta; no toca lib/)"
flutter create --org mx.ipn.escom --project-name camara_mic_flutter --platforms=android,ios . >/dev/null
# La plantilla agrega un test de ejemplo que referencia MyApp; no aplica a este proyecto.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then rm -f test/widget_test.dart; fi

echo "==> Configurando Android"
MANIFEST=android/app/src/main/AndroidManifest.xml
python3 - "$MANIFEST" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
perms = """    <!-- Práctica 3: permisos de cámara y micrófono -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.microphone" android:required="false" />
"""
if "android.permission.CAMERA" not in s:
    s = re.sub(r"(<manifest[^>]*>)", r"\1\n" + perms, s, count=1)
s = s.replace('android:label="camara_mic_flutter"', 'android:label="Cámara y Mic"')
open(p, "w", encoding="utf-8").write(s)
PY

for GRADLE in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$GRADLE" ]; then
    # record/camera requieren API 24+
    sed -i.bak -E 's/minSdk( = |Version )flutter\.minSdkVersion/minSdk\1 24/' "$GRADLE" && rm -f "$GRADLE.bak"
  fi
done

echo "==> Configurando iOS (Info.plist)"
PLIST=ios/Runner/Info.plist
python3 - "$PLIST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
keys = {
    "NSCameraUsageDescription": "La cámara se usa para tomar fotos que se guardan en la galería de la app.",
    "NSMicrophoneUsageDescription": "El micrófono se usa para grabar notas de audio en el dispositivo.",
    "NSPhotoLibraryUsageDescription": "Permite importar fotos desde tu fototeca.",
}
add = ""
for k, v in keys.items():
    if k not in s:
        add += f"\t<key>{k}</key>\n\t<string>{v}</string>\n"
if "UIFileSharingEnabled" not in s:
    add += "\t<key>UIFileSharingEnabled</key>\n\t<true/>\n\t<key>LSSupportsOpeningDocumentsInPlace</key>\n\t<true/>\n"
if add:
    idx = s.rfind("</dict>")
    s = s[:idx] + add + s[idx:]
s = s.replace("<string>Camara Mic Flutter</string>", "<string>Cámara y Mic</string>")
open(p, "w", encoding="utf-8").write(s)
PY

echo "==> flutter pub get"
flutter pub get

if [ "${1:-}" = "--build" ]; then
  echo "==> Compilando APK (release)"
  flutter build apk --release
  mkdir -p ../binarios
  cp build/app/outputs/flutter-apk/app-release.apk ../binarios/CamaraMicFlutter.apk
  if [ "$(uname)" = "Darwin" ]; then
    echo "==> Compilando iOS para simulador"
    flutter build ios --simulator --debug
    echo "    App para simulador: build/ios/iphonesimulator/Runner.app"
    echo "    (Para IPA firmada: flutter build ipa, requiere equipo de desarrollo de Apple)"
  fi
fi
echo "Listo."
