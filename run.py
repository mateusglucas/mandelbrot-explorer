#!/usr/bin/env python3
"""VUnit test runner. Usage:  uv run python run.py -v   (or: make test)"""

from pathlib import Path
from vunit import VUnit

ROOT = Path(__file__).parent

vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()

# Nome "lib" (VUnit não deixa chamar de "work"). Dentro dos .vhd, "work" = lib atual.
lib = vu.add_library("lib")
lib.add_source_files(ROOT / "src" / "utils.vhd")
lib.add_source_files(ROOT / "src" / "calc_addr.vhd")
lib.add_source_files(ROOT / "src" / "iterator.vhd")
lib.add_source_files(ROOT / "src" / "idx_to_coord.vhd")
lib.add_source_files(ROOT / "src" / "pan.vhd")
lib.add_source_files(ROOT / "src" / "memory.vhd")
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
tb_mem.add_config(name="small", generics={"MEM_SIZE": 16, "W_ADDR": 5, "W_DATA": 3})

vu.main()
