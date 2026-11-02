# Copyright 2026 Universidad de los Andes.
# Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: SHL-0.51
#
# Course: Arquitectura de Computadores (2026)
# 
# Authors:
# - Nicolás Villegas <navillegas@miuandes.cl>

# Configuration
TOP  := game_top
PCF  := goboard.pcf

# RTL Sources
SRC  := $(wildcard ./rtl/*.v ./rtl/**/*.v)

# Build Targets
JSON := $(TOP).json
ASC  := $(TOP).asc
BIN  := $(TOP).bin

# Assembly Sources
SS   := sw/game.s
HEX  := sw/game.hex
ROM  := rtl/game_rom.v
FFM  := rtl/game_mem_ff.v

.PHONY: all prog clean stats asm

# Default target
all: asm prog

# Step 1: Synthesis using Yosys
$(JSON): $(SRC) $(HEX)
	yosys -p "read_verilog $(SRC); synth_ice40 -top $(TOP) -json ${TOP}.json; stat"

# Step 2: Place and Route using NextPNR
$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --hx1k --package vq100 --freq 25 --json $(JSON) --pcf $(PCF) --asc $(ASC)

# Step 3: Bitstream Generation
$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

# Step 4: Flash the Board
prog: $(BIN)
	iceprog $(BIN)

# Assembles game.s, generating game.hex, game_rom.v (strategy 1) and game_mem_ff.v (strategy 2)
asm: $(SS)
	python3 assembler.py $(SS) -o $(HEX) --rom $(ROM) --ff-mem $(FFM)

# Clean up generated files
clean:
	rm -f $(JSON) $(ASC) $(BIN) $(HEX)

# =====================================================================
#                      ASIC (LibreLane + GF180MCU)
# =====================================================================
# Ejecutar dentro del nix-shell, desde la raíz del repo. Ejemplos:
#   make asic                                        estrategia 1 (romram)
#   make asic STRAT=ff                               estrategia 2 (ff)
#   make asic TAG=romram_T50 ARGS="-c CLOCK_PERIOD=50"
#   make klayout TAG=romram_T50
 
PDK   ?= gf180mcuD
STRAT ?= romram
TAG   ?= $(STRAT)_base
ARGS  ?=
 
asic: asm
	cd asic && librelane --pdk $(PDK) $(ARGS) config_$(STRAT).json --run-tag $(TAG) --overwrite
 
klayout:
	cd asic && librelane --pdk $(PDK) --flow openinklayout config_$(STRAT).json --run-tag $(TAG)
 
openroad:
	cd asic && librelane --pdk $(PDK) --flow openinopenroad config_$(STRAT).json --run-tag $(TAG)