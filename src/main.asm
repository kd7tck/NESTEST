.segment "HEADER"
  .byte "NES", $1A ; Magic string for iNES format
  .byte $02        ; Number of 16KB PRG-ROM banks (2 banks = 32KB)
  .byte $01        ; Number of 8KB CHR-ROM banks (1 bank = 8KB)
  .byte $40        ; Mapper type (4 for MMC3), mirroring (lower nibble for mapper, upper for mirroring/submapper)
  .byte $00        ; Mapper type, other flags (upper nibble of mapper is in previous byte)
  .byte $00, $00, $00, $00, $00, $00, $00, $00 ; Reserved bytes

; MMC3 Register Addresses
MMC3_CMD          = $8000
MMC3_BANK_SELECT  = $8001
MMC3_IRQ_LATCH    = $A000
MMC3_IRQ_RELOAD   = $A001
MMC3_IRQ_DISABLE  = $C000
MMC3_IRQ_ENABLE   = $C001

; PPU Register Addresses
PPUCTRL    = $2000
PPUMASK    = $2001
PPUSTATUS  = $2002
OAMADDR    = $2003
OAMDATA    = $2004
PPUSCROLL  = $2005
PPUADDR    = $2006
PPUDATA    = $2007
OAMDMA     = $4014

; Target scanline for MMC3 IRQ
SCANLINE_SPLIT1 = 80
SCANLINE_SPLIT2 = 160 ; Target for the second split event

; APU Register Constants
APU_PULSE1_CTRL   = $4000
APU_PULSE1_SWEEP  = $4001
APU_PULSE1_TIMERL = $4002
APU_PULSE1_TIMERH = $4003
APU_SND_CHN_CTRL  = $4015
APU_FRAME_CNT     = $4017

.segment "ZEROPAGE"
layer1_scroll_x: .res 1
layer1_scroll_y: .res 1
layer2_scroll_x: .res 1
layer2_scroll_y: .res 1
layer3_scroll_x: .res 1
layer3_scroll_y: .res 1
irq_split_state: .res 1 ; 0 for first split, 1 for second
fine_x_scroll_value: .res 1 ; Holds the 3-bit fine X scroll (0-7)

; New 16.16 fixed-point world/main scroll
main_scroll_x_low:  .res 1 ; Fractional part (16.16, so 8 bits of fraction here)
main_scroll_x_high: .res 1 ; Integer part (pixel scroll)

; Player world coordinates (16.16)
player_world_x_low: .res 1
player_world_x_high: .res 1
player_world_y_low:   .res 1 ; Player world Y position (16.16)
player_world_y_high:  .res 1

; Temporary variables for 16-bit math
temp_low: .res 1
temp_high: .res 1

; NMI Synchronization
NMICount: .res 1
PrevNMICount: .res 1

; Variables for sprite calculations
sprite_eff_scroll_low: .res 1
sprite_eff_scroll_high: .res 1
sprite_screen_x: .res 1
oam_index: .res 1 ; To keep track of current OAM buffer offset
last_beep_scroll_high: .res 1 ; For sound trigger logic

.segment "RODATA"
NUM_FOREGROUND_SPRITES = 2

; Sprite 0 (Layer 4, Factor 1.25)
sprite0_world_x_low:  .byte $00
sprite0_world_x_high: .byte $50  ; Initial world X position
sprite0_y:            .byte $80  ; Screen Y position
sprite0_tile:         .byte $01  ; Tile index from sprites.chr
sprite0_attr:         .byte $00  ; Palette 0, no flip

; Sprite 1 (Layer 5, Factor 1.50)
sprite1_world_x_low:  .byte $00
sprite1_world_x_high: .byte $70  ; Initial world X position
sprite1_y:            .byte $A0  ; Screen Y position
sprite1_tile:         .byte $02  ; Tile index from sprites.chr
sprite1_attr:         .byte $01  ; Palette 1, no flip

; Player Sprite Data
player_sprite_tile:   .byte $00  ; Tile index for player (e.g., first sprite in sprites.chr)
player_sprite_attr:   .byte $02  ; Palette 2, no flip

PlayerScreenXOffset: .byte 64 ; Player desired screen X position

SampleNametable:
    .byt $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01 ; Row 0
    .byt $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02 ; Row 1
    .byt $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03 ; Row 2
SampleNametable_End: ; Label to mark end for size calculation if needed by loader. (Not used by LoadSmallNametable)

ppu_ctrl_value_default: .byte %10001000 ; BG $0000, Sprites $1000, NMI on
ppu_mask_value_default: .byte %00011110 ; Show BG/Sprites, Show left column BG/Sprites

.segment "OAM_DATA" ; Mapped to $0200 in nes.cfg
oam_ram_buffer: .res 256

.segment "STARTUP"
RESET:
  SEI          ; Disable interrupts
  CLD          ; Disable decimal mode
  LDX #$40
  STX $4017    ; Disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; $00 -> $FF

  JSR MMC3_Init ; Initialize MMC3 Mapper
  JSR LoadSmallNametable ; Load initial nametable data

  ; Initialize APU
  LDA #%00000001    ; Enable Pulse1 channel only
  STA APU_SND_CHN_CTRL
  LDA #%01000000    ; Mode 0: 4-step sequence, APU IRQ disable
  STA APU_FRAME_CNT

  ; Initialize scroll positions and counters
  LDA #0
  STA layer1_scroll_y
  STA layer2_scroll_y
  STA layer3_scroll_y
  STA main_scroll_x_low
  STA main_scroll_x_high
  STA player_world_x_low
  STA player_world_x_high
  STA player_world_y_low    ; Init player Y low
  LDA #120 ; Initial screen Y position for player
  STA player_world_y_high   ; Init player Y high
  STA NMICount
  STA PrevNMICount
  STA fine_x_scroll_value ; Initialize fine_x_scroll to 0
  LDA #$FF
  STA last_beep_scroll_high ; Initialize for sound trigger

VBLANKWAIT1:       ; Wait for vblank to make sure PPU is ready
  BIT $2002
  BPL VBLANKWAIT1

CLRMEM:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  INX
  BNE CLRMEM

VBLANKWAIT2:      ; Wait for vblank again
  BIT $2002
  BPL VBLANKWAIT2

Palette:
  LDA $2002     ; Read PPUSTATUS to reset PPU address latch
  LDA #$3F
  STA $2006     ; Point PPUADDR to $3F00 (high byte)
  LDA #$00
  STA $2006     ; Point PPUADDR to $3F00 (low byte)

  ; Universal Background + BG Palette 0
  LDA #$0F ; $3F00: Universal Background (Black)
  STA $2007
  LDA #$11 ; $3F01: BG P0C1 (Dark Blue)
  STA $2007
  LDA #$21 ; $3F02: BG P0C2 (Blue)
  STA $2007
  LDA #$31 ; $3F03: BG P0C3 (Light Blue)
  STA $2007

  ; BG Palette 1
  LDA #$0F ; $3F04: Mirror of $3F00 (Black)
  STA $2007
  LDA #$17 ; $3F05: BG P1C1 (Dark Red)
  STA $2007
  LDA #$27 ; $3F06: BG P1C2 (Red)
  STA $2007
  LDA #$37 ; $3F07: BG P1C3 (Light Red)
  STA $2007

  ; BG Palette 2
  LDA #$0F ; $3F08: Mirror of $3F00 (Black)
  STA $2007
  LDA #$19 ; $3F09: BG P2C1 (Dark Green)
  STA $2007
  LDA #$29 ; $3F0A: BG P2C2 (Green)
  STA $2007
  LDA #$39 ; $3F0B: BG P2C3 (Light Green)
  STA $2007

  ; BG Palette 3
  LDA #$0F ; $3F0C: Mirror of $3F00 (Black)
  STA $2007
  LDA #$16 ; $3F0D: BG P3C1 (Dark Yellow/Brown)
  STA $2007
  LDA #$26 ; $3F0E: BG P3C2 (Yellow)
  STA $2007
  LDA #$36 ; $3F0F: BG P3C3 (Light Yellow)
  STA $2007

  ; Sprite Palette 0
  LDA #$0F ; $3F10: SP P0C0 (Transparent - use Universal BG)
  STA $2007
  LDA #$11 ; $3F11: SP P0C1 (Dark Blue)
  STA $2007
  LDA #$21 ; $3F12: SP P0C2 (Blue)
  STA $2007
  LDA #$31 ; $3F13: SP P0C3 (Light Blue)
  STA $2007

  ; Sprite Palette 1
  LDA #$0F ; $3F14: SP P1C0 (Transparent - use Universal BG)
  STA $2007
  LDA #$17 ; $3F15: SP P1C1 (Dark Red)
  STA $2007
  LDA #$27 ; $3F16: SP P1C2 (Red)
  STA $2007
  LDA #$37 ; $3F17: SP P1C3 (Light Red)
  STA $2007

  ; Sprite Palette 2
  LDA #$0F ; $3F18: SP P2C0 (Transparent - use Universal BG)
  STA $2007
  LDA #$19 ; $3F19: SP P2C1 (Dark Green)
  STA $2007
  LDA #$29 ; $3F1A: SP P2C2 (Green)
  STA $2007
  LDA #$39 ; $3F1B: SP P2C3 (Light Green)
  STA $2007

  ; Sprite Palette 3
  LDA #$0F ; $3F1C: SP P3C0 (Transparent - use Universal BG)
  STA $2007
  LDA #$16 ; $3F1D: SP P3C1 (Dark Yellow/Brown)
  STA $2007
  LDA #$26 ; $3F1E: SP P3C2 (Yellow)
  STA $2007
  LDA #$36 ; $3F1F: SP P3C3 (Light Yellow)
  STA $2007

