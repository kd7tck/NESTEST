#!/bin/bash

# Script to build the NES ROM

# Define paths
CA65_PATH=ca65
LD65_PATH=ld65
SRC_DIR=src
OUTPUT_DIR=bin
ROM_NAME=game.nes

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir "$OUTPUT_DIR"
fi

# Assemble
echo "Assembling..."
"$CA65_PATH" "$SRC_DIR/main.asm" -o "$OUTPUT_DIR/main.o" -g --listing "$OUTPUT_DIR/main.lst"

# Link
echo "Linking..."
"$LD65_PATH" -C "$SRC_DIR/nes.cfg" -o "$OUTPUT_DIR/$ROM_NAME" "$OUTPUT_DIR/main.o" --mapfile "$OUTPUT_DIR/map.txt"

echo "Build complete: $OUTPUT_DIR/$ROM_NAME"
