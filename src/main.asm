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

; PPU Registers - now in graphics.asm
.import PPUCTRL, PPUMASK, PPUSTATUS, OAMADDR, OAMDATA, PPUSCROLL, PPUADDR, PPUDATA, OAMDMA
; APU Registers - now in sound.asm
.import APU_PULSE1_CTRL, APU_PULSE1_SWEEP, APU_PULSE1_TIMERL, APU_PULSE1_TIMERH
.import APU_SND_CHN_CTRL, APU_FRAME_CNT

; Imported Subroutines & Data from graphics.asm
.import LoadPalette, LoadSmallNametable, UpdateSprites, UpdateLayerScrolls
.import ppu_ctrl_value_default, ppu_mask_value_default
.import oam_ram_buffer

; Imported Subroutines & Data from sound.asm
.import InitializeSound, PlaySoundEffect, PlayBeepSound
.import SFX_JUMP_ID, SFX_COIN_ID

; Target scanline for MMC3 IRQ
SCANLINE_SPLIT1 = 80
SCANLINE_SPLIT2 = 160 ; Target for the second split event

.segment "ZEROPAGE"
; Graphics ZP vars - now in graphics.asm
.importzp layer1_scroll_x, layer1_scroll_y, layer2_scroll_x, layer2_scroll_y, layer3_scroll_x, layer3_scroll_y
.importzp fine_x_scroll_value
.importzp sprite_eff_scroll_low, sprite_eff_scroll_high, sprite_screen_x, oam_index

irq_split_state: .res 1 ; 0 for first split, 1 for second

; New 16.16 fixed-point world/main scroll - Stays in main.asm
.global main_scroll_x_low, main_scroll_x_high
main_scroll_x_low:  .res 1
main_scroll_x_high: .res 1

; Player world coordinates (16.16) - Stays in main.asm
.global player_world_x_low, player_world_x_high, player_world_y_low, player_world_y_high
player_world_x_low: .res 1
player_world_x_high: .res 1
player_world_y_low:   .res 1
player_world_y_high:  .res 1

; Temporary variables for 16-bit math - Stays in main.asm
.global temp_low, temp_high
temp_low: .res 1
temp_high: .res 1

; NMI Synchronization - Stays in main.asm
NMICount: .res 1
PrevNMICount: .res 1

; Game Logic State - Stays in main.asm
last_coin_scroll_high: .res 1
last_jump_scroll_high: .res 1

.segment "RODATA"
NUM_FOREGROUND_SPRITES = 2

; Sprite world X high positions - Stays in main.asm (game specific object placement)
.global sprite0_world_x_high, sprite1_world_x_high
sprite0_world_x_high: .byte $50
sprite1_world_x_high: .byte $70

.segment "STARTUP"
RESET:
  SEI          ; Disable interrupts
  CLD          ; Disable decimal mode
  LDX #$40
  STX APU_FRAME_CNT    ; Disable APU frame IRQ (use imported APU_FRAME_CNT)
  LDX #$FF
  TXS          ; Set up stack
  INX          ; $00 -> $FF

  JSR MMC3_Init ; Initialize MMC3 Mapper
  JSR LoadPalette        ; Now in graphics.asm
  JSR LoadSmallNametable ; Now in graphics.asm
  JSR InitializeSound    ; Now in sound.asm

  ; Initialize scroll positions and counters
  LDA #0
  STA layer1_scroll_y ; Uses imported ZP
  STA layer2_scroll_y ; Uses imported ZP
  STA layer3_scroll_y ; Uses imported ZP
  STA main_scroll_x_low
  STA main_scroll_x_high
  STA player_world_x_low
  STA player_world_x_high
  STA player_world_y_low    ; Init player Y low
  LDA #120 ; Initial screen Y position for player
  STA player_world_y_high   ; Init player Y high
  STA NMICount
  STA PrevNMICount
  STA fine_x_scroll_value ; Uses imported ZP
  LDA #$FF
  STA last_coin_scroll_high ; Initialize for coin sound trigger
  STA last_jump_scroll_high ; Initialize for jump sound trigger

VBLANKWAIT1:       ; Wait for vblank to make sure PPU is ready
  BIT PPUSTATUS ; Use imported PPUSTATUS
  BPL VBLANKWAIT1

CLRMEM:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA oam_ram_buffer, x ; Clear OAM buffer (uses imported oam_ram_buffer)
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  INX
  BNE CLRMEM

VBLANKWAIT2:      ; Wait for vblank again
  BIT PPUSTATUS ; Use imported PPUSTATUS
  BPL VBLANKWAIT2

; Palette loading code moved to LoadPalette in graphics.asm

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

  ; --- Coin Sound Trigger ---
  LDA main_scroll_x_high
  CMP #10 ; Trigger at scroll position 10
  BNE SkipCoinSound
  LDA main_scroll_x_low ; Check low byte too for more precise trigger
  BNE SkipCoinSound
    ; Check if already played for this specific high scroll value
    LDA last_coin_scroll_high
    CMP main_scroll_x_high
    BEQ SkipCoinSound ; Already played

    LDA #SFX_COIN_ID
    JSR PlaySoundEffect
    LDA main_scroll_x_high
    STA last_coin_scroll_high ; Remember this scroll value
SkipCoinSound:

  ; --- Trigger for Jump Sound ---
  LDA main_scroll_x_high
  CMP #20 ; Trigger at a different scroll position
  BNE SkipJumpSound
  LDA main_scroll_x_low ; Check low byte too for more precise trigger
  BNE SkipJumpSound
  ; Check if already played for this specific high scroll value
  LDA last_jump_scroll_high
  CMP main_scroll_x_high
  BEQ SkipJumpSound ; Already played

  LDA #SFX_JUMP_ID
  JSR PlaySoundEffect
  LDA main_scroll_x_high
  STA last_jump_scroll_high ; Remember this scroll value
SkipJumpSound:

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

; All subroutines (UpdateLayerScrolls, PlaySoundEffect, PlayBeepSound, LoadSmallNametable, UpdateSprites)
; are now moved to graphics.asm or sound.asm and imported.

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