.segment "CODE" ; Or PRG_SWAP_A as per nes.cfg for main code

MainLoop:
  ; --- Simulate Input: Increment scroll (e.g., holding Right) ---
  INC main_scroll_x_low
  BNE SkipIncHigh
  INC main_scroll_x_high
SkipIncHigh:

  ; Copy main_scroll to player_world_x (assuming player movement drives scroll)
  LDA main_scroll_x_low
  STA player_world_x_low
  LDA main_scroll_x_high
  STA player_world_x_high

  ; --- Calculate Per-Layer Scroll Positions ---
  JSR UpdateLayerScrolls

  ; --- Update Sprite Logic ---
  JSR UpdateSprites

  ; --- Example Sound Trigger ---
  LDA main_scroll_x_high
  CMP #10
  BNE SkipBeep
  LDA main_scroll_x_low ; Check low byte too for more precise trigger
  BNE SkipBeep
    ; Check if already beeped for this specific high scroll value
    LDA last_beep_scroll_high
    CMP main_scroll_x_high
    BEQ SkipBeep ; Already beeped

    JSR PlayBeepSound
    LDA main_scroll_x_high
    STA last_beep_scroll_high ; Remember this scroll value
SkipBeep:

  ; --- Other game logic would go here (player updates, enemy AI, collisions) ---

  ; --- Wait for VBlank (NMI) ---
WaitForNMI:
  LDA NMICount         ; Assuming NMICount is a variable incremented by NMI handler
  STA PrevNMICount
WaitLoop:
  LDA NMICount
  CMP PrevNMICount
  BEQ WaitLoop         ; Loop until NMICount changes

  JMP MainLoop

