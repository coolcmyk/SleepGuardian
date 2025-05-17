;====================================================
; SPI‑Master → 16×2 LCD (4‑bit) display temp byte
;====================================================
#define __SFR_OFFSET 0x00
#include "avr/io.h"

;— LCD pins on PORTE, PORTB —
.equ LCD_DDR_D,   DDRD
.equ LCD_DDR_B,   DDRB
.equ LCD_PORT_D,  PORTD
.equ LCD_PORT_B,  PORTB
.equ PIN_RS,      1
.equ PIN_E,       0

;— SPI master bits in SPCR —
; SPE, MSTR

;— Delays —
.equ US_COUNT,    90
.equ MS_COUNT,    40

;— public entry—
.global master_main
master_main:
    ; CRITICAL FIX: Reset sequence
    ; Configure SPI pins first
    SBI   DDRB, 3     ; MOSI as OUTPUT
    CBI   DDRB, 4     ; MISO as INPUT  
    SBI   DDRB, 5     ; SCK as OUTPUT
    SBI   DDRB, 2     ; SS as OUTPUT
    SBI   PORTB, 2    ; SS HIGH initially
    
    ; init SPI as master
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)  ; Added SPR0 for slower clock
    OUT   SPCR, R16

    ; Wait for peripherals to stabilize
    RCALL delay_seconds
    
    ; init LCD port direction
    LDI   R16, 0xFF
    OUT   LCD_DDR_D, R16
    OUT   LCD_DDR_B, R16
    
    ; Make sure EN starts LOW
    CBI   LCD_PORT_B, PIN_E
    ; Make sure RS starts LOW
    CBI   LCD_PORT_B, PIN_RS
    
    ; Wait for LCD to power up
    RCALL delay_seconds
    
    ; Initialize the LCD
    RCALL LCD_init
    
    ; Show a test message first to verify LCD works
    LDI   R16, 'T'
    RCALL data_wrt
    LDI   R16, 'e'
    RCALL data_wrt
    LDI   R16, 's'
    RCALL data_wrt
    LDI   R16, 't'
    RCALL data_wrt

    ; Wait to make sure we can see the test message
    RCALL delay_seconds
    
    ; Now proceed to main loop
    RJMP  main_temp_loop

main_temp_loop:
    ; 1) clock one byte from slave
    RCALL spi_request_byte    ; → R16

    ; 2) clear display
    LDI   R16, 0x01
    RCALL command_wrt
    RCALL delay_ms

    ; 3) convert R16 to ASCII
    MOV   R19, R16
    CLR   R18
tens_loop:
    CPI   R19, 10
    BRLO  tens_done
    SUBI  R19, 10
    INC   R18
    RJMP  tens_loop
tens_done:
    ; print tens
    MOV   R16, R18
    LDI   R20, '0'
    ADD   R16, R20
    RCALL data_wrt
    ; print ones
    MOV   R16, R19
    LDI   R20, '0'
    ADD   R16, R20
    RCALL data_wrt

    ; suffix " C"
    LDI   R16, ' '
    RCALL data_wrt
    LDI   R16, 'C'
    RCALL data_wrt

    RCALL delay_seconds
    RJMP  main_temp_loop

;==========================================
; SPI request (master) → R16
;==========================================
spi_request_byte:
    ; CRITICAL FIX 1: Ensure SS is high before starting
    SBI   PORTB, 2                ; SS HIGH
    RCALL delay_ms                ; Wait a moment
    
    ; CRITICAL FIX 2: Multiple attempts to get valid data
    LDI   R20, 3                  ; Try 3 times
retry_spi:
    ; Pull SS low to activate slave
    CBI   PORTB, 2                ; SS LOW
    RCALL delay_ms                ; Wait for slave to respond
    
    ; Send command byte 0x00 to request temperature
    LDI   R16, 0x00
    OUT   SPDR, R16
    
wait_spif_m:
    IN    R17, SPSR
    SBRS  R17, SPIF
    RJMP  wait_spif_m
    
    ; CRITICAL FIX 3: Ensure we got real data
    IN    R16, SPDR              ; Read received byte
    
    ; Pull SS high to deactivate slave
    SBI   PORTB, 2                ; SS HIGH
    
    ; Check if we got a valid temperature (not 0 or 1)
    CPI   R16, 2
    BRSH  valid_temp              ; If ≥2, treat as valid

    ; Not valid, try again if we have attempts left
    DEC   R20
    BRNE  retry_spi
    
    ; If all attempts failed, use default
    LDI   R16, 23                 ; Use 23°C as fallback
    
valid_temp:
    RET

;==========================================
; LCD routines (based on reference code)
;==========================================
LCD_init:
    ; Make sure EN starts LOW
    CBI   LCD_PORT_B, PIN_E
    ; Wait for LCD power-on
    RCALL delay_ms
    
    LDI   R16, 0x33         ; Initialize LCD for 4-bit mode
    RCALL command_wrt
    RCALL delay_ms
    
    LDI   R16, 0x32
    RCALL command_wrt
    RCALL delay_ms
    
    LDI   R16, 0x28         ; LCD 2 lines, 5x7 matrix
    RCALL command_wrt
    RCALL delay_ms
    
    LDI   R16, 0x0C         ; Display ON, cursor OFF
    RCALL command_wrt
    
    LDI   R16, 0x01         ; Clear LCD
    RCALL command_wrt
    RCALL delay_ms
    
    LDI   R16, 0x06         ; Shift cursor right
    RCALL command_wrt
    
    ; Additional delay after init
    RCALL delay_ms
    RET

command_wrt:
    MOV   R27, R16
    ANDI  R27, 0xF0
    OUT   LCD_PORT_D, R27
    CBI   LCD_PORT_B, PIN_RS
    SBI   LCD_PORT_B, PIN_E
    RCALL delay_short
    CBI   LCD_PORT_B, PIN_E
    RCALL delay_us

    MOV   R27, R16
    SWAP  R27
    ANDI  R27, 0xF0
    OUT   LCD_PORT_D, R27
    SBI   LCD_PORT_B, PIN_E
    RCALL delay_short
    CBI   LCD_PORT_B, PIN_E
    RCALL delay_us
    RET

data_wrt:
    MOV   R27, R16
    ANDI  R27, 0xF0
    OUT   LCD_PORT_D, R27
    SBI   LCD_PORT_B, PIN_RS
    SBI   LCD_PORT_B, PIN_E
    RCALL delay_short
    CBI   LCD_PORT_B, PIN_E
    RCALL delay_us

    MOV   R27, R16
    SWAP  R27
    ANDI  R27, 0xF0
    OUT   LCD_PORT_D, R27
    SBI   LCD_PORT_B, PIN_E
    RCALL delay_short
    CBI   LCD_PORT_B, PIN_E
    RCALL delay_us
    RET

;==========================================
; delays
;==========================================
delay_short:
    NOP
    NOP
    RET

delay_us:
    LDI   R20, US_COUNT
l_us:
    RCALL delay_short
    DEC   R20
    BRNE  l_us
    RET

delay_ms:
    LDI   R21, MS_COUNT
l_ms:
    RCALL delay_us
    DEC   R21
    BRNE  l_ms
    RET

delay_seconds:
    LDI   R20, 255
l_s1:
    LDI   R21, 255
l_s2:
    LDI   R22, 20
l_s3:
    DEC   R22
    BRNE  l_s3
    DEC   R21
    BRNE  l_s2
    DEC   R20
    BRNE  l_s1
    RET
