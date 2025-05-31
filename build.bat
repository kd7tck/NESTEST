@echo off
REM Script to build the NES ROM

REM Define paths
SET CA65_PATH=ca65
SET LD65_PATH=ld65
SET SRC_DIR=src
SET OUTPUT_DIR=bin
SET ROM_NAME=game.nes

REM Create output directory if it doesn't exist
IF NOT EXIST %OUTPUT_DIR% (
    mkdir %OUTPUT_DIR%
)

REM Assemble
echo Assembling...
%CA65_PATH% %SRC_DIR%/main.asm -o %OUTPUT_DIR%/main.o -g --listing %OUTPUT_DIR%/main.lst

REM Link
echo Linking...
%LD65_PATH% -C %SRC_DIR%/nes.cfg -o %OUTPUT_DIR%/%ROM_NAME% %OUTPUT_DIR%/main.o --mapfile %OUTPUT_DIR%/map.txt

echo Build complete: %OUTPUT_DIR%/%ROM_NAME%
