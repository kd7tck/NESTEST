; PPU Register Definitions
.global PPUCTRL, PPUMASK, PPUSTATUS, OAMADDR, OAMDATA, PPUSCROLL, PPUADDR, PPUDATA, OAMDMA
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014

; Imported from main.asm
.importzp main_scroll_x_low, main_scroll_x_high
.importzp player_world_x_high, player_world_y_high
.importzp temp_low, temp_high
.import sprite0_world_x_high, sprite1_world_x_high

.segment "ZEROPAGE"
.global layer1_scroll_x, layer1_scroll_y, layer2_scroll_x, layer2_scroll_y, layer3_scroll_x, layer3_scroll_y
.global fine_x_scroll_value
.global sprite_eff_scroll_low, sprite_eff_scroll_high, sprite_screen_x, oam_index

layer1_scroll_x: .res 1
layer1_scroll_y: .res 1
layer2_scroll_x: .res 1
layer2_scroll_y: .res 1
layer3_scroll_x: .res 1
layer3_scroll_y: .res 1
fine_x_scroll_value: .res 1
sprite_eff_scroll_low: .res 1
sprite_eff_scroll_high: .res 1
sprite_screen_x: .res 1
oam_index: .res 1

.segment "OAM_DATA"
.global oam_ram_buffer
oam_ram_buffer: .res 256

.segment "RODATA"
.global Palette
Palette:
  ; Universal Background + BG Palette 0
  .byte $0F,$11,$21,$31
  ; BG Palette 1
  .byte $0F,$17,$27,$37
  ; BG Palette 2
  .byte $0F,$19,$29,$39
  ; BG Palette 3
  .byte $0F,$16,$26,$36
  ; Sprite Palette 0
  .byte $0F,$11,$21,$31
  ; Sprite Palette 1
  .byte $0F,$17,$27,$37
  ; Sprite Palette 2
  .byte $0F,$19,$29,$39
  ; Sprite Palette 3
  .byte $0F,$16,$26,$36

.global sprite0_world_x_low, sprite0_y, sprite0_tile, sprite0_attr
sprite0_world_x_low:  .byte $00
sprite0_y:            .byte $80
sprite0_tile:         .byte $01
sprite0_attr:         .byte $00

.global sprite1_world_x_low, sprite1_y, sprite1_tile, sprite1_attr
sprite1_world_x_low:  .byte $00
sprite1_y:            .byte $A0
sprite1_tile:         .byte $02
sprite1_attr:         .byte $01

.global player_sprite_tile, player_sprite_attr, PlayerScreenXOffset
player_sprite_tile:   .byte $00
player_sprite_attr:   .byte $02
PlayerScreenXOffset: .byte 64

.global SampleNametable, SampleNametable_End
SampleNametable:
    .byt $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01 ; Row 0
    .byt $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02 ; Row 1
    .byt $03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03 ; Row 2
SampleNametable_End:

.global ppu_ctrl_value_default, ppu_mask_value_default
ppu_ctrl_value_default: .byte %10001000 ; BG $0000, Sprites $1000, NMI on
ppu_mask_value_default: .byte %00011110 ; Show BG/Sprites, Show left column BG/Sprites


.segment "CODE"
.global LoadPalette
LoadPalette:
  LDA PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  LDX #$00
LoadPaletteLoop:
  LDA Palette, X
  STA PPUDATA
  INX
  CPX #$20
  BNE LoadPaletteLoop
  RTS

.global LoadSmallNametable
LoadSmallNametable:
  PHA
  TXA
  PHA
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  LDX #$00
LoadSmallLoop:
  LDA SampleNametable, X
  STA PPUDATA
  INX
  CPX #(SampleNametable_End - SampleNametable)
  BNE LoadSmallLoop
  PLA
  TAX
  PLA
  RTS

.global UpdateSprites
UpdateSprites:
  PHA
  TXA
  PHA
  TYA
  PHA
  LDX #$00
  STX oam_index
  LDA main_scroll_x_low
  STA sprite_eff_scroll_low
  LDA main_scroll_x_high
  STA sprite_eff_scroll_high
  LDA player_world_x_high
  SEC
  SBC sprite_eff_scroll_high
  CLC
  ADC PlayerScreenXOffset
  STA sprite_screen_x
  LDY oam_index
  LDA player_world_y_high
  STA oam_ram_buffer, Y
  INY
  LDA player_sprite_tile
  STA oam_ram_buffer, Y
  INY
  LDA player_sprite_attr
  STA oam_ram_buffer, Y
  INY
  LDA sprite_screen_x
  STA oam_ram_buffer, Y
  INY
  STY oam_index
  LDA main_scroll_x_low
  STA temp_low
  LDA main_scroll_x_high
  STA temp_high
  LSR temp_high
  ROR temp_low
  LSR temp_high
  ROR temp_low
  CLC
  LDA main_scroll_x_low
  ADC temp_low
  STA sprite_eff_scroll_low
  LDA main_scroll_x_high
  ADC temp_high
  STA sprite_eff_scroll_high
  LDA sprite0_world_x_high
  SEC
  SBC sprite_eff_scroll_high
  STA sprite_screen_x
  LDY oam_index
  LDA sprite0_y
  STA oam_ram_buffer, Y
  INY
  LDA sprite0_tile
  STA oam_ram_buffer, Y
  INY
  LDA sprite0_attr
  STA oam_ram_buffer, Y
  INY
  LDA sprite_screen_x
  STA oam_ram_buffer, Y
  INY
  STY oam_index
  LDA main_scroll_x_low
  STA temp_low
  LDA main_scroll_x_high
  STA temp_high
  LSR temp_high
  ROR temp_low
  CLC
  LDA main_scroll_x_low
  ADC temp_low
  STA sprite_eff_scroll_low
  LDA main_scroll_x_high
  ADC temp_high
  STA sprite_eff_scroll_high
  LDA sprite1_world_x_high
  SEC
  SBC sprite_eff_scroll_high
  STA sprite_screen_x
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
  LDA #$F8
HideLoop:
  CPY #252
  BCS EndHideLoop
  STA oam_ram_buffer, Y
  INY
  STA oam_ram_buffer, Y
  INY
  STA oam_ram_buffer, Y
  INY
  STA oam_ram_buffer, Y
  INY
  JMP HideLoop
EndHideLoop:
  PLA
  TAY
  PLA
  TAX
  PLA
  RTS

.global UpdateLayerScrolls
UpdateLayerScrolls:
  PHA
  TXA
  PHA
  TYA
  PHA
  LDA main_scroll_x_low
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  STA fine_x_scroll_value
  LDA main_scroll_x_high
  ASL A
  ASL A
  ASL A
  ORA fine_x_scroll_value
  STA layer3_scroll_x
  LDA main_scroll_x_high
  LSR A
  STA temp_high
  LDA temp_high
  ASL A
  ASL A
  ASL A
  ORA fine_x_scroll_value
  STA layer1_scroll_x
  LDA main_scroll_x_high
  STA temp_high
  LSR temp_high
  LDA main_scroll_x_high
  LSR A
  LSR A
  CLC
  ADC temp_high
  STA temp_high
  LDA temp_high
  ASL A
  ASL A
  ASL A
  ORA fine_x_scroll_value
  STA layer2_scroll_x
  PLA
  TAY
  PLA
  TAX
  PLA
  RTS
