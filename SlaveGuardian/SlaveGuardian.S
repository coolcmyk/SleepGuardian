;============================================================
; SleepGuardian - ATmega328P: DHT11 Sensor → SPI Slave
; Group 23 - 2025 | LED on PC0 | DHT11 Data on PB1 | SPI on dedicated pins
;============================================================

#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global slave_main
.global setTemperature

; External C functions for debugging
.extern printDebug
.extern printValue

; Debug message strings
msg_start:      .asciz "Starting DHT11 reading..."
msg_success:    .asciz "Successfully read temperature"
msg_error:      .asciz "Error reading DHT11"

;============================================================
; MAIN ROUTINE
;============================================================
slave_main:
    ; Initialize Timer0 for precise delays
    LDI     R16, (1<<WGM01)      ; CTC mode
    OUT     TCCR0A, R16

    ; Setup I/O pins
    LDI     R16, (1 << PC0)
    OUT     DDRC, R16            ; Set PC0 (LED) as output
    CBI     PORTC, PC0           ; LED OFF initially
    
    ; Load debug message start address and call debug print
    LDI     R30, lo8(msg_start)
    LDI     R31, hi8(msg_start)
    CALL    printDebug
    
    ; Temp storage register
    LDI     R17, 0               ; Default temp value
    
main_loop:
    RCALL   delay_2s             ; ≈2s delay between readings

    ; --- DHT11 Start Signal ---
    SBI     DDRB, 1              ; Set PB1 as output
    CBI     PORTB, 1             ; Pull LOW
    RCALL   delay_20ms           ; Wait 20ms
    SBI     PORTB, 1             ; Release HIGH
    
    ; Short delay before switching to input
    NOP
    NOP
    NOP
    
    ; --- Wait for DHT11 Response ---
    CBI     DDRB, 1              ; PB1 as input
    
    ; Enable pull-up resistor (CRITICAL FIX!)
    SBI     PORTB, 1             ; Enable pull-up on PB1
    
wait_resp_low:
    SBIC    PINB, 1
    RJMP    wait_resp_low        ; Wait for DHT11 low pulse
    
wait_resp_high:
    SBIS    PINB, 1
    RJMP    wait_resp_high       ; Wait for DHT11 high pulse
    
wait_data_start:
    SBIC    PINB, 1
    RJMP    wait_data_start      ; Wait for DHT11 low pulse again
    
    ; Blink LED to indicate start of reading
    SBI     PORTC, PC0
    RCALL   delay_50us
    CBI     PORTC, PC0

    ; --- Read Data from DHT11 ---
    RCALL   DHT11_read_byte       ; Humidity int - store in R19
    MOV     R19, R18
    RCALL   DHT11_read_byte       ; Humidity frac (discard)
    RCALL   DHT11_read_byte       ; Temperature int → R18  
    MOV     R17, R18              ; Store temp in R17
    
    ; Only proceed if reading looks valid
    CPI     R17, 0
    BREQ    reading_error
    CPI     R17, 80              ; Check if temp is reasonable (<80°C)
    BRSH    reading_error

    ; Debugging: After reading temperature
    LDI     R30, lo8(msg_success)
    LDI     R31, hi8(msg_success)
    CALL    printDebug

    ; --- LED Control Based on Temp ---
    CPI     R17, 26               ; Compare temp < 26°C?
    BRLO    turn_on_led
    RJMP    turn_off_led

turn_on_led:
    SBI     PORTC, PC0            ; Turn on LED (low temp indicator)
    RJMP    update_temp_for_spi

turn_off_led:
    CBI     PORTC, PC0            ; Turn off LED (high temp)
    ; Fall through to update temp

update_temp_for_spi:
    ; CRITICAL FIX: Blink LED rapidly to indicate successful reading
    SBI     PORTC, PC0            ; Turn ON LED
    RCALL   delay_50us
    CBI     PORTC, PC0            ; Turn OFF LED
    RCALL   delay_50us
    SBI     PORTC, PC0            ; Turn ON LED
    RCALL   delay_50us
    CBI     PORTC, PC0            ; Turn OFF LED
    
    ; Restore LED state based on temperature
    CPI     R17, 26
    BRLO    restore_led_on
    RJMP    continue_update

restore_led_on:
    SBI     PORTC, PC0            ; Turn LED back on if temp was low

continue_update:
    ; Sanity check the reading
    CPI     R17, 0                ; Check if reading is zero (error)
    BREQ    use_default
    CPI     R17, 100              ; Check if reading is unreasonably high
    BRSH    use_default
    RJMP    valid_reading         ; Reading looks valid
    
