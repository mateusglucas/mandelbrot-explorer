# Mandelbrot Explorer

Mandelbrot set explorer on the Tang Nano 20K (GW2AR-18).
320×240 framebuffer in BSRAM, HDMI 640×480 output, pan/zoom over UART.

## Board access

To flash and open the serial port without `sudo`:

```bash
./tools/setup_fpga_access.sh
```

Log out and back in afterward (`dialout` group + FTDI udev rule).

## Build

```bash
make sync
make test
make lint
make build
make flash
make serial   # default: /dev/ttyUSB1
```

## TODO

- [ ] Pipeline the compute path to raise `clk_calc`
- [ ] Move the framebuffer to external SRAM → higher resolution
