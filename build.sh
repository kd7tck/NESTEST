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
"$CA65_PATH" "$SRC_DIR/graphics.asm" -o "$OUTPUT_DIR/graphics.o" -g --listing "$OUTPUT_DIR/graphics.lst"
"$CA65_PATH" "$SRC_DIR/sound.asm" -o "$OUTPUT_DIR/sound.o" -g --listing "$OUTPUT_DIR/sound.lst"

# Link
echo "Linking..."
"$LD65_PATH" -C "$SRC_DIR/nes.cfg" -o "$OUTPUT_DIR/$ROM_NAME" "$OUTPUT_DIR/main.o" "$OUTPUT_DIR/graphics.o" "$OUTPUT_DIR/sound.o" --mapfile "$OUTPUT_DIR/map.txt"

echo "Build complete: $OUTPUT_DIR/$ROM_NAME"
