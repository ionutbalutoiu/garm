#!/usr/bin/env bash
set -o errexit

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run $0 script as root"
    exit 1
fi

DIR="$(dirname $0)"
TEMPLATES_DIR="$DIR/../templates"

if [[ -z $NGROK_AUTH_TOKEN ]]; then echo "ERROR: The env variable NGROK_AUTH_TOKEN is not set"; exit 1; fi
if [[ -z $NGROK_DOMAIN ]]; then echo "ERROR: The env variable NGROK_DOMAIN is not set"; exit 1; fi

snap install ngrok

cat $TEMPLATES_DIR/ngrok-tunnel.service | envsubst > /etc/systemd/system/ngrok-tunnel.service

systemctl daemon-reload
systemctl start ngrok-tunnel

TIMEOUT=${TIMEOUT:-60}
SECONDS=0
while true; do
    if [[ $SECONDS -gt $TIMEOUT ]]; then
        echo "ERROR: Timeout waiting GARM ngrok tunnel to be started"
        exit 1
    fi
    # ping webhooks endpoint to check if ngrok tunnel is ready
    curl -sS --fail https://${NGROK_DOMAIN}/webhooks || {
        echo "Garm ngrok tunnel not started yet, waiting..."
        sleep 5
        continue
    }
    break
done

echo "GARM ngrok tunnel started"
