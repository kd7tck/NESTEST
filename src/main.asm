.segment "HEADER"
  .byte "NES", $1A ; Magic string for iNES format
  .byte $01        ; Number of 16KB PRG-ROM banks
  .byte $01        ; Number of 8KB CHR-ROM banks
  .byte $00        ; Mapper type (0 for NROM), mirroring
  .byte $00        ; Mapper type, other flags
  .byte $00, $00, $00, $00, $00, $00, $00, $00 ; Reserved bytes

.segment "STARTUP"
RESET:
  SEI          ; Disable interrupts
  CLD          ; Disable decimal mode
  LDX #$40
  STX $4017    ; Disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; $00 -> $FF

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
  LDA $2002             ; Reset PPU, start writing to PPU $2007
  LDA #$3F
  STA $2006             ; Write PPU address $3F00
  LDA #$00
  STA $2006
  LDA #$0F              ; Black background
  STA $2007
  LDA #$10              ; Blue
  STA $2007
  LDA #$20              ; Green
  STA $2007
  LDA #$30              ; Red
  STA $2007

Forever:
  JMP Forever         ; Infinite loop

NMI:
  RTI

IRQ:
  RTI

.segment "VECTORS"
  .addr NMI, RESET, IRQ ; Define NMI, RESET, and IRQ vectors
