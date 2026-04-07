FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    WINEARCH=win64 \
    WINEPREFIX=/root/.wine \
    WINEDLLOVERRIDES="mscoree,mshtml="

# --- Base deps ---
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget gnupg2 ca-certificates && \
    mkdir -p /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/winehq.key https://dl.winehq.org/wine-builds/winehq.key && \
    echo "deb [signed-by=/etc/apt/keyrings/winehq.key] https://dl.winehq.org/wine-builds/ubuntu/ noble main" \
        > /etc/apt/sources.list.d/winehq.list && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    apt-get install -y --no-install-recommends \
        xvfb \
        fluxbox \
        x11vnc \
        novnc \
        websockify \
        supervisor \
        winbind \
        winetricks \
        cabextract \
        libusb-1.0-0 \
        libusb-1.0-0:i386 \
        usbutils \
    && rm -rf /var/lib/apt/lists/*

# --- Copy Hantek software and scripts ---
COPY Hantek-6000_Ver2.2.7_D20220325/ /hantek/installer/
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/install.sh /hantek/install.sh
COPY docker/start.sh /hantek/start.sh
COPY docker/bind-hantek-usb.sh /hantek/bind-hantek-usb.sh
COPY docker/start-scope.sh /hantek/start-scope.sh
RUN chmod +x /hantek/install.sh /hantek/start.sh /hantek/bind-hantek-usb.sh /hantek/start-scope.sh

# --- Bootstrap Wine prefix and install Hantek software ---
RUN bash /hantek/install.sh

EXPOSE 6080

CMD ["/hantek/start.sh"]
