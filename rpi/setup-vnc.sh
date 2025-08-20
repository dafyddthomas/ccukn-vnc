#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo bash setup-vnc.sh [VNC_PASSWORD]
VNC_PASS="${1:-ccp2003!}"

# Sanity checks for RealVNC limits (6–8 chars)
LEN=${#VNC_PASS}
if (( LEN < 6 || LEN > 8 )); then
  echo "ERROR: RealVNC VNC passwords must be 6–8 characters. You provided ${LEN}." >&2
  exit 1
fi

echo "==> Checking for RealVNC Server (realvnc-vnc-server)…"
if ! dpkg -s realvnc-vnc-server >/dev/null 2>&1; then
  echo "==> Installing RealVNC Server…"
  apt-get update -y
  apt-get install -y realvnc-vnc-server
else
  echo "==> RealVNC Server already installed."
fi

# Ensure service is enabled
echo "==> Enabling and starting RealVNC service…"
systemctl enable vncserver-x11-serviced >/dev/null 2>&1 || true
systemctl start  vncserver-x11-serviced >/dev/null 2>&1 || true

# Force VNC password authentication (not Unix login)
# RealVNC reads config from /root/.vnc/config.d/vncserver-x11 (service mode)
echo "==> Forcing Authentication=VNC…"
install -d -m 755 /root/.vnc/config.d
# Keep custom file minimal; avoid clobbering other settings if present
CONF="/root/.vnc/config.d/vncserver-x11"
if [ -f "$CONF" ]; then
  # Update or append Authentication line
  if grep -q '^Authentication=' "$CONF"; then
    sed -i 's/^Authentication=.*/Authentication=VNC/' "$CONF"
  else
    echo "Authentication=VNC" >> "$CONF"
  fi
else
  echo "Authentication=VNC" > "$CONF"
fi

# Set the VNC password in service mode, non-interactively.
# vncpasswd prompts: Password, Verify, View-only? (y/n)
echo "==> Setting VNC password…"
# shellcheck disable=SC2016
printf '%s\n%s\nn\n' "$VNC_PASS" "$VNC_PASS" | vncpasswd -service >/dev/null

# Restart to apply everything
echo "==> Restarting RealVNC service…"
systemctl restart vncserver-x11-serviced

echo "==> Done."
echo "VNC Server is running (service mode) with password authentication."
echo "Password set to: ${VNC_PASS}"
echo
echo "Connect to: <your_pi_ip>:5900 (RealVNC Viewer/any VNC client)."
echo "Tip: If headless, set a dummy HDMI or enable a virtual display profile to get a desktop."