use_default:
    ; Use a value that won't be confused with an error
    LDI     R17, 23               ; Default to 23°C

valid_reading:
    ; CRITICAL FIX: Make the actual temperature different from 1
    ; This confirms if SPI is working by using a distinct value
    CPI     R17, 1
    BRNE    skip_value_fix
    LDI     R17, 42               ; Use 42°C instead of 1°C to distinguish from error
    
skip_value_fix:
    ; Pass temperature to C function
    MOV     R24, R17              ; Pass temperature as parameter
    CALL    setTemperature        ; Call C function to update shared variable
    
    ; Go back to main loop for next temp reading
    RJMP    main_loop

reading_error:
    ; Debug message for error
    LDI     R30, lo8(msg_error)
    LDI     R31, hi8(msg_error)
    CALL    printDebug
    
    ; Flash LED rapidly to indicate error
    LDI     R20, 5               ; Flash 5 times
error_flash:
    SBI     PORTC, PC0           ; LED ON
    RCALL   delay_50us
    CBI     PORTC, PC0           ; LED OFF
    RCALL   delay_50us
    DEC     R20
    BRNE    error_flash
    
    ; Use previous value or default
    LDI     R17, 23              ; Default to 23°C only on error
    
    RJMP    update_temp_for_spi

;============================================================
; DHT11_read_byte - Reads 1 byte from DHT11 into R18
; Using reference implementation approach
;============================================================
DHT11_read_byte:
    LDI   R17, 8        ; Set counter for receiving 8 bits
    CLR   R18           ; Clear data register
    
bit_loop:
    ; Wait for rising edge (start of bit)
wait_bit_rise:
    SBIS  PINB, PB1     ; Skip if PB1 is high
    RJMP  wait_bit_rise ; Loop until PB1 becomes high
    
    ; Wait 50us then check if bit is still high (1) or low (0)
    RCALL delay_50us
    
    ; If pin is still high after 50us, it's a 1 bit
    SBIS  PINB, PB1     ; Skip if PB1 is high (1 bit)
    RJMP  zero_bit      ; PB1 is low = 0 bit
    
    ; Process 1 bit
    SEC                 ; Set carry flag (C=1)
    ROL   R18           ; Shift carry (1) into LSB
    RJMP  wait_bit_fall
    
zero_bit:
    LSL   R18           ; Shift 0 into LSB
    
wait_bit_fall:
    ; Wait for falling edge (end of bit)
    SBIC  PINB, PB1     ; Skip if PB1 is low
    RJMP  wait_bit_fall ; Loop until PB1 becomes low
    
    DEC   R17           ; Decrement bit counter
    BRNE  bit_loop      ; Continue until all 8 bits read
    RET

;============================================================
; Delay ~50 µs via Timer0 CTC Mode
;============================================================
delay_50us:
    CLR     R20
    OUT     TCNT0, R20           ; Initialize timer0 with count=0
    LDI     R20, 100
    OUT     OCR0A, R20           ; OCR0A = 100
    LDI     R20, 0b00001010      ; CTC mode, prescaler 8
    OUT     TCCR0B, R20
    
wait_timer0:
    IN      R20, TIFR0           ; Get TIFR0 byte & check
    SBRS    R20, OCF0A           ; Skip if OCF0A=1 (compare match)
    RJMP    wait_timer0          ; Keep checking
    
    CLR     R20
    OUT     TCCR0B, R20          ; Stop Timer0
    
    LDI     R20, (1<<OCF0A)
    OUT     TIFR0, R20           ; Clear OCF0A flag
    RET

;============================================================
; delay_20ms - Software delay ~20ms (@16 MHz)
;============================================================
delay_20ms:
    LDI     R20, 255
d20_loop1:
    LDI     R21, 210
d20_loop2:
    LDI     R22, 2
d20_loop3:
    DEC     R22
    BRNE    d20_loop3
    DEC     R21
    BRNE    d20_loop2
    DEC     R20
    BRNE    d20_loop1
    RET

;============================================================
; delay_2s - Software delay ~2 seconds (@16 MHz)
;============================================================
delay_2s:
    LDI     R20, 255
d2_loop1:
    LDI     R21, 255
d2_loop2:
    LDI     R22, 164
d2_loop3:
    DEC     R22
    BRNE    d2_loop3
    DEC     R21
    BRNE    d2_loop2
    DEC     R20
    BRNE    d2_loop1
    RET
