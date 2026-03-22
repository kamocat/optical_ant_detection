#!/usr/bin/env sh
# Installs antcam and the appropriate init/cron integration.
#
# Usage: sudo ./install.sh
#
# What it does:
#   1. Copies the compiled binary to /usr/local/bin/count_ants
#   2. Copies antcam, capture, and notify scripts to /app/
#   3. Copies config/ to /app/config/
#   4. Installs systemd units (if systemd present) or OpenRC + crond
#      crontab (if OpenRC present)
#
# Environment variables:
#   APP_DIR      Installation directory for scripts (default: /app)
#   BIN_DIR      Installation directory for binary  (default: /usr/local/bin)
#   BINARY       Path to already-compiled count_ants binary
#                (default: ./build/count_ants)

set -e

APP_DIR="${APP_DIR:-/app}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
BINARY="${BINARY:-./build/count_ants}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run as root (sudo ./install.sh)" >&2
    exit 1
fi

if [ ! -x "$BINARY" ]; then
    echo "Error: binary not found at $BINARY — build first:" >&2
    echo "  cmake -B build && cmake --build build -j\$(nproc)" >&2
    exit 1
fi

# ── Install binary and scripts ────────────────────────────────────────────────
echo "Installing binary → $BIN_DIR/count_ants"
install -m755 "$BINARY" "$BIN_DIR/count_ants"

echo "Installing scripts → $APP_DIR/"
install -d "$APP_DIR"
install -m755 "$SCRIPT_DIR/src/antcam"  "$APP_DIR/antcam"
install -m755 "$SCRIPT_DIR/src/capture" "$APP_DIR/capture"
install -m755 "$SCRIPT_DIR/src/notify"  "$APP_DIR/notify"

echo "Installing config → $APP_DIR/config/"
install -d "$APP_DIR/config"
install -m644 "$SCRIPT_DIR/config/config.yaml" "$APP_DIR/config/config.yaml"

# ── Init system detection ─────────────────────────────────────────────────────
if [ -d /run/systemd/system ]; then
    echo "Detected systemd — installing units"
    install -m644 "$SCRIPT_DIR/integrations/systemd/antcam.service" \
        /etc/systemd/system/antcam.service
    install -m644 "$SCRIPT_DIR/integrations/systemd/antcam.timer" \
        /etc/systemd/system/antcam.timer
    systemctl daemon-reload
    systemctl enable --now antcam.timer
    echo "Timer enabled: $(systemctl status antcam.timer --no-pager -l 2>&1 | head -3)"

elif command -v rc-update > /dev/null 2>&1; then
    echo "Detected OpenRC — installing init script and crontab"
    install -m755 "$SCRIPT_DIR/integrations/openrc/antcam" /etc/init.d/antcam
    install -m644 "$SCRIPT_DIR/integrations/openrc/antcam.cron" /etc/cron.d/antcam
    rc-update add crond default 2>/dev/null || true
    rc-service crond start 2>/dev/null || true
    echo "Crontab installed at /etc/cron.d/antcam"

else
    echo "Warning: could not detect systemd or OpenRC." >&2
    echo "  Manually install the appropriate files from integrations/." >&2
fi

# ── Credentials reminder ──────────────────────────────────────────────────────
echo ""
echo "Installation complete."
echo "Set up credentials before first run:"
echo "  cp integrations/homeassistant/mqtt.env.example /etc/antcam/mqtt.env"
echo "  cp integrations/ntfy/ntfy.env.example          /etc/antcam/ntfy.env"
echo "  \$EDITOR /etc/antcam/mqtt.env"
echo "  \$EDITOR /etc/antcam/ntfy.env"
