#!/bin/bash
# Roda UMA vez (pede senha): libera gravação da Tang Nano sem sudo depois.
# Depois: logout/login (ou reiniciar a sessão) para o grupo dialout valer.

set -euo pipefail

sudo usermod -aG dialout "$USER"

RULE=/etc/udev/rules.d/99-tangnano-ftdi.rules
sudo tee "$RULE" >/dev/null <<'EOF'
# Tang Nano / FT2232H — acesso sem root para openFPGALoader
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", MODE="0666", GROUP="dialout"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

echo
echo "ok. faça logout/login (ou reinicie a sessão gráfica) para o grupo dialout valer."
echo "gravação imediata (com sudo, sem esperar logout):"
echo "  sudo $HOME/Documentos/openFPGALoader/build/openFPGALoader -b tangnano20k impl/pnr/mandelbrot_explorer.fs"
