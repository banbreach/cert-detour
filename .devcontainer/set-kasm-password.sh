#!/usr/bin/env bash
set -euo pipefail

# Codespaces secrets are available to lifecycle scripts after the Codespace
# is running. They are not available to the image ENTRYPOINT at container
# creation time. This hook therefore updates KasmVNC's password file after
# Kasm has initialized.
: "${KASM_VNC_PASSWORD:?Missing Codespaces secret KASM_VNC_PASSWORD}"

if [[ "$KASM_VNC_PASSWORD" == *$'\n'* || "$KASM_VNC_PASSWORD" == *$'\r'* ]]; then
  echo "KASM_VNC_PASSWORD must not contain newline characters." >&2
  exit 1
fi

password_length=${#KASM_VNC_PASSWORD}
if (( password_length < 12 || password_length > 128 )); then
  echo "KASM_VNC_PASSWORD must be between 12 and 128 characters." >&2
  exit 1
fi

if ! command -v kasmvncpasswd >/dev/null 2>&1; then
  echo "kasmvncpasswd was not found; the Kasm image may not have initialized correctly." >&2
  exit 1
fi

# The image runs as the Kasm desktop user (UID 1000). KasmVNC stores its
# Basic-Auth credentials in ~/.kasmpasswd. The password is read from stdin
# and is never printed to the terminal or written into repository files.
umask 077
printf '%s\n%s\n' "$KASM_VNC_PASSWORD" "$KASM_VNC_PASSWORD" \
  | kasmvncpasswd -u kasm_user -wo

chmod 600 "$HOME/.kasmpasswd"
unset KASM_VNC_PASSWORD

echo "KasmVNC password configured from the Codespaces secret."
