# Mandelbrot Explorer

Mandelbrot set explorer on the Tang Nano 20K (GW2AR-18).
320×240 framebuffer in BSRAM, HDMI 640×480 output, pan/zoom over UART.

## Board access

To flash and open the serial port without `sudo`:

```bash
./tools/setup_fpga_access.sh
```

Then log out and back in (`dialout` group + FTDI udev rule).

## Build

```bash
make sync      # Python deps (uv)
make test      # VUnit (make test p=8 ARGS='*tb_pipe*')
make check     # GHDL analyze
make lint      # VSG
make fmt       # VSG --fix
make build     # Gowin bitstream
make flash
make serial    # UART nav (default: /dev/ttyUSB1)
make all       # build && flash
make clean
```

## TODO

- [ ] Pipeline the compute path to raise `clk_calc`
- [ ] Move the framebuffer to external SRAM → higher resolution
- [ ] Add schematic
- [ ] Add sample images
- [ ] Load palette from an external file
- [ ] Parameterize video timing and FB→screen scale
