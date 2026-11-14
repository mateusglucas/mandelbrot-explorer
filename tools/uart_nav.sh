#!/bin/bash
# terminal serial para navegar o Mandelbrot (115200 8N1)
# uso: ./tools/uart_nav.sh [/dev/ttyUSBx]
# na Tang Nano 20K o UART do BL616 costuma ser ttyUSB1 (FTDI B)

set -euo pipefail

PORT=${1:-/dev/ttyUSB1}
BAUD=115200

if [[ ! -e "$PORT" ]]; then
	echo "porta $PORT nao existe. plugs:" >&2
	ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true
	exit 1
fi

if [[ ! -r "$PORT" || ! -w "$PORT" ]]; then
	echo "sem permissao em $PORT ($(ls -l "$PORT"))" >&2
	echo "voce precisa do grupo dialout. rode uma vez:" >&2
	echo "  ./tools/setup_fpga_access.sh" >&2
	echo "depois logout/login, OU por agora:" >&2
	echo "  sudo screen $PORT $BAUD" >&2
	exit 1
fi

if [[ ! -t 0 || ! -t 1 ]]; then
	echo "precisa de um terminal interativo (rode no teu shell, nao pelo agente)." >&2
	exit 1
fi

cat <<EOF
porta: $PORT @ $BAUD
comandos:
  w/a/s/d ou setas  pan
  e / +             zoom in
  q / -             zoom out
  r                 reset (centro, zoom 0)
  Ctrl+A K  (ou Ctrl+A X)  sair do screen
EOF

# clocal: ignora DCD (FTDI sem carrier → screen sai com "terminating")
# se ainda falhar após sudo screen: sudo rm -f /var/lock/LCK*ttyUSB* /run/lock/LCK*ttyUSB*
stty -F "$PORT" "$BAUD" cs8 -cstopb -parenb clocal cread raw -echo || true
exec screen "$PORT" "$BAUD"
