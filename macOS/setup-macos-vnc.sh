#!/usr/bin/env bash
set -euo pipefail

# macOS VNC setup (built-in Apple Remote Desktop agent)
# - Installs nothing (uses built-in components)
# - Enables VNC ("legacy") password auth
# - Sets the password (default: ccp2003!)
# - Activates Remote Management and restarts the agent

VNC_PASS="${1:-ccp2003!}"

# Sanity: macOS VNC/ARDAgent expects 6–8 char VNC-style passwords
LEN=${#VNC_PASS}
if (( LEN < 6 || LEN > 8 )); then
  echo "ERROR: VNC password must be 6–8 characters. You provided ${LEN}." >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run with sudo." >&2
  exit 1
fi

KICKSTART="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
if [[ ! -x "$KICKSTART" ]]; then
  echo "kickstart not found; this macOS version may not include ARD the same way. Aborting." >&2
  exit 2
fi

echo "==> Enabling Remote Management and VNC password auth…"
# Turn on Remote Management access (the service behind Screen Sharing/ARD)
"$KICKSTART" -activate -configure -access -on

# Allow legacy VNC viewers and set the VNC password
"$KICKSTART" -configure -clientopts -setvnclegacy -vnclegacy yes
"$KICKSTART" -configure -setvncpw "$VNC_PASS"

# (Optional but sensible) allow remote control without a prompt
"$KICKSTART" -configure -clientopts -setremotecontrol -remotecontrol yes

# Restart ARD agent and ensure menu extra is enabled (status in menu bar)
"$KICKSTART" -restart -agent -menu

# Application firewall usually auto-allows system services, but to be explicit:
FIREWALL="/usr/libexec/ApplicationFirewall/socketfilterfw"
if [[ -x "$FIREWALL" ]]; then
  AGENT="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/MacOS/ARDAgent"
  echo "==> Nudging Application Firewall to allow ARDAgent…"
  "$FIREWALL" --add "$AGENT" >/dev/null 2>&1 || true
  "$FIREWALL" --unblockapp "$AGENT" >/dev/null 2>&1 || true
fi

echo "==> Done."
echo "VNC is enabled with password auth."
echo "Password set to: ${VNC_PASS}"
echo "Connect with any VNC client to: $(ipconfig getifaddr en0 2>/dev/null || echo '<your_mac_ip>'):5900"
echo
echo "Security note: opening VNC to the internet is a bad idea. Put it behind a VPN or restrict at your router."
