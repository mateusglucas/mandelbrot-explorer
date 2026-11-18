# Bitstream Tang Nano 20K (GW2AR-LV18QN88C8/I7)
# uso: make build

set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7

add_file src/common/utils.vhd
add_file src/common/pipe_delay.vhd
add_file src/common/counter.vhd
add_file src/compute/calc_addr.vhd
add_file src/compute/iterator.vhd
add_file src/compute/idx_to_coord.vhd
add_file src/compute/pan.vhd
add_file src/compute/memory.vhd
add_file src/compute/scheduler.vhd
add_file src/compute/pixel_map.vhd
add_file src/compute/navigator.vhd
add_file src/compute/mandelbrot_core.vhd
add_file src/uart/uart_rx.vhd
add_file src/uart/commands.vhd
add_file src/video/vga_sync.vhd
add_file src/video/palette.vhd
add_file src/video/video.vhd
add_file src/video/tmds_encoder.vhd
add_file src/video/hdmi_tx.vhd
add_file src/board/pll.vhd
add_file src/board/main.vhd
add_file src/board/mandelbrot.cst
add_file src/board/mandelbrot.sdc

set_option -top_module main
set_option -vhdl_std vhd2008
set_option -output_base_name mandelbrot_explorer
set_option -timing_driven 1
set_option -place_option 2
set_option -route_option 1
set_option -print_all_synthesis_warning 1

run all
