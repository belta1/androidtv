FROM debian:bookworm-slim

ARG SCRCPY_VERSION=4.1
ARG SCRCPY_SHA256=ad56ae8bfeedf41e824945c11dbf55fcb092b3e615b9b486f48a50e30d389635

# Runtime libs scrcpy (SDL3) loads to draw on the host's Wayland/X11 session
# with GPU acceleration and play audio through the host's PipeWire/PulseAudio.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl \
      libwayland-client0 libwayland-cursor0 libwayland-egl1 libdecor-0-0 libxkbcommon0 \
      libx11-6 libx11-xcb1 libxext6 libxrandr2 libxcursor1 libxi6 libxfixes3 libxss1 \
      libegl1 libgl1 libgles2 libgbm1 libdrm2 libgl1-mesa-dri \
      libpulse0 \
 && curl -fsSL -o /tmp/scrcpy.tgz \
      "https://github.com/Genymobile/scrcpy/releases/download/v${SCRCPY_VERSION}/scrcpy-linux-x86_64-v${SCRCPY_VERSION}.tar.gz" \
 && echo "${SCRCPY_SHA256}  /tmp/scrcpy.tgz" | sha256sum -c - \
 && mkdir -p /opt/scrcpy \
 && tar xzf /tmp/scrcpy.tgz -C /opt/scrcpy --strip-components=1 \
 && ln -s /opt/scrcpy/scrcpy /usr/local/bin/scrcpy \
 && ln -s /opt/scrcpy/adb /usr/local/bin/adb \
 && apt-get purge -y curl && apt-get autoremove -y \
 && rm -rf /tmp/scrcpy.tgz /var/lib/apt/lists/* \
 && mkdir -p /state && chmod 1777 /state

COPY root/ /
RUN chmod +x /usr/local/bin/magictv-launcher /usr/local/bin/magictv-open

ENV HOME=/state
CMD ["/usr/local/bin/magictv-launcher"]