; --- Subroutine to Calculate Layer Scrolls ---
UpdateLayerScrolls:
  PHA ; Preserve A
  TXA
  PHA ; Preserve X
  TYA
  PHA ; Preserve Y

  ; Calculate Fine X scroll (top 3 bits of main_scroll_x_low)
  ; This fine_x_scroll is shared by all layers for horizontal alignment to main view.
  LDA main_scroll_x_low
  LSR A ; bit 7 to carry
  LSR A ; bit 6 to carry
  LSR A ; bit 5 to carry
  LSR A ; bit 4 to carry
  LSR A ; bit 3 to carry. Now A = bits 7,6,5 of original main_scroll_x_low (shifted to bits 0,1,2)
  ; AND #%00000111 ; Ensure it's 0-7, LSRs already do this if original was byte.
  STA fine_x_scroll_value ; Store the 3-bit fine X scroll (0-7)

  ; Layer 3 Scroll (Factor 1.0)
  ; Coarse X scroll is main_scroll_x_high
  ; Combined X value for $2005 = (main_scroll_x_high << 3) | fine_x_scroll_value
  ; This interpretation of how to use fine_x_scroll_value with coarse scroll
  ; is specific to the problem description's implied NMI/IRQ scroll write method.
  LDA main_scroll_x_high ; Coarse X part
  ASL A ; x2
  ASL A ; x4
  ASL A ; x8 (now coarse X is in bits D3-D7)
  ORA fine_x_scroll_value
  STA layer3_scroll_x

  ; Layer 1 Scroll (Factor 0.5)
  ; scroll1_coarse = main_scroll_x_high >> 1
  LDA main_scroll_x_high
  LSR A                   ; Coarse X / 2
  STA temp_high           ; Store coarse X for layer 1
  ; Combined X value = (temp_high << 3) | fine_x_scroll_value
  LDA temp_high
  ASL A ; x2
  ASL A ; x4
  ASL A ; x8
  ORA fine_x_scroll_value
  STA layer1_scroll_x

  ; Layer 2 Scroll (Factor 0.75)
  ; scroll2_coarse = (main_scroll_x_high >> 1) + (main_scroll_x_high >> 2)
  LDA main_scroll_x_high
  STA temp_high           ; temp_high = main_scroll_x_high
  LSR temp_high           ; temp_high = main_scroll_x_high >> 1 (val_a)
  LDA main_scroll_x_high
  LSR A                   ; A = main_scroll_x_high >> 1
  LSR A                   ; A = main_scroll_x_high >> 2 (val_b)
  CLC
  ADC temp_high           ; A = val_a + val_b (coarse X for layer 2)
  STA temp_high           ; Store coarse X for layer 2
  ; Combined X value = (temp_high << 3) | fine_x_scroll_value
  LDA temp_high
  ASL A ; x2
  ASL A ; x4
  ASL A ; x8
  ORA fine_x_scroll_value
  STA layer2_scroll_x

  ; Y scrolls are static, initialized in RESET.

  PLA ; Restore Y
  TAY
  PLA ; Restore X
  TAX
  PLA ; Restore A
  RTS

PlayBeepSound:
  PHA

  ; Setup Pulse 1 for a short beep
  ; $4000: DDLC VVVV (Duty, EnvLoop/LenCtrHalt, ConstVol, Vol/EnvPeriod)
  LDA #%01011111  ; Duty 25% (01), Length Ctr Halt OFF, Const Vol ON, Volume 15 (max)
  STA APU_PULSE1_CTRL

  ; $4001: EPPP NSSS (Sweep enable, Period, Negate, Shift)
  LDA #%00001000  ; Sweep off
  STA APU_PULSE1_SWEEP

  ; $4002: TTTT TTTT (Timer low 8 bits)
  LDA #$A8        ; Timer value for a mid-range note
  STA APU_PULSE1_TIMERL

  ; $4003: LLLL LTTT (Length counter load, Timer high 3 bits)
  LDA #%00010001  ; Length counter load (e.g., $00010 = table val 20), Timer high (for $1A8 -> $01)
  STA APU_PULSE1_TIMERH ; This write also triggers the sound

  PLA
  RTS

LoadSmallNametable:
  PHA
  TXA
  PHA

  LDA PPUSTATUS
  LDA #$20 ; Nametable 0 address $2000
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #$00
LoadSmallLoop:
  LDA SampleNametable, X
  STA PPUDATA
  INX
  CPX #(32*3) ; Load 3 rows = 96 bytes
  BNE LoadSmallLoop

  PLA
  TAX
  PLA
  RTS

