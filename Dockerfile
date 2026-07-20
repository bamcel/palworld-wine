FROM archlinux:multilib-devel

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TINI_VERSION=0.19.0
ARG GOSU_VERSION=1.17
ARG SUPERCRONIC_VERSION=0.2.45

RUN pacman --noconfirm -Syu \
    && pacman --noconfirm -S --needed \
        bash \
        ca-certificates \
        cabextract \
        coreutils \
        curl \
        findutils \
        gnupg \
        grep \
        gzip \
        lib32-gnutls \
        lib32-libxcomposite \
        libxcomposite \
        procps-ng \
        sed \
        shadow \
        tar \
        unzip \
        wine \
        wine-gecko \
        wine-mono \
        winetricks \
        xorg-server-xvfb \
    && pacman --noconfirm -Scc \
    && rm -rf /var/cache/pacman/pkg/*

RUN curl -fsSL "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-amd64" -o /usr/local/bin/tini \
    && chmod +x /usr/local/bin/tini \
    && curl -fsSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" -o /usr/local/bin/gosu \
    && chmod +x /usr/local/bin/gosu \
    && curl -fsSL "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" -o /usr/local/bin/supercronic \
    && chmod +x /usr/local/bin/supercronic

ENV PUID=99 \
    PGID=100 \
    TZ=UTC \
    WINEPREFIX=/palworld/.wine \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    LIBGL_ALWAYS_SOFTWARE=1 \
    XDG_CACHE_HOME=/palworld/.cache \
    XDG_RUNTIME_DIR=/tmp/xdg-runtime \
    DISPLAY=:99 \
    STEAM_APP_ID=2394010 \
    SERVER_DIR=/palworld/server \
    PAL_EXE= \
    STEAMCMD_DIR=/steamcmd \
    BACKUP_DIR=/backups \
    UPDATE_ON_BOOT=true \
    VALIDATE_ON_UPDATE=true \
    WINETRICKS_ON_BOOT=true \
    FORCE_WINETRICKS=false \
    BACKUP_ENABLED=true \
    BACKUP_CRON="0 */6 * * *" \
    DELETE_OLD_BACKUPS=false \
    OLD_BACKUP_DAYS=30 \
    MULTITHREADING=true \
    COMMUNITY=false \
    PORT=8211 \
    QUERY_PORT=27015 \
    XVFB_LOG_STDOUT=false \
    EXTRA_ARGS=""

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen
ENV LANG=en_US.UTF-8

COPY rootfs/ /

RUN chmod +x \
        /usr/local/bin/docker-entrypoint.sh \
        /usr/local/bin/start-palworld.sh \
        /usr/local/bin/backup-palworld.sh \
        /usr/local/bin/healthcheck-palworld.sh \
    && mkdir -p /palworld /steamcmd /backups

EXPOSE 8211/udp 27015/udp 25575/tcp
VOLUME ["/palworld", "/steamcmd", "/backups"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=20m --retries=3 CMD ["/usr/local/bin/healthcheck-palworld.sh"]
ENTRYPOINT ["/usr/local/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
