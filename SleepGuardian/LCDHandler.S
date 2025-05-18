;====================================================
; LCD Handler for SleepGuardian - Direct Port Version
;====================================================
#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Export these functions to be called from C
.global LCD_init_asm
.global LCD_command_asm
.global LCD_data_asm
.global LCD_update_temp_asm

;================================================================
; Initialize LCD display in 4-bit mode
;================================================================
LCD_init_asm:
      ; Save used registers
      PUSH  R16
      PUSH  R17
      
      ; Configure ports
      LDI   R16, 0xFF
      OUT   DDRD, R16         ; Port D as outputs for data
      OUT   DDRB, R16         ; Port B as outputs for control
      CBI   PORTB, 0          ; EN = 0
      
      ; Wait for LCD to power up
      RCALL delay_ms
      
      ; 4-bit initialization sequence
      LDI   R16, 0x33         ; 8-bit mode first attempt
      RCALL command_wrt       
      RCALL delay_ms
      
      LDI   R16, 0x32         ; 4-bit mode
      RCALL command_wrt
      RCALL delay_ms
      
      LDI   R16, 0x28         ; 2 lines, 5x7 matrix
      RCALL command_wrt
      RCALL delay_ms
      
      LDI   R16, 0x0C         ; Display ON, cursor OFF
      RCALL command_wrt
      
      LDI   R16, 0x01         ; Clear display
      RCALL command_wrt
      RCALL delay_ms
      
      LDI   R16, 0x06         ; Auto-increment cursor
      RCALL command_wrt
      
      ; Restore registers
      POP   R17
      POP   R16
      RET

;================================================================
; Send command to LCD
; Parameter: R24 = command byte
;================================================================
LCD_command_asm:
      ; Save used registers
      PUSH  R16
      PUSH  R27
      
      ; Move parameter to R16
      MOV   R16, R24
      
      ; Send command
      RCALL command_wrt
      
      ; Restore registers
      POP   R27
      POP   R16
      RET

;================================================================
; Send data to LCD
; Parameter: R24 = data byte
;================================================================
LCD_data_asm:
      ; Save used registers
      PUSH  R16
      PUSH  R27
      
      ; Move parameter to R16
      MOV   R16, R24
      
      ; Send data
      RCALL data_wrt
      
      ; Restore registers
      POP   R27
      POP   R16
      RET

;================================================================
; Update LCD with temperature
; Parameter: R24 = temperature value
;================================================================
LCD_update_temp_asm:
      ; Save used registers
      PUSH  R16
      PUSH  R17
      PUSH  R18
      PUSH  R27
      
      ; Move parameter to R18
      MOV   R18, R24
      
      ; Clear display
      LDI   R16, 0x01
      RCALL command_wrt
      RCALL delay_ms
      
      ; Set cursor to first position
      LDI   R16, 0x80
      RCALL command_wrt
      
      ; Display "Temp: "
      LDI   R16, 'T'
      RCALL data_wrt
      LDI   R16, 'e'
      RCALL data_wrt
      LDI   R16, 'm'
      RCALL data_wrt
      LDI   R16, 'p'
      RCALL data_wrt
      LDI   R16, ':'
      RCALL data_wrt
      LDI   R16, ' '
      RCALL data_wrt
      
      ; Convert temperature to ASCII digits
      MOV   R16, R18
      LDI   R17, 10
      RCALL div_mod         ; R16 = tens, R17 = ones
      
      ; Display tens digit
      SUBI  R16, -'0'       ; Convert to ASCII
      RCALL data_wrt
      
      ; Display ones digit
      MOV   R16, R17
      SUBI  R16, -'0'       ; Convert to ASCII
      RCALL data_wrt
      
      ; Display degree symbol and C
      LDI   R16, 0xDF       ; Degree symbol
      RCALL data_wrt
      LDI   R16, 'C'
      RCALL data_wrt
      
      ; Restore registers
      POP   R27
      POP   R18
      POP   R17
      POP   R16
      RET

;================================================================
; Division for converting temperature to digits
; Input: R16 = dividend, R17 = divisor
; Output: R16 = quotient, R17 = remainder
;================================================================
div_mod:
      PUSH  R18
      CLR   R18
div_loop:
      CP    R16, R17
      BRLO  div_done
      SUB   R16, R17
      INC   R18
      RJMP  div_loop
div_done:
      MOV   R17, R16        ; remainder
      MOV   R16, R18        ; quotient
      POP   R18
      RET

;================================================================
; Command write helper function
;================================================================
command_wrt:
      MOV   R27, R16
      ANDI  R27, 0xF0         ; mask low nibble & keep high nibble
      OUT   PORTD, R27        ; o/p high nibble to port D
      CBI   PORTB, 1          ; RS = 0 for command
      SBI   PORTB, 0          ; EN = 1
      RCALL delay_short       ; widen EN pulse
      CBI   PORTB, 0          ; EN = 0 for H-to-L pulse
      RCALL delay_us          ; delay in micro seconds
      ;----------------------------------------------------
      MOV   R27, R16
      SWAP  R27               ; swap nibbles
      ANDI  R27, 0xF0         ; mask low nibble & keep high nibble
      OUT   PORTD, R27        ; o/p high nibble to port D
      SBI   PORTB, 0          ; EN = 1
      RCALL delay_short       ; widen EN pulse
      CBI   PORTB, 0          ; EN = 0 for H-to-L pulse
      RCALL delay_us          ; delay in micro seconds
      RET

;================================================================
; Data write helper function
;================================================================
data_wrt:
      MOV   R27, R16
      ANDI  R27, 0xF0         ; mask low nibble & keep high nibble
      OUT   PORTD, R27        ; o/p high nibble to port D
      SBI   PORTB, 1          ; RS = 1 for data
      SBI   PORTB, 0          ; EN = 1
      RCALL delay_short       ; make wide EN pulse
      CBI   PORTB, 0          ; EN = 0 for H-to-L pulse
      RCALL delay_us          ; delay in micro seconds
      ;----------------------------------------------------
      MOV   R27, R16
      SWAP  R27               ; swap nibbles
      ANDI  R27, 0xF0         ; mask low nibble & keep high nibble
      OUT   PORTD, R27        ; o/p high nibble to port D
      SBI   PORTB, 0          ; EN = 1
      RCALL delay_short       ; widen EN pulse
      CBI   PORTB, 0          ; EN = 0 for H-to-L pulse
      RCALL delay_us          ; delay in micro seconds
      RET

;================================================================
; Delay functions
;================================================================
delay_short:
      NOP
      NOP
      RET

delay_us:
      LDI   R20, 90
delay_us_loop:
      RCALL delay_short
      DEC   R20
      BRNE  delay_us_loop
      RET

delay_ms:
      LDI   R21, 40
delay_ms_loop:
      RCALL delay_us
      DEC   R21
      BRNE  delay_ms_loop
      RET