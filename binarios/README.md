# Binarios

Se generan con `./tools/build_all.sh` (macOS con Xcode, Flutter y Android SDK):

| Archivo | Ejercicio | Plataforma |
|---|---|---|
| `HolaESCOM-simulador.app.zip` | 1 | Simulador iOS |
| `GestorArchivos-simulador.app.zip` | 2 | Simulador iOS |
| `CamaraMic-simulador.app.zip` | 3 | Simulador iOS |
| `CamaraMicFlutter.apk` | 4 | Android |
| `GestorArchivosKMP.apk` | 5 | Android |
| `iosApp-simulador.app.zip` | 5 | Simulador iOS |
| `capturas/` | 1–5 | Capturas de pantalla de simulador/emulador |

Para instalar un `.app` en el simulador: descomprimir y ejecutar
`xcrun simctl install booted <App>.app`.

> Una IPA instalable en iPhone físico requiere firmar con un Apple ID/equipo de desarrollo
> (Xcode › Product › Archive). Por eso, como permite la práctica, se entregan builds de
> simulador y capturas.
