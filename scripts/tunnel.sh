#!/usr/bin/env bash
#
# tunnel.sh — open an SSH tunnel from your laptop to the instance's Jupyter server.
#
# The security group does NOT expose the Jupyter port to the internet. Instead you
# forward it over the encrypted SSH connection: localhost:8888 on your machine maps to
# localhost:8888 on the instance. Then open http://localhost:8888 in your browser.
#
# Usage (on your laptop):
#   ./tunnel.sh <instance-public-ip> [path-to-key.pem] [remote-user] [port]
#
# Examples:
#   ./tunnel.sh 203.0.113.10 ai-infra-key.pem
#   ./tunnel.sh 203.0.113.10 ~/.ssh/ai-infra-key.pem ubuntu 8888
#
# Tip: `terraform output jupyter_tunnel_command` prints a ready-to-paste version.
#
set -euo pipefail

IP="${1:-}"
KEY="${2:-ai-infra-key.pem}"
USER_NAME="${3:-ubuntu}"
PORT="${4:-8888}"

if [ -z "${IP}" ]; then
  echo "Usage: $0 <instance-public-ip> [key.pem] [user] [port]" >&2
  exit 1
fi

echo "Forwarding localhost:${PORT} -> ${USER_NAME}@${IP}:${PORT}"
echo "Once connected, on the instance run:  jupyter notebook --no-browser --port=${PORT}"
echo "Then open the printed http://localhost:${PORT}/?token=... URL in your browser."
echo

exec ssh -i "${KEY}" -N -L "${PORT}:localhost:${PORT}" "${USER_NAME}@${IP}"
