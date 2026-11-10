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

vu.main()
