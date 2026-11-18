# Mandelbrot explorer — Tang Nano 20K / Gowin
#
#   make sync    — instala deps Python (uv)
#   make test    — VUnit (p=N paralelo, ARGS='filtro')
#   make check   — analisa VHDL com GHDL (rápido, sem FPGA)
#   make lint    — VSG style check (vsg.yaml)
#   make fmt     — VSG --fix (reescreve .vhd)
#   make build   — síntese + P&R + bitstream (precisa build.tcl)
#   make flash   — grava impl/pnr/mandelbrot_explorer.fs na placa
#   make serial  — abre UART de navegação (screen)
#   make all     — build && flash
#   make clean   — remove artefatos GHDL/Gowin locais

GOWIN_HOME      ?= $(HOME)/gowin/IDE
OPENFPGALOADER  ?= $(HOME)/openFPGALoader/build/openFPGALoader
BITSTREAM       ?= impl/pnr/mandelbrot_explorer.fs
BOARD           ?= tangnano20k
PORT            ?= /dev/ttyUSB1
BAUD            ?= 115200

# análise rápida (sem IP Gowin: pll/hdmi)
GHDL_SRCS ?= \
	src/common/utils.vhd \
	src/common/pipe_delay.vhd \
	src/common/counter.vhd \
	src/compute/calc_addr.vhd \
	src/compute/iterator.vhd \
	src/compute/idx_to_coord.vhd \
	src/compute/pan.vhd \
	src/compute/memory.vhd \
	src/compute/scheduler.vhd \
	src/compute/pixel_map.vhd \
	src/compute/navigator.vhd \
	src/compute/mandelbrot_core.vhd \
	src/uart/uart_rx.vhd \
	src/uart/commands.vhd \
	src/video/vga_sync.vhd \
	src/video/palette.vhd \
	src/video/video.vhd

UV ?= uv
PYTHON ?= $(UV) run python

VSG_CFG ?= vsg.yaml

.PHONY: help check analyze test test-vunit sync lint fmt build flash serial uart all clean

help:
	@echo "targets: sync | test | check | lint | fmt | build | flash | serial | all | clean"
	@echo "  PORT=$(PORT)  BITSTREAM=$(BITSTREAM)"
	@echo "  make test p=8"

# --- deps (uv) ---
sync:
	$(UV) sync

# --- análise rápida (GHDL, sem VUnit) ---
check analyze:
	ghdl -a --std=08 $(GHDL_SRCS)
	@echo "ok: GHDL analyze"

# --- estilo VHDL (VSG) ---
lint:
	$(UV) run vsg -c $(VSG_CFG) -of summary

fmt:
	$(UV) run vsg -c $(VSG_CFG) --fix

# --- testes (VUnit descobre TBs em run.py) ---
#   make test              # 1 processo (padrão)
#   make test p=8          # paralelo (Make reserva -p; use p=)
#   make test p=4 ARGS='*tb_pipe*'
p    ?= 1
ARGS ?=
test test-vunit:
	$(PYTHON) run.py -v -p $(p) $(ARGS)

# --- bitstream Gowin ---
build: build.tcl
	env -u QT_PLUGIN_PATH QT_QPA_PLATFORM=offscreen \
		LD_LIBRARY_PATH="$(GOWIN_HOME)/lib" \
		"$(GOWIN_HOME)/bin/gw_sh" build.tcl

# --- gravação ---
flash: $(BITSTREAM)
	$(OPENFPGALOADER) -b $(BOARD) $(BITSTREAM)

$(BITSTREAM):
	@echo "bitstream ausente: $(BITSTREAM)"
	@echo "rode: make build"
	@exit 1

# --- serial / navegação ---
serial uart:
	./tools/uart_nav.sh $(PORT)

all: build flash

clean:
	rm -f *.o *.cf work-obj93.cf
	rm -rf impl/gwsynthesis impl/pnr impl/temp