UpdateSprites:
  PHA
  TXA
  PHA
  TYA
  PHA

  LDX #$00
  STX oam_index ; Start populating oam_ram_buffer from its beginning

  ; --- Process Player Sprite (Layer 3, F=1.0) ---
  ; Player's effective scroll IS main_scroll (Factor 1.0)
  LDA main_scroll_x_low
  STA sprite_eff_scroll_low
  LDA main_scroll_x_high
  STA sprite_eff_scroll_high

  ; Screen X = player_world_x_high - sprite_eff_scroll_high
  ; (player_world_x is currently set to main_scroll_x in MainLoop)
  ; Screen X = (player_world_x_high - main_scroll_x_high) + PlayerScreenXOffset
  ; Since player_world_x_high = main_scroll_x_high, this simplifies to PlayerScreenXOffset
  LDA player_world_x_high
  SEC
  SBC sprite_eff_scroll_high ; sprite_eff_scroll_high is main_scroll_x_high for player
  CLC                        ; Result of SBC is (player_world_x_high - main_scroll_x_high), which is 0
  ADC PlayerScreenXOffset    ; So, sprite_screen_x becomes PlayerScreenXOffset
  STA sprite_screen_x

  ; Populate OAM Buffer for Player Sprite
  LDY oam_index
  LDA player_world_y_high ; Using the high byte of world Y as screen Y
  STA oam_ram_buffer, Y
  INY
  LDA player_sprite_tile
  STA oam_ram_buffer, Y
  INY
  LDA player_sprite_attr
  STA oam_ram_buffer, Y
  INY
  LDA sprite_screen_x       ; Calculated screen X
  STA oam_ram_buffer, Y
  INY
  STY oam_index

  ; --- Process Sprite 0 (Layer 4, F=1.25) ---
  ; Calculate effective scroll: main_scroll + (main_scroll >> 2)
  LDA main_scroll_x_low
  STA temp_low
  LDA main_scroll_x_high
  STA temp_high

  ; temp = main_scroll >> 2
  LSR temp_high
  ROR temp_low
  LSR temp_high
  ROR temp_low          ; Now temp_high, temp_low = main_scroll >> 2

  CLC
  LDA main_scroll_x_low
  ADC temp_low
  STA sprite_eff_scroll_low
  LDA main_scroll_x_high
  ADC temp_high
  STA sprite_eff_scroll_high ; sprite_eff_scroll = main_scroll * 1.25

  ; Screen X = sprite0_world_x_high - sprite_eff_scroll_high
  LDA sprite0_world_x_high
  SEC
  SBC sprite_eff_scroll_high
  STA sprite_screen_x

  ; Populate OAM Buffer for sprite 0
  LDY oam_index
  LDA sprite0_y
  STA oam_ram_buffer, Y ; Y position
  INY
  LDA sprite0_tile
  STA oam_ram_buffer, Y ; Tile Index
  INY
  LDA sprite0_attr
  STA oam_ram_buffer, Y ; Attributes
  INY
  LDA sprite_screen_x
  STA oam_ram_buffer, Y ; X position
  INY
  STY oam_index

  ; --- Process Sprite 1 (Layer 5, F=1.50) ---
  ; Calculate effective scroll: main_scroll + (main_scroll >> 1)
  LDA main_scroll_x_low
  STA temp_low
  LDA main_scroll_x_high
  STA temp_high

  ; temp = main_scroll >> 1
  LSR temp_high
  ROR temp_low          ; Now temp_high, temp_low = main_scroll >> 1

  CLC
  LDA main_scroll_x_low
  ADC temp_low
  STA sprite_eff_scroll_low
  LDA main_scroll_x_high
  ADC temp_high
  STA sprite_eff_scroll_high ; sprite_eff_scroll = main_scroll * 1.50

  ; Screen X = sprite1_world_x_high - sprite_eff_scroll_high
  LDA sprite1_world_x_high
  SEC
  SBC sprite_eff_scroll_high
  STA sprite_screen_x

  ; Populate OAM Buffer for sprite 1
  LDY oam_index
  LDA sprite1_y
  STA oam_ram_buffer, Y
  INY
  LDA sprite1_tile
  STA oam_ram_buffer, Y
  INY
  LDA sprite1_attr
  STA oam_ram_buffer, Y
  INY
  LDA sprite_screen_x
  STA oam_ram_buffer, Y
  INY
  STY oam_index

  ; --- Hide remaining sprites ---
  ; Fill rest of OAM with Y > 239 to hide them
  LDA #$F8 ; Screen Y position to hide sprites (e.g. 248)
HideLoop:
  CPY #252 ; Process up to OAM index 251 (for 63 sprites total, leaving last sprite for safety)
           ; Max OAM is 256 bytes (64 sprites). Loop until Y is 252, so we fill sprite entries up to 62.
           ; Sprite 63 (indices 252, 253, 254, 255) will be the last one potentially set by this loop.
  BCS EndHideLoop ; If Y >= 252, branch to end. BCS is equivalent to BGE for unsigned.
  STA oam_ram_buffer, Y
  INY
  STA oam_ram_buffer, Y ; Tile (can be same hidden Y)
  INY
  STA oam_ram_buffer, Y ; Attributes (can be same hidden Y)
  INY
  STA oam_ram_buffer, Y ; X (can be same hidden Y)
  INY
  JMP HideLoop
