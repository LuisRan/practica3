# Ejercicio 1 · Instalación del entorno macOS / iOS

> Las secciones marcadas con 📸 deben completarse con capturas/fotografías propias del equipo
> (se guardan en `docs/img/`). Los datos entre corchetes `[...]` se llenan con la información real.

## 1.1 Identificación del equipo

### Comparativa de especificaciones

| Integrante | Equipo | CPU | RAM | Almacenamiento libre | GPU | Virtualización (VT-x/AMD-V) | ¿Cumple requisitos MacOS-Docker? |
|---|---|---|---|---|---|---|---|
| Luis [Apellidos] | **MacBook Air (Mac física)** | Apple Silicon [M1/M2/M3] | [8/16] GB | [..] GB | Integrada Apple | N/A (macOS nativo) | **No necesita Docker** |
| [Integrante 2] | [Laptop/PC] | [..] | [..] GB | [..] GB | [..] | [Sí/No] | [Sí/No] |
| [Integrante 3] | [Laptop/PC] | [..] | [..] GB | [..] GB | [..] | [Sí/No] | [Sí/No] |

Requisitos sugeridos por `gabrielhuav/MacOS-Docker`: **16 GB de RAM**, **20 GB libres (50 GB con Xcode)** y procesador con virtualización; Docker (en Windows: Docker Desktop + WSL + Ubuntu).

### Justificación de la elección

Un integrante cuenta con una **Mac física (MacBook Air)**. La práctica permite trabajar directamente en ella: macOS corre de forma nativa (sin la sobrecarga de QEMU/KVM), Xcode y los simuladores funcionan con aceleración de hardware y no se requiere generar números de serie ni descargar la imagen de macOS (~1 h). Por ello:

- **Integrante responsable del equipo:** [Nombre completo] — Boleta [..........]
- **Equipo:** MacBook Air, procesador [Apple M_], [__] GB RAM, macOS [versión, p. ej. 26 “Tahoe”], Xcode [versión].
- 📸 Foto del equipo y captura de *Acerca de esta Mac* → `docs/img/ej1_acerca_de_mac.png`.

## 1.2 Trabajo en equipo

La bitácora de sesiones está en [`Bitacora.md`](Bitacora.md). Todos los integrantes trabajaron sobre la Mac (presencial o por pantalla compartida) y el historial de commits refleja la participación de cada uno.

## 1.3 Instalación de macOS con Docker (ruta alternativa, no requerida al tener Mac física)

Se documenta para los integrantes/equipos sin Mac, siguiendo el README de `github.com/gabrielhuav/MacOS-Docker`:

1. **Requisitos:** 16 GB RAM, 20–50 GB libres, CPU con virtualización habilitada en BIOS.
2. **Windows:** Docker Desktop → *Settings › Resources › WSL Integration* → activar *Enable integration with my default WSL distro*. En `C:\Users\<usuario>\.wslconfig`:
   ```ini
   [wsl2]
   nestedVirtualization=true
   ```
   Verificar KVM con `kvm-ok` (si falla: `sudo apt -y install bridge-utils cpu-checker libvirt-clients libvirt-daemon qemu qemu-kvm`) e instalar `x11-apps`.
3. **Linux:** instalar `qemu`, `libvirt`, `virt-manager`, habilitar `libvirtd`/`virtlogd`, `echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs`, `sudo modprobe kvm`.
4. **Arranque del contenedor** (recursos: `RAM=8` GB, `SMP=8`, `CORES=4`, ajustables según la PC):
   ```bash
   docker run -it --device /dev/kvm -p 50922:10022 \
     -v /tmp/.X11-unix:/tmp/.X11-unix -e "DISPLAY=${DISPLAY:-:0.0}" \
     -e GENERATE_UNIQUE=true \
     -e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom.plist' \
     -e SHORTNAME=ventura -e RAM=8 -e SMP=8 -e CORES=4 \
     sickcodes/docker-osx:latest
   ```
5. En el instalador: *macOS Base System* → *Disk Utility* → borrar el disco **QEMU** (~270 GB) como `MacOS`, formato **APFS**, esquema **GUID** → *Reinstall macOS* (≈1 h) → asistente inicial.
6. Verificar arranque y acceso a Internet dentro del contenedor (Safari/App Store).

**Configuración óptima de recursos:** asignar como máximo la mitad de los núcleos físicos y 50–60 % de la RAM del anfitrión; disco dinámico de al menos 80 GB si se instalará Xcode.

## 1.4 Configuración del entorno de desarrollo iOS (realizado en la Mac)

1. **Xcode** desde la Mac App Store (o developer.apple.com). Abrir una vez para instalar componentes adicionales y aceptar la licencia:
   ```bash
   sudo xcodebuild -license accept
   xcode-select -p                # /Applications/Xcode.app/Contents/Developer
   xcodebuild -version
   ```
2. **Simuladores:** *Xcode › Settings › Components* → descargar la plataforma **iOS**. Crear/verificar un iPhone y un iPad en *Window › Devices and Simulators › Simulators*:
   ```bash
   xcrun simctl list devices available
   ```
3. **Herramientas adicionales:**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"   # Homebrew
   brew install cocoapods          # CocoaPods (requerido por Flutter en iOS)
   swift package --version         # Swift Package Manager viene con Xcode
   brew install --cask flutter     # (Ejercicio 4)
   brew install --cask android-studio   # (Ejercicios 4 y 5)
   ```
4. **Proyecto de prueba** `Ejercicio1-EntornoMacOS/HolaESCOM`: SwiftUI que muestra el modelo/versión del dispositivo, si corre en simulador y un contador con estado y cambio de tema.
   ```bash
   open Ejercicio1-EntornoMacOS/HolaESCOM/HolaESCOM.xcodeproj   # elegir iPhone 16 → ⌘R
   ```
5. 📸 Capturas: Xcode instalado (`ej1_xcode.png`), lista de simuladores (`ej1_simuladores.png`), HolaESCOM ejecutándose en iPhone y iPad (`ej1_holaescom_iphone.png`, `ej1_holaescom_ipad.png`).

## 1.5 Entregables — lista de verificación

- [ ] Tabla comparativa de PCs llenada
- [ ] Guía paso a paso (este documento) con capturas en `docs/img/`
- [ ] Captura de macOS con Xcode instalado
- [ ] HolaESCOM corriendo en el simulador de iOS
- [ ] Bitácora de sesiones ([`Bitacora.md`](Bitacora.md))
- [ ] Responsable del equipo y justificación (sección 1.1)
- [ ] Evidencia fotográfica/capturas de las reuniones
