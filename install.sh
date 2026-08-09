#!/bin/bash
set -e

PLASMOID_ID="KSpotiWidget"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting installation for KSpotiWidget..."

# 1. Install Python Dependencies
echo "Installing Python dependencies..."
python3 -m pip install --upgrade flask deep-translator cutlet pykakasi cyrtranslit --break-system-packages 2>/dev/null || \
python3 -m pip install --upgrade flask deep-translator cutlet pykakasi cyrtranslit

# 2. Install/Upgrade Plasmoid for KDE Plasma 6
echo "Installing Plasmoid widget into KDE Plasma 6..."
if kpackagetool6 -l | grep -q "$PLASMOID_ID"; then
    echo "Updating existing KSpotiWidget installation..."
    kpackagetool6 -t Plasma/Applet -u "$SCRIPT_DIR"
else
    echo "Installing KSpotiWidget..."
    kpackagetool6 -t Plasma/Applet -i "$SCRIPT_DIR"
fi

# 3. Create Systemd User Service to auto-start Python Server on boot
echo "Setting up background translation server systemd service..."
mkdir -p ~/.config/systemd/user/

PLASMOID_PATH="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"

cat <<EOF > ~/.config/systemd/user/kspoti-server.service
[Unit]
Description=KSpotiWidget Translation Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${PLASMOID_PATH}/romaji_server.py
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now kspoti-server.service

echo ""
echo "KSpotiWidget installed successfully!"
echo "Add 'KSpotiWidget' to your desktop or panel from KDE's 'Add Widgets' menu."