EndHideLoop:

  PLA
  TAY
  PLA
  TAX
  PLA
  RTS

MMC3_Init:
  PHA             ; Preserve A

  ; Disable MMC3 IRQs initially
  LDA #$00        ; Value doesn't matter for disabling
  STA MMC3_IRQ_DISABLE

  ; Set default PRG banking mode (Mode 0: $8000 swappable, $A000 swappable, $C000 fixed, $E000 fixed)
  ; And default CHR banking mode (Mode 0: two 2KB banks at $0000-$07FF and $0800-$0FFF, four 1KB banks at $1000-$1FFF)
  LDA #%00000000  ; Bits 7,6 for PRG mode (00 is mode 0). Bits 5-0 for CHR A12 inversion.
  STA MMC3_CMD

  ; Select initial PRG bank 0 for the $8000-$9FFF slot (R6):
  LDA #$06        ; Select R6 register (for $8000-$9FFF)
  STA MMC3_CMD
  LDA #$00        ; Bank 0
  STA MMC3_BANK_SELECT

  ; Select initial PRG bank 1 for the $A000-$BFFF slot (R7):
  LDA #$07        ; Select R7 register (for $A000-$BFFF)
  STA MMC3_CMD
  LDA #$01        ; Bank 1
  STA MMC3_BANK_SELECT

  ; Note: The fixed bank at $E000-$FFFF is automatically the last physical bank.
  ; The bank at $C000-$DFFF is automatically the second to last physical bank in this PRG mode.
  ; RESET code (including this routine) should be in the fixed upper bank ($E000-$FFFF).

  ; Initialize IRQ split state
  LDA #$00
  STA irq_split_state

  ; --- CHR Banking Setup for MMC3 Mode 0 ---
  ; PPU $0000-$0FFF for BG tiles (from CHR banks 0-3)
  ; PPU $1000-$1FFF for Sprite tiles (from CHR banks 4-7)

  ; Set $8000 CMD register to select CHR regs R0-R5, then $8001 for bank number.
  ; CHR A12 inversion bits in $8000 are 0 for now (normal mapping).

  ; R0: PPU $0000-$07FF (2KB), map to CHR physical bank 0 (which means banks 0 & 1 if 1KB granularity)
  LDA #%00000000  ; Select R0, PRG Mode 0, CHR A12 Inversion bits all 0
  STA MMC3_CMD
  LDA #$00        ; CHR data bank 0 (for the 2KB page starting at $0000)
  STA MMC3_BANK_SELECT

  ; R1: PPU $0800-$0FFF (2KB), map to CHR physical bank 2 (banks 2 & 3 if 1KB granularity)
  LDA #%00000001  ; Select R1
  STA MMC3_CMD
  LDA #$02        ; CHR data bank 2 (for the 2KB page starting at $0800)
  STA MMC3_BANK_SELECT

  ; R2: PPU $1000-$13FF (1KB), map to CHR physical bank 4
  LDA #%00000010  ; Select R2
  STA MMC3_CMD
  LDA #$04        ; CHR data bank 4
  STA MMC3_BANK_SELECT

  ; R3: PPU $1400-$17FF (1KB), map to CHR physical bank 5
  LDA #%00000011  ; Select R3
  STA MMC3_CMD
  LDA #$05        ; CHR data bank 5
  STA MMC3_BANK_SELECT

  ; R4: PPU $1800-$1BFF (1KB), map to CHR physical bank 6
  LDA #%00000100  ; Select R4
  STA MMC3_CMD
  LDA #$06        ; CHR data bank 6
  STA MMC3_BANK_SELECT

  ; R5: PPU $1C00-$1FFF (1KB), map to CHR physical bank 7
  LDA #%00000101  ; Select R5
  STA MMC3_CMD
  LDA #$07        ; CHR data bank 7
  STA MMC3_BANK_SELECT

  PLA             ; Restore A
  RTS

