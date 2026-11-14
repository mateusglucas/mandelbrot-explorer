#!/usr/bin/env python3
"""VUnit test runner. Usage:  uv run python run.py -v   (or: make test)"""

from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent

vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()

# Nome "lib" (VUnit não deixa chamar de "work"). Dentro dos .vhd, "work" = lib atual.
lib = vu.add_library("lib")
lib.add_source_files(ROOT / "src" / "common" / "utils.vhd")
lib.add_source_files(ROOT / "src" / "common" / "pipe_delay.vhd")
lib.add_source_files(ROOT / "src" / "common" / "counter.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "calc_addr.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "iterator.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "idx_to_coord.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "pan.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "memory.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "scheduler.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "pixel_map.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "navigator.vhd")
lib.add_source_files(ROOT / "src" / "compute" / "mandelbrot_core.vhd")
lib.add_source_files(ROOT / "src" / "uart" / "uart_rx.vhd")
lib.add_source_files(ROOT / "src" / "uart" / "commands.vhd")
lib.add_source_files(ROOT / "src" / "video" / "vga_sync.vhd")
lib.add_source_files(ROOT / "src" / "video" / "palette.vhd")
lib.add_source_files(ROOT / "src" / "video" / "video.vhd")
lib.add_source_files(ROOT / "tb" / "tb_*.vhd")

# VUnit + GHDL: VHDL-2008 (biblioteca do VUnit exige)
vu.set_compile_option("ghdl.a_flags", ["--std=08"])
vu.set_sim_option("ghdl.elab_flags", ["--std=08"])

tb = lib.entity("tb_calc_addr")
tb.add_config(name="320x240", generics={"RES_H": 320, "RES_V": 240})
tb.add_config(name="640x480", generics={"RES_H": 640, "RES_V": 480})
tb.add_config(name="128x240", generics={"RES_H": 128, "RES_V": 240})
tb.add_config(name="320x256", generics={"RES_H": 320, "RES_V": 256})
tb.add_config(name="128x256", generics={"RES_H": 128, "RES_V": 256})

tb_idx = lib.entity("tb_idx_to_coord")
# RATIO_FP is Q fixed-point bit pattern; F=K-4=12 with default K=16
#   4096=1.0, 2048=0.5, 1024=0.25, 3072=0.75, 5120=1.25
tb_idx.add_config(name="res5_r1", generics={"RES": 5, "RATIO_FP": 4096})
tb_idx.add_config(name="res5_r0_5", generics={"RES": 5, "RATIO_FP": 2048})
tb_idx.add_config(name="res5_r0_25", generics={"RES": 5, "RATIO_FP": 1024})
tb_idx.add_config(name="res5_r0_75", generics={"RES": 5, "RATIO_FP": 3072})
tb_idx.add_config(name="res5_r1_25", generics={"RES": 5, "RATIO_FP": 5120})
tb_idx.add_config(name="res320_r0_5", generics={"RES": 320, "W_ZOOM": 5, "RATIO_FP": 2048})
tb_idx.add_config(name="res320_r0_75", generics={"RES": 320, "W_ZOOM": 5, "RATIO_FP": 3072})

tb_pan = lib.entity("tb_pan")
# DELTA_FP bit pattern; 256>>zoom, clamps to 1 at high zoom
tb_pan.add_config(name="d256", generics={"DELTA_FP": 256})
tb_pan.add_config(name="d16", generics={"DELTA_FP": 16})

tb_mem = lib.entity("tb_memory")
# MEM_SIZE not power-of-2 so W_ADDR=bits_of(MEM_SIZE-1) can still encode OOR addrs
tb_mem.add_config(name="small", generics={"MEM_SIZE": 12, "W_DATA": 3})

tb_sched = lib.entity("tb_scheduler")
tb_sched.add_config(name="3x2", generics={"RES_H": 3, "RES_V": 2})
tb_sched.add_config(name="4x3", generics={"RES_H": 4, "RES_V": 3})
tb_sched.add_config(name="5x5", generics={"RES_H": 5, "RES_V": 5})

tb_ca = lib.entity("tb_pixel_map")
tb_ca.add_config(name="5x4_r1", generics={"RES_H": 5, "RES_V": 4, "RATIO_FP": 4096})
tb_ca.add_config(name="5x4_r0_5", generics={"RES_H": 5, "RES_V": 4, "RATIO_FP": 2048})
tb_ca.add_config(name="8x6", generics={"RES_H": 8, "RES_V": 6, "RATIO_FP": 4096})

tb_pipe = lib.entity("tb_pipe_delay")
tb_pipe.add_config(name="n0", generics={"N": 0, "W": 4})
tb_pipe.add_config(name="n1", generics={"N": 1, "W": 4})  # null-range shift
tb_pipe.add_config(name="n3", generics={"N": 3, "W": 8})

tb_cnt = lib.entity("tb_counter")
tb_cnt.add_config(name="max5", generics={"MAX": 5})
tb_cnt.add_config(name="max10", generics={"MAX": 10})
tb_cnt.add_config(name="max20", generics={"MAX": 20})
tb_cnt.add_config(name="max8", generics={"MAX": 8})    # power of 2
tb_cnt.add_config(name="max16", generics={"MAX": 16})  # power of 2
tb_cnt.add_config(name="max32", generics={"MAX": 32})  # power of 2

tb_nav = lib.entity("tb_navigator")
tb_nav.add_config(name="z5_d256", generics={"ZOOM_MAX": 5, "DELTA_FP": 256})
tb_nav.add_config(name="z10_d16", generics={"ZOOM_MAX": 10, "DELTA_FP": 16})
tb_nav.add_config(name="z8_d256", generics={"ZOOM_MAX": 8, "DELTA_FP": 256})

tb_mb = lib.entity("tb_mandelbrot_core")
tb_mb.add_config(name="4x3", generics={"RES_H": 4, "RES_V": 3, "MAX_ITER": 16})

tb_cmd = lib.entity("tb_commands")
tb_cmd.add_config(name="default")

tb_uart = lib.entity("tb_uart_rx")
tb_uart.add_config(name="1M_100k", generics={"CLK_HZ": 1_000_000, "BAUD": 100_000})

tb_vid = lib.entity("tb_video")
tb_vid.add_config(name="4x3", generics={"RES_H": 4, "RES_V": 3})

vu.main()
