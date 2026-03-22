#!/bin/sh
# Publishes the MQTT discovery payload so Home Assistant auto-discovers the
# ant sensor.  Run once after changing discovery.json or when onboarding a
# new HA instance.
#
# Requires mqtt.env in the same directory as this script.
# Copy mqtt.env.example to mqtt.env and fill in your broker credentials.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ENV_FILE="${SCRIPT_DIR}/mqtt.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=mqtt.env.example
    . "$ENV_FILE"
else
    echo "Error: $ENV_FILE not found. Copy mqtt.env.example to mqtt.env and fill in your values." >&2
    exit 1
fi

# HA MQTT device-discovery topic (cmps / multi-component format, HA >= 2024.2)
# Format: homeassistant/device/<device_id>/config
DEVICE_ID="my_ant_sensor_1"
TOPIC="homeassistant/device/${DEVICE_ID}/config"

mosquitto_pub \
    -h "$MQTT_HOST" \
    -p "$MQTT_PORT" \
    -u "$MQTT_USER" \
    -P "$MQTT_PASS" \
    -t "$TOPIC" \
    -f "${SCRIPT_DIR}/discovery.json" \
    -q 1 \
    --retain