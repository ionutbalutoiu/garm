#!/usr/bin/env bash
set -o errexit

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run $0 script as root"
    exit 1
fi

DIR="$(dirname $0)"
BINARIES_DIR="$DIR/../../../bin"
CONTRIB_DIR="$DIR/../../../contrib"
TEMPLATES_DIR="$DIR/../templates"

if [[ ! -f $BINARIES_DIR/garm ]] || [[ ! -f $BINARIES_DIR/garm-cli ]]; then
    echo "ERROR: Please build GARM binaries first"
    exit 1
fi

if [[ -z $OAUTH_TOKEN ]]; then echo "ERROR: The env variable OAUTH_TOKEN is not set"; exit 1; fi
if [[ -z $CREDENTIALS_NAME ]]; then echo "ERROR: The env variable CREDENTIALS_NAME is not set"; exit 1; fi

function generate_secret() {
    (tr -dc 'a-zA-Z0-9!@#$%^&*()_+?><~\`;' < /dev/urandom | head -c 32) 2>/dev/null
}

function wait_open_port() {
    local ADDRESS="$1"
    local PORT="$2"
    local TIMEOUT=30
    SECONDS=0
    while true; do
        if [[ $SECONDS -gt $TIMEOUT ]]; then
            echo "ERROR: Port $PORT didn't open at $ADDRESS within $TIMEOUT seconds"
            return 1
        fi
        nc -v -w 5 -z "$ADDRESS" "$PORT" &>/dev/null && break || sleep 1
    done
    echo "Port $PORT at address $ADDRESS is open"
}

# Use the LXD bridge IP address as the GARM metadata address.
export GARM_METADATA_IP=$(lxc network ls -f json 2>/dev/null | jq -r '.[] | select(.name=="lxdbr0") | .config."ipv4.address"' | cut -d '/' -f1)

export JWT_AUTH_SECRET="$(generate_secret)"
export DB_PASSPHRASE="$(generate_secret)"

# Group "adm" is the LXD daemon group as set by the "canonical/setup-lxd" GitHub action.
useradd --shell /usr/bin/false --system --groups adm --no-create-home garm

mkdir -p /etc/garm
cat $TEMPLATES_DIR/config.toml | envsubst > /etc/garm/config.toml
chown -R garm:garm /etc/garm

mv $BINARIES_DIR/* /usr/local/bin/
cp $CONTRIB_DIR/garm.service /etc/systemd/system/garm.service

systemctl daemon-reload
systemctl start garm

wait_open_port 127.0.0.1 9997

echo "GARM is up and running"
