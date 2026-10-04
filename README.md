# Magic TV en el escritorio Ubuntu

Android (redroid, sin emulación) corre en un contenedor compartido. **Cualquier usuario** del equipo abre Magic TV como un programa normal (icono del menú o comando `magictv`): se abre una ventana en su propio escritorio (Wayland o X11), con sonido por PipeWire/PulseAudio. Hasta 1080p a 60 fps, sin navegador ni VNC.

```
stack Portainer "magictv"                                  sesión de cada usuario
┌──────────────────────────────┐                          ┌────────────────────────┐
│ android   (redroid 12)       │◀── adb/H.264+Opus ──────│ magictv-window-<uid>   │──▶ ventana + audio
│ installer (instala las APKs) │                          │ (scrcpy, se abre con   │
└──────────────────────────────┘                          │  el icono o `magictv`) │
                                                          └────────────────────────┘
```

Todos los usuarios ven **el mismo Android** (misma app, mismo login). Si dos usuarios lo abren a la vez, ven y controlan la misma pantalla.

## Primera ejecución (resumen)

Haz estos pasos en orden; el detalle de cada uno está en [Primer setup paso a paso](#primer-setup-paso-a-paso).

**A. En tu PC (una vez)** — publicar el código y la imagen:
```bash
git add . && git commit -m "Magic TV container" && git push -u origin main
```
Espera a que GitHub → **Actions** → *Build viewer image* termine en ✅ y pon el paquete `androidtv-viewer` como **Public**.

**B. En el Ubuntu, como administrador (una vez):**
```bash
# 1. Preparar el host: kernel, carpeta de APKs, comando e icono para todos los usuarios
curl -fsSL https://raw.githubusercontent.com/belta1/androidtv/main/host-setup.sh | sudo bash

# 2. Dejar la APK
cp ~/Descargas/MagicTV.apk /home/belta1/docker_compose/config/magictv/
```

**C. En Portainer (una vez):** Stacks → Add stack → Repository →
URL `https://github.com/belta1/androidtv`, ref `refs/heads/main`, path `docker-compose.yml` → **Deploy the stack**.

**D. Esperar a que Android arranque e instale la APK (1–2 min):**
```bash
docker logs -f magictv-installer     # espera a ver "Success", luego Ctrl+C
```

**E. Abrir Magic TV (cualquier usuario, siempre):** menú de aplicaciones → **Magic TV**, o en una terminal:
```bash
magictv
```
La primera vez, inicia sesión dentro de la app; queda guardado para todos.

A partir de aquí no hay que repetir nada: tras reiniciar el equipo, Docker vuelve a levantar Android solo, y cada usuario solo tiene que hacer el paso **E**.

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

```bash
echo $XDG_SESSION_TYPE      # wayland (recomendado) o x11
ls /dev/dri                 # debe listar card0 y renderD128 (GPU)
docker ps                   # Docker funcionando
```

Si sale `x11`, mira la sección [Sesión X11](#sesión-x11-no-wayland).

### Paso 3 — Preparar el host (una vez, como administrador)

```bash
curl -fsSL https://raw.githubusercontent.com/belta1/androidtv/main/host-setup.sh | sudo bash
```

Esto:
- activa el módulo `binder` del kernel (Android lo necesita; queda activo tras reiniciar),
- crea la carpeta de APKs `/home/belta1/docker_compose/config/magictv`,
- instala para **todos los usuarios** el comando `magictv` y el icono **Magic TV** en el menú de aplicaciones,
- crea `/etc/magictv.conf` (ajustes de la ventana) y una regla `sudoers` que permite a cualquier usuario abrir Magic TV **sin** darle acceso a Docker.

Compruébalo con `grep binder /proc/filesystems` (debe mostrar `binder`).

### Paso 4 — Dejar la APK

La APK va en el **host Ubuntu**, en `/home/belta1/docker_compose/config/magictv/` (no dentro de ningún contenedor; se monta solo):

```bash
cp ~/Descargas/MagicTV.apk /home/belta1/docker_compose/config/magictv/
chmod 644 /home/belta1/docker_compose/config/magictv/*.apk
```

- El nombre da igual, pero debe terminar en `.apk` (no `.xapk` ni `.zip`).
- Se instala sola. Para **actualizarla**, reemplaza el archivo: se reinstala en ≤ 1 min.

### Paso 5 — Crear el stack en Portainer

Portainer → **Stacks** → **Add stack**:

| Campo | Valor |
|---|---|
| Name | `magictv` |
| Build method | **Repository** |
| Repository URL | `https://github.com/belta1/androidtv` |
| Repository reference | `refs/heads/main` |
| Compose path | `docker-compose.yml` |

Opcional: `GPU_MODE=host` si tienes GPU Intel/AMD (requiere descomentar `/dev/dri` en el servicio `android`).

Pulsa **Deploy the stack**. Portainer descarga `redroid/redroid` (~1 GB) y `ghcr.io/belta1/androidtv-viewer` (~130 MB).

### Paso 6 — Primer arranque

1. El primer arranque de Android tarda **1–2 min**. Sigue la instalación de la APK:
   ```bash
   docker logs -f magictv-installer
   ```
   ```
   [magictv] connected to android:5555 (arm64-v8a,armeabi-v7a,...,x86_64,...)
   [magictv] installing MagicTV.apk ...
   Success
   ```
2. Con cualquier usuario: abre **Magic TV** desde el menú de aplicaciones (o ejecuta `magictv` en una terminal).
3. Se abre una **ventana** de 1280×720 (redimensionable) con sonido. Inicia sesión en la app una vez: queda guardado para todos (volumen `android-data`).

### Paso 7 — Si algo falla

Ejecuta `magictv` en una terminal para ver el error:

| Mensaje | Solución |
|---|---|
| `Android not ready after 180s` | `docker logs magictv-android`; casi siempre falta `binder` → repetir paso 3 y reiniciar. O el stack no está desplegado |
| `network magictv not found` / `No such image` | El stack de Portainer no está desplegado (paso 5) |
| `sudo: a password is required` | Falta `/etc/sudoers.d/magictv` → repetir paso 3 |
| `no desktop session found` | Sesión X11 sin `xhost` (ver abajo) |
| `no PulseAudio/PipeWire socket` | Sin audio en esa sesión; revisa el sonido del escritorio |
| `INSTALL_FAILED_NO_MATCHING_ABIS` (installer) | APK incompatible; consigue la versión `arm64-v8a`/universal |

## Uso

- **Abrir:** icono **Magic TV** (se puede anclar al dock: clic derecho → *Añadir a favoritos*) o `magictv`.
- **Cerrar:** cierra la ventana. Android sigue encendido en segundo plano, así que reabrir es instantáneo.
- **Abrir al iniciar sesión** (todos los usuarios): `sudo cp /usr/share/applications/magictv.desktop /etc/xdg/autostart/`
- **Apagar del todo:** detén el stack en Portainer.

Controles: ratón = toque, clic derecho = **Atrás**, clic central = **Inicio**, teclado normal, `Alt+F` = pantalla completa.

## Configuración

**Ventana** — `/etc/magictv.conf` (como root; aplica a todos los usuarios en la siguiente apertura):

| Variable | Defecto | Descripción |
|---|---|---|
| `FULLSCREEN` | `false` | `true` para abrir a pantalla completa |
| `WINDOW_WIDTH` / `WINDOW_HEIGHT` | `1280` / `720` | Tamaño inicial |
| `MAX_SIZE` | `1920` | Lado máximo del vídeo |
| `FPS` | `60` | Tope de fps |
| `VIDEO_BITRATE` | `8M` | Bitrate H.264 |
| `AUDIO_CODEC` | `aac` | `aac` o `flac` (redroid no tiene Opus) |
| `APP_PACKAGE` | autodetectado | Paquete a abrir (si hay varios APKs) |

**Android** — variables del stack en Portainer:

| Variable | Defecto | Descripción |
|---|---|---|
| `APK_DIR` | `/home/belta1/docker_compose/config/magictv` | Carpeta del host con los `.apk` |
| `WIDTH` / `HEIGHT` / `DPI` | `1920` / `1080` / `240` | Pantalla de Android |
| `FPS` | `60` | Fps de Android |
| `GPU_MODE` | `guest` | **Recomendado `host`** con iGPU Intel/AMD (descomentar `/dev/dri` en `android`). Reduce mucho la CPU. No funciona con NVIDIA |
| `ANDROID_MEM` | `2g` | Límite de RAM de Android |

### Sesión X11 (no Wayland)

Ubuntu usa Wayland por defecto. Si un usuario usa X11 (p. ej. con NVIDIA), debe autorizar su propia sesión una vez por login, por ejemplo en *Aplicaciones al inicio*:

```bash
xhost +SI:localuser:$(id -un)
```

## Seguridad

Los usuarios **no** se añaden al grupo `docker` (equivale a root). La regla `sudoers` solo permite ejecutar `/usr/local/lib/magictv/run` sin argumentos. Ese script lanza el contenedor de la ventana con el uid del usuario y monta únicamente su propia sesión (`/run/user/<uid>`).

## Diagnóstico

```bash
docker logs -f magictv-installer
docker exec magictv-installer adb -s android:5555 shell getprop ro.product.cpu.abilist   # debe incluir arm64-v8a
docker ps --filter name=magictv-window   # ventanas abiertas (una por usuario)
```
