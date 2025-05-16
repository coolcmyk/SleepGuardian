;--------------------------------------------------------
; SleepGuardian. © 2025 Kelompok 23. All rights reserved.
; DHT11 → 1-LED Controller for ATmega328P
; LED → PC0
; DHT11 data → PB1
;--------------------------------------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;--------------------------------------------------------
.global main
;=================================================================
main:
;------------
    LDI   R16, (1<<PC0)       ; Set PC0 as output (LED)
    OUT   DDRC, R16           ; Configure PORTC
    CBI   PORTC, PC0          ; Initially LED off

main_loop:
    RCALL delay_2s            ; Wait ≈2s between readings

    ;--- Send start signal on PB1 ---
    SBI   DDRB, PB1           ; PB1 as output
    CBI   PORTB, PB1          ; Pull LOW
    RCALL delay_20ms          ; Hold LOW for 20ms
    SBI   PORTB, PB1          ; Release HIGH

    ;--- Switch PB1 to input and wait for DHT11 response ---
    CBI   DDRB, PB1           ; PB1 as input
w1: SBIC  PINB, PB1           ; Wait for initial LOW (80 µs)
    RJMP  w1
w2: SBIS  PINB, PB1           ; Wait for initial HIGH (80 µs)
    RJMP  w2
w3: SBIC  PINB, PB1           ; Wait for next LOW (start of data)
    RJMP  w3

    ;--- Read and discard humidity bytes ---
    RCALL DHT11_reading        ; Byte1 = humidity int (discarded)
    RCALL DHT11_reading        ; Byte2 = humidity frac (discarded)

    ;--- Read temperature integer (byte3) ---
    RCALL DHT11_reading        ; Byte3 = temp int → in R18
    MOV   R16, R18             ; Save temperature in R16

    ;--- Discard remaining bytes ---
    RCALL DHT11_reading        ; Byte4 = temp frac (discarded)
    RCALL DHT11_reading        ; Byte5 = checksum (discarded)

    ;--- LED control logic based on temperature ---
    CPI   R16, 26              ; Compare temperature with 25°C
    BRLO  led_on               ; TEMP < 25 → LED ON
    RJMP  led_off

led_on:
    SBI   PORTC, PC0           ; Turn LED ON
    RJMP  main_loop

led_off:
    CBI   PORTC, PC0           ; Turn LED OFF
    RJMP  main_loop

;=================================================================
; Read one byte from DHT11 into R18
;=================================================================
DHT11_reading:
    LDI   R17, 8               ; 8 bits to read
    CLR   R18                  ; Clear data buffer
;---------------------------------------------------------
read_bit:
    SBIS  PINB, PB1            ; Wait for rising edge
    RJMP  read_bit
    RCALL delay_timer0         ; Wait ≈50 µs
    SBIS  PINB, PB1            ; Check bit value
    RJMP  bit_zero             ; If 0, jump to bit_zero
    SEC                        ; Set carry flag (C=1)
    ROL   R18                  ; Shift carry into data buffer
    RJMP  wait_low             ; Jump to wait for low
bit_zero:
    LSL   R18                  ; Shift in 0 (carry=0)
;---------------------------------------------------------
wait_low:
    SBIC  PINB, PB1            ; Wait for falling edge
    RJMP  wait_low
    DEC   R17                  ; Decrement bit counter
    BRNE  read_bit             ; Read next bit if not done
    RET                        ; Return when all bits read

;=================================================================
; Delay subroutines
;=================================================================
delay_20ms:                    ; ≈20 ms delay (@16 MHz)
    LDI   R20, 255
d20a:LDI   R21, 210
d20b:LDI   R22, 2
d20c:DEC   R22
     BRNE  d20c
     DEC   R21
     BRNE  d20b
     DEC   R20
     BRNE  d20a
    RET

delay_2s:                      ; ≈2 s delay (@16 MHz)
    LDI   R20, 255
d2a: LDI   R21, 255
d2b: LDI   R22, 164
d2c: DEC   R22
     BRNE  d2c
     DEC   R21
     BRNE  d2b
     DEC   R20
     BRNE  d2a
    RET

delay_timer0:                  ; ≈50 µs delay via Timer0 CTC
    CLR   R23
    OUT   TCNT0, R23          ; Initialize timer0 with count=0
    LDI   R23, 100
    OUT   OCR0A, R23          ; OCR0 = 100
    LDI   R23, 0b00001010     ; CTC mode, prescaler=8
    OUT   TCCR0B, R23
dt0:IN    R23, TIFR0          ; Get TIFR0 byte & check
    SBRS  R23, OCF0A          ; If OCF0=1, skip next instruction
    RJMP  dt0                 ; Else, loop back & check OCF0 flag
    CLR   R23
    OUT   TCCR0B, R23         ; Stop timer0
    LDI   R23, (1<<OCF0A)
    OUT   TIFR0, R23          ; Clear OCF0 flag
    RET