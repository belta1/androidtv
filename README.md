# Magic TV en la pantalla del host

Android (redroid, sin emulación) en contenedor + scrcpy dibujando directamente en el escritorio Ubuntu del mismo equipo (Wayland o X11), con audio por PipeWire/PulseAudio. Hasta 1080p a 60 fps. Sin navegador ni VNC: una sola codificación H.264 → decodificación.

```
android (redroid 12) ──adb/H.264+Opus──▶ viewer (scrcpy) ──socket Wayland/X11 + Pulse──▶ escritorio Ubuntu
```

## Primer setup paso a paso

### Paso 1 — Publicar la imagen en GitHub (una vez, desde tu PC)

1. Sube este repo a GitHub:
   ```bash
   git add . && git commit -m "Magic TV container" && git push -u origin main
   ```
2. En GitHub → pestaña **Actions**, espera a que termine **Build viewer image** (✅, ~3 min).
3. En GitHub → tu perfil → **Packages** → `androidtv-viewer` → *Package settings* → **Change visibility → Public**.
   (Si prefieres dejarla privada: Portainer → *Registries* → añade `ghcr.io` con tu usuario y un token con permiso `read:packages`.)

> Si el repo es **privado**, en el paso 5 activa *Authentication* en Portainer con un token de GitHub, y en el paso 3 usa `git clone` con ese token en lugar de `curl`.

### Paso 2 — Comprobar el host Ubuntu

En el Ubuntu donde corre Portainer (y donde se verá la imagen):

```bash
echo $XDG_SESSION_TYPE      # wayland (recomendado) o x11
ls /dev/dri                 # debe listar card0 y renderD128 (GPU)
docker ps                   # Docker funcionando
```

Si sale `x11`, mira la sección [Sesión X11](#sesión-x11-no-wayland).

### Paso 3 — Preparar el kernel (una vez)

```bash
curl -fsSL https://raw.githubusercontent.com/belta1/androidtv/main/host-setup.sh | sudo bash
```

Esto activa el módulo `binder` (Android lo necesita, y queda activo tras reiniciar) y crea la carpeta `/home/belta1/docker_compose/config/magictv`.
**Apunta los valores** que imprime al final, por ejemplo:

```
HOST_UID=1000  HOST_GID=1000  RENDER_GID=993
```

Compruébalo con `grep binder /proc/filesystems` (debe mostrar `binder`).

### Paso 4 — Dejar la APK

La APK va en el **host Ubuntu**, en `/home/belta1/docker_compose/config/magictv/` (no dentro de ningún contenedor; se monta solo). La carpeta es de tu usuario, no hace falta `sudo`:

```bash
cp ~/Descargas/MagicTV.apk /home/belta1/docker_compose/config/magictv/
chmod 644 /home/belta1/docker_compose/config/magictv/*.apk
ls -l /home/belta1/docker_compose/config/magictv
```

- El nombre del archivo da igual, pero debe terminar en `.apk` (no `.xapk` ni `.zip`).
- Se instala sola al arrancar el contenedor. Para **actualizarla**, reemplaza el archivo y reinicia `magictv-viewer`.
- ¿Otra carpeta? Cambia la variable `APK_DIR` en el paso 5.

### Paso 5 — Crear el stack en Portainer

Portainer → **Stacks** → **Add stack**:

| Campo | Valor |
|---|---|
| Name | `magictv` |
| Build method | **Repository** |
| Repository URL | `https://github.com/belta1/androidtv` |
| Repository reference | `refs/heads/main` |
| Compose path | `docker-compose.yml` |
| Environment variables | `HOST_UID`, `HOST_GID`, `RENDER_GID` con los valores del paso 3 |

Opcional: `GPU_MODE=host` si tienes GPU Intel/AMD (ver tabla de variables; requiere descomentar `/dev/dri` en el servicio `android`).

Pulsa **Deploy the stack**. Portainer descarga `redroid/redroid` (~1 GB) y `ghcr.io/belta1/androidtv-viewer` (~130 MB).

### Paso 6 — Primer arranque

1. Inicia sesión en el escritorio de Ubuntu con el usuario de `HOST_UID`.
2. El primer arranque de Android tarda **1–2 min**. Sigue el progreso:
   ```bash
   docker logs -f magictv-viewer
   ```
   Secuencia esperada:
   ```
   [magictv] connected to android:5555 (arm64-v8a,armeabi-v7a,...,x86_64,...)
   [magictv] installing MagicTV.apk ...
   Success
   [magictv] display: wayland
   [magictv] starting com.xxx.magictv
   ```
3. Magic TV aparece a pantalla completa con sonido. Inicia sesión en la app una vez: queda guardado en el volumen `android-data`.

### Paso 7 — Si algo falla

| Síntoma en el log | Solución |
|---|---|
| `waiting for android:5555` sin fin | `docker logs magictv-android`; casi siempre falta `binder` → repetir paso 3 y reiniciar |
| `waiting for desktop session` | No hay sesión iniciada con ese `HOST_UID`, o es X11 sin `xhost` |
| `no PulseAudio/PipeWire socket` | `HOST_UID` no coincide con el usuario logueado |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | La APK no es compatible; consigue la versión `arm64-v8a`/universal |
| Pantalla negra o error de GL | `RENDER_GID` incorrecto (`getent group render`) |

## Variables

| Variable | Defecto | Descripción |
|---|---|---|
| `HOST_UID` / `HOST_GID` | `1000` | Usuario del escritorio (dueño de los sockets de pantalla y audio) |
| `RENDER_GID` | `993` | `getent group render` — acceso a la GPU para dibujar |
| `APK_DIR` | `/home/belta1/docker_compose/config/magictv` | Carpeta del host con los `.apk` (se instalan/actualizan al arrancar) |
| `WIDTH` / `HEIGHT` / `DPI` | `1920` / `1080` / `240` | Pantalla de Android |
| `FPS` | `60` | Tope de fps |
| `MAX_SIZE` | `1920` | Lado máximo del vídeo |
| `VIDEO_BITRATE` | `8M` | Bitrate H.264 (en local se puede subir sin coste de red) |
| `GPU_MODE` | `guest` | **Recomendado `host`** con iGPU Intel/AMD: descomentar `/dev/dri` en el servicio `android`. Reduce mucho la CPU a 1080p60. No funciona con NVIDIA. |
| `WAYLAND_DISPLAY` / `DISPLAY` | `wayland-0` / `:0` | Se usa Wayland si existe el socket, si no X11 |
| `APP_PACKAGE` | autodetectado | Paquete a abrir (si hay varios APKs) |

### Sesión X11 (no Wayland)

Ubuntu usa Wayland por defecto. Si el escritorio es X11 (p. ej. con NVIDIA), autoriza al contenedor una vez por sesión, por ejemplo en *Aplicaciones al inicio*:

```bash
xhost +SI:localuser:$(id -un)
```

## Controles

Ratón = toque, clic derecho = **Atrás**, clic central = **Inicio**, teclado normal. `Alt+F` sale/entra de pantalla completa. Si se cierra la ventana, vuelve a abrirse en 3 s (`docker stop magictv-viewer` para cerrarla del todo).

## Diagnóstico

```bash
docker logs -f magictv-viewer
docker exec magictv-viewer adb -s android:5555 shell getprop ro.product.cpu.abilist   # debe incluir arm64-v8a
```
