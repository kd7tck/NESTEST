; APU Register Definitions
.global APU_PULSE1_CTRL, APU_PULSE1_SWEEP, APU_PULSE1_TIMERL, APU_PULSE1_TIMERH
.global APU_SND_CHN_CTRL, APU_FRAME_CNT

; Imported zero-page variables from main.asm
.importzp temp_low, temp_high

APU_PULSE1_CTRL   = $4000
APU_PULSE1_SWEEP  = $4001
APU_PULSE1_TIMERL = $4002
APU_PULSE1_TIMERH = $4003
APU_SND_CHN_CTRL  = $4015
APU_FRAME_CNT     = $4017

.segment "RODATA"
.global SoundEffect_Jump, SoundEffect_Coin, SoundEffectsEnd
.global SOUND_EFFECT_DATA_SIZE
.global SFX_JUMP_ID, SFX_COIN_ID, TOTAL_SOUND_EFFECTS
.global SoundEffectDataTable, SoundEffectDataTable_End

SoundEffect_Jump:
  .byte %01011100
  .byte %10110010
  .byte $A0
  .byte %01000000

SoundEffect_Coin:
  .byte %10011010
  .byte %00001000
  .byte $50
  .byte %00100000

SoundEffectsEnd:

SOUND_EFFECT_DATA_SIZE = 4

SFX_JUMP_ID = 0
SFX_COIN_ID = 1
TOTAL_SOUND_EFFECTS = 2

SoundEffectDataTable:
  .addr SoundEffect_Jump
  .addr SoundEffect_Coin
SoundEffectDataTable_End:

.segment "CODE"
.global InitializeSound
InitializeSound:
  LDA #%00000001    ; Enable Pulse1 channel only
  STA APU_SND_CHN_CTRL
  LDA #%01000000    ; Mode 0: 4-step sequence, APU IRQ disable
  STA APU_FRAME_CNT
  RTS

.global PlaySoundEffect
PlaySoundEffect:
  PHA
  ; temp_low and temp_high are now imported
  ASL A
  TAX
  LDA SoundEffectDataTable, X
  STA temp_low
  INX
  LDA SoundEffectDataTable, X
  STA temp_high
  LDY #0
  LDA (temp_low), Y
  STA APU_PULSE1_CTRL
  INY
  LDA (temp_low), Y
  STA APU_PULSE1_SWEEP
  INY
  LDA (temp_low), Y
  STA APU_PULSE1_TIMERL
  INY
  LDA (temp_low), Y
  STA APU_PULSE1_TIMERH
  PLA
  RTS

.global PlayBeepSound
PlayBeepSound:
  PHA
  LDA #%01011111
  STA APU_PULSE1_CTRL
  LDA #%00001000
  STA APU_PULSE1_SWEEP
  LDA #$A8
  STA APU_PULSE1_TIMERL
  LDA #%00010001
  STA APU_PULSE1_TIMERH
  PLA
  RTS
