# NES Game Project: [To Be Determined]

This project is an NES game featuring extreme parallax scrolling, developed in 6502 Assembly.

## Project Goals

- Implement a single-player side-scrolling game (genre TBD: action, platformer, or shooter).
- Achieve extreme parallax scrolling with three background layers and two foreground layers.
- Utilize highly detailed and realistic pixel art within NES constraints.

## Technical Details

- **Platform:** Nintendo Entertainment System (NES)
- **Programming Language:** 6502 Assembly (CA65)
- **Graphics:** 256x240 resolution, 64-color palette.
- **Sound:** 5-channel APU.

## Development Environment

- **Assembler:** CA65
- **Emulator:** FCEUX (for testing on Windows 11)
- **Graphics Editor:** YY-CHR or PyTILES
- **Sound Tool:** Famitracker

## Building the ROM

1.  Ensure you have `ca65` and `ld65` (part of the CC65 toolchain) installed and in your system's PATH.
2.  Run the `build.bat` script from the root of the project:
    ```bash
    build.bat
    ```
3.  The compiled ROM (`game.nes`) will be placed in the `bin` directory.

## Running the Game

Use an NES emulator like FCEUX to run `bin/game.nes`.

## Project Structure

- `src/`: Contains the 6502 assembly source code (`.asm`) and linker configuration (`.cfg`).
- `graphics/`: Contains tile data (`.chr`) for backgrounds and sprites.
- `sound/`: Contains music and sound effect files (e.g., Famitracker `.ftm` files).
- `docs/`: Contains project documentation and design notes.
- `bin/`: Output directory for the compiled ROM and other build artifacts (e.g., map files, listings). This directory is created by the build script.
- `build.bat`: Script for building the NES ROM.