NMI:
  PHA             ; Push Accumulator
  TXA             ; Transfer X to A
  PHA             ; Push X (as A)
  TYA             ; Transfer Y to A
  PHA             ; Push Y (as A)

  LDA PPUSTATUS   ; Read PPU status to reset address latch and acknowledge NMI

  ; --- OAM DMA Transfer ---
  LDA #>oam_ram_buffer ; High byte of OAM buffer RAM address (e.g., $02 for $0200)
  STA OAMDMA        ; Writing here initiates DMA transfer from $xx00-$xxFF to OAM
  ; Note: DMA takes ~513 CPU cycles. Subsequent code should account for this.

  ; --- PPU Rendering Setup ---
  LDA ppu_mask_value_default
  STA PPUMASK
  LDA ppu_ctrl_value_default
  STA PPUCTRL       ; Initial PPUCTRL write, NMI enabled.

  ; --- Set Scroll for Layer 1 ---
  LDA layer1_scroll_x
  STA PPUSCROLL     ; Write X scroll
  LDA layer1_scroll_y
  STA PPUSCROLL     ; Write Y scroll

  ; --- MMC3 IRQ Setup for First Scanline Split ---
  LDA #$00
  STA irq_split_state      ; Reset for current frame's IRQ sequence
  LDA #SCANLINE_SPLIT1 ; Value for the first IRQ (e.g., scanline 80)
  STA MMC3_IRQ_LATCH   ; Write to IRQ Latch register ($A000)

  LDA #$00           ; Dummy write, value doesn't matter for reload
  STA MMC3_IRQ_RELOAD  ; Write to IRQ Reload register ($A001) to arm the counter

  LDA #$00           ; Dummy write, value doesn't matter for enable
  STA MMC3_IRQ_ENABLE  ; Write to IRQ Enable register ($C001) to enable MMC3 IRQs

  ; --- Music/Sound Update (Placeholder) ---
  ; JSR UpdateMusic

  INC NMICount      ; Increment NMI counter for main loop synchronization

  ; --- NMI Exit ---
  PLA             ; Pull Y (as A)
  TAY             ; Transfer A to Y
  PLA             ; Pull X (as A)
  TAX             ; Transfer A to X
  PLA             ; Pull Accumulator
  RTI             ; Return from Interrupt

IRQ:
  PHA             ; Push Accumulator
  TXA             ; Transfer X to A
  PHA             ; Push X (as A)
  TYA             ; Transfer Y to A
  PHA             ; Push Y (as A)

  ; MMC3 IRQ is cleared by the CPU jump, effectively. Re-arm or disable as needed.

  LDA irq_split_state
  BEQ HandleFirstSplit

HandleSecondSplit:
  ; --- This is the IRQ for the second split (e.g., at scanline 160) ---
  ; Set scroll for Layer 3
  LDA layer3_scroll_x
  STA PPUSCROLL
  LDA layer3_scroll_y
  STA PPUSCROLL

  ; Disable MMC3 IRQs for the rest of the frame
  LDA #$00 ; dummy value
  STA MMC3_IRQ_DISABLE

  JMP IrqDone

HandleFirstSplit:
  ; --- This is the IRQ for the first split (e.g., at scanline 80) ---
  ; Set scroll for Layer 2
  LDA layer2_scroll_x
  STA PPUSCROLL
  LDA layer2_scroll_y
  STA PPUSCROLL

  ; Set up MMC3 IRQ for the second split
  LDA #(SCANLINE_SPLIT2 - SCANLINE_SPLIT1) ; Latch value (scanlines from current to next IRQ)
  STA MMC3_IRQ_LATCH

  LDA #$00 ; dummy value
  STA MMC3_IRQ_RELOAD  ; Arm the counter

  LDA #$00 ; dummy value
  STA MMC3_IRQ_ENABLE  ; Enable MMC3 IRQs

  ; Update state for next IRQ
  INC irq_split_state  ; irq_split_state becomes 1

IrqDone:
  PLA             ; Pull Y (as A)
  TAY             ; Transfer A to Y
  PLA             ; Pull X (as A)
  TAX             ; Transfer A to X
  PLA             ; Pull Accumulator
  RTI             ; Return from Interrupt

.segment "CHRDATA"
  .incbin "graphics/tiles.chr" ; Assuming this file is 8KB (8192 bytes)

.segment "VECTORS"
  .addr NMI, RESET, IRQ ; Define NMI, RESET, and IRQ vectors
