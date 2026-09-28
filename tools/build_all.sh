#!/usr/bin/env bash
# Compila todas las apps de la práctica y copia los resultados a binarios/.
# Requiere macOS con Xcode (+ simulador de iOS), Flutter y Android SDK/JDK 17.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/binarios"
mkdir -p "$OUT"
SIM="${SIM:-iPhone 16}"   # cambia con: SIM="iPhone 15" ./tools/build_all.sh

ios_build () {  # $1 = .xcodeproj  $2 = esquema
  local proj="$1" scheme="$2"
  echo "==> iOS: $scheme"
  xcodebuild -project "$proj" -scheme "$scheme" -configuration Debug \
    -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$ROOT/build/$scheme" CODE_SIGNING_ALLOWED=NO build | tail -n 3
  local app
  app=$(find "$ROOT/build/$scheme/Build/Products" -maxdepth 2 -name "*.app" | head -n 1)
  if [ -n "$app" ]; then
    (cd "$(dirname "$app")" && zip -qry "$OUT/${scheme}-simulador.app.zip" "$(basename "$app")")
    echo "    -> binarios/${scheme}-simulador.app.zip"
  fi
}

ios_build "$ROOT/Ejercicio1-EntornoMacOS/HolaESCOM/HolaESCOM.xcodeproj" HolaESCOM
ios_build "$ROOT/Ejercicio2-GestorArchivos/GestorArchivos/GestorArchivos.xcodeproj" GestorArchivos
ios_build "$ROOT/Ejercicio3-CamaraMicrofono/CamaraMic/CamaraMic.xcodeproj" CamaraMic

echo "==> Flutter (Ejercicio 4)"
if command -v flutter >/dev/null; then
  (cd "$ROOT/Ejercicio4-Flutter/camara_mic_flutter" && ./tool/setup_platforms.sh --build)
else
  echo "    flutter no está instalado; se omite."
fi

echo "==> Kotlin Multiplatform (Ejercicio 5)"
(cd "$ROOT/Ejercicio5-KotlinMultiplatform/GestorArchivosKMP" && ./gradlew :composeApp:assembleRelease \
  && cp composeApp/build/outputs/apk/release/composeApp-release.apk "$OUT/GestorArchivosKMP.apk")
ios_build "$ROOT/Ejercicio5-KotlinMultiplatform/GestorArchivosKMP/iosApp/iosApp.xcodeproj" iosApp

echo "Listo. Binarios en: $OUT"
ls -la "$OUT"
