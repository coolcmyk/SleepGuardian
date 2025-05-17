#include <avr/io.h>

; Export the assembly functions to be called from C
.global setup_ports
.global init_serial
.global main_logic

; Constants
.equ UBRR_VALUE, 103          ; UBRR value for 9600 baud at 16MHz (16000000/16/9600-1)

; Variables in data segment
.section .data
timer_count:     .byte 1      ; Timer counter
system_active:   .byte 0      ; 0 = inactive, 1 = active
alarm_triggered: .byte 0      ; 0 = not triggered, 1 = triggered
ldr_threshold:   .word 200    ; LDR threshold value (2.0 * 100)

; Code segment
.section .text

; setup_ports - Initialize the I/O ports
setup_ports:
    ; Save used registers
    push r16
    
    ; Configure ADC
    ldi r16, (1 << REFS0)     ; AVCC as reference voltage
    sts ADMUX, r16
    
    ldi r16, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0) ; Enable ADC, prescaler 128
    sts ADCSRA, r16
    
    ; Set PB5 (Buzzer) as output
    in r16, DDRB
    ori r16, (1 << 5)         ; PB5 as output
    out DDRB, r16
    in r16, PORTB
    andi r16, ~(1 << 5)       ; Initialize buzzer off
    out PORTB, r16
    
    ; Set PD3 (Red LED) as output
    in r16, DDRD
    ori r16, (1 << 3)         ; PD3 as output
    out DDRD, r16
    in r16, PORTD
    andi r16, ~(1 << 3)       ; Initialize LED off
    out PORTD, r16
    
    ; Configure PC0 (A0 - LDR) as input
    in r16, DDRC
    andi r16, ~(1 << 0)       ; PC0 as input
    out DDRC, r16
    
    ; Configure PC1 (A1 - Start Button) as input with pull-up
    in r16, DDRC
    andi r16, ~(1 << 1)       ; PC1 as input
    out DDRC, r16
    in r16, PORTC
    ori r16, (1 << 1)         ; Enable pull-up
    out PORTC, r16
    
    ; Configure PD2 (INT0 - Reset Button) as input
    ; (Pull-up is external according to requirements)
    in r16, DDRD
    andi r16, ~(1 << 2)       ; PD2 as input
    out DDRD, r16
    
    ; Restore registers
    pop r16
    ret

; init_serial - Initialize the serial communication
init_serial:
    ; Save used registers
    push r16
    push r17
    
    ; Set baud rate
    ldi r16, lo8(UBRR_VALUE)
    ldi r17, hi8(UBRR_VALUE)
    sts UBRR0H, r17
    sts UBRR0L, r16
    
    ; Enable transmitter
    ldi r16, (1 << TXEN0)
    sts UCSR0B, r16
    
    ; Set frame format: 8 data bits, 1 stop bit, no parity
    ldi r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts UCSR0C, r16
    
    ; Restore registers
    pop r17
    pop r16
    ret

; read_adc - Read ADC value from specified channel
; Input: r24 = ADC channel (0-7)
; Output: r25:r24 = ADC result
read_adc:
    ; Save used registers
    push r16
    
    ; Set ADC channel (preserve REFS bits)
    lds r16, ADMUX
    andi r16, 0xF0           ; Clear lower 4 bits
    or r16, r24              ; Set channel
    sts ADMUX, r16
    
    ; Start conversion
    lds r16, ADCSRA
    ori r16, (1 << ADSC)
    sts ADCSRA, r16
    
    ; Wait for conversion to complete
adc_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_wait
    
    ; Read ADC result
    lds r24, ADCL
    lds r25, ADCH
    
    ; Restore registers
    pop r16
    ret

; send_byte - Send a single byte to serial
; Input: r24 = byte to send
send_byte:
    ; Save used registers
    push r16
    
    ; Wait until UDR0 is ready for data
tx_wait:
    lds r16, UCSR0A
    sbrs r16, UDRE0
    rjmp tx_wait
    
    ; Send character
    sts UDR0, r24
    
    ; Restore registers
    pop r16
    ret

; Function to send a string from program memory
; Input: Z = pointer to string in program memory
send_string:
    ; Save used registers
    push r16
    push r24
    push r30
    push r31
    
send_string_loop:
    ; Load character from program memory
    lpm r24, Z+
    
    ; Check for end of string (0)
    cpi r24, 0
    breq send_string_done
    
    ; Send the character
    rcall send_byte
    
    ; Continue loop
    rjmp send_string_loop
    
send_string_done:
    ; Restore registers
    pop r31
    pop r30
    pop r24
    pop r16
    ret

; delay_ms - Delay for a specified number of milliseconds
; Input: r24 = number of milliseconds
delay_ms:
    ; Save used registers
    push r16
    push r17
    
delay_outer:
    ; Inner loop: ~1ms @ 16MHz
    ldi r17, 200
delay_inner:
    ldi r16, 200
    
delay_cycle:
    nop
    nop
    dec r16
    brne delay_cycle
    
    dec r17
    brne delay_inner
    
    dec r24
    brne delay_outer
    
    ; Restore registers
    pop r17
    pop r16
    ret

; convert_and_send_number - Convert a number to ASCII and send it via serial
; Input: r24 = number to send (0-255)
convert_and_send_number:
    ; Save used registers
    push r16
    push r17
    push r18
    push r25
    push r26
    
    ; Check if number is 0
    cpi r24, 0
    brne not_zero
    
    ; Send '0'
    ldi r24, '0'
    rcall send_byte
    rjmp convert_end
    
not_zero:
    ; Convert number to ASCII
    ; r24 = number
    ; r18 = digit count
    ; r26 = temp
    ldi r18, 0         ; Digit count
    mov r26, r24       ; Save original number
    
    ; First, count digits and calculate powers of 10
    mov r24, r26       ; Restore number
    ldi r17, 100       ; Check hundreds
    cp r24, r17
    brlo tens_digit
    
    ; Hundreds digit
    ldi r24, '0'
hundreds_loop:
    inc r24
    sub r26, r17
    cp r26, r17
    brsh hundreds_loop
    ; Send hundreds digit
    rcall send_byte
    
tens_digit:
    ; Tens digit
    mov r24, r26       ; Get remaining value
    ldi r17, 10
    cp r24, r17
    brlo ones_digit
    
    ldi r24, '0'
tens_loop:
    inc r24
    subi r26, 10
    cp r26, r17
    brsh tens_loop
    ; Send tens digit
    rcall send_byte
    
ones_digit:
    ; Ones digit (remaining value in r26)
    mov r24, r26
    subi r24, -'0'     ; Convert to ASCII
    rcall send_byte
    
convert_end:
    ; Restore registers
    pop r26
    pop r25
    pop r18
    pop r17
    pop r16
    ret

; Main logic function called from C
main_logic:
    ; Save used registers
    push r0
    push r1
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21
    push r22
    push r23
    push r24
    push r25
    push r26
    push r27
    push r28
    push r29
    push r30
    push r31
    
    ; Check if system is already alarming
    lds r16, alarm_triggered
    cpi r16, 1
    breq main_logic_end    ; Skip if alarm already triggered
    
    ; Read LDR sensor (A0 - PC0)
    ldi r24, 0            ; ADC0 channel
    rcall read_adc
    
    ; Compare LDR value with threshold (200 = 2.0 * 100)
    lds r16, ldr_threshold
    lds r17, ldr_threshold+1
    cp r24, r16
    cpc r25, r17
    brsh not_dark         ; Branch if LDR >= threshold (not dark enough)
    
    ; Dark enough, now check start button (A1 - PC1)
    in r16, PINC
    sbrs r16, 1               ; Skip if bit is set (button not pressed)
    rjmp button_pressed       ; Button pressed
    rjmp main_logic_end       ; Button not pressed

button_pressed:
    ; Check if system is already active
    lds r16, system_active
    cpi r16, 1
    breq check_timer      ; Skip if already active
    
    ; System not active but conditions met - activate system
    ldi r16, 1
    sts system_active, r16
    
    ; Reset timer
    ldi r16, 0
    sts timer_count, r16
    
    ; Send activation message
    ldi r30, lo8(msg_activated)
    ldi r31, hi8(msg_activated)
    rcall send_string
    
    rjmp main_logic_end
    
check_timer:
    ; System active - increment timer
    lds r16, timer_count
    inc r16
    sts timer_count, r16
    
    ; Send timer value
    ldi r30, lo8(msg_timer)
    ldi r31, hi8(msg_timer)
    rcall send_string
    
    ; Convert timer to ASCII and send
    mov r24, r16
    rcall convert_and_send_number
    
    ; Send newline
    ldi r30, lo8(msg_newline)
    ldi r31, hi8(msg_newline)
    rcall send_string
    
    ; Check if timer reached 10 seconds
    cpi r16, 10
    brlo main_logic_end    ; Not there yet
    
    ; Timer reached 10 seconds - trigger alarm
    ldi r16, 1
    sts alarm_triggered, r16
    
    ; Turn on buzzer
    in r16, PORTB
    ori r16, (1 << 5)
    out PORTB, r16
    
    ; Turn on red LED
    in r16, PORTD
    ori r16, (1 << 3)
    out PORTD, r16
    
    ; Send alarm message
    ldi r30, lo8(msg_alarm)
    ldi r31, hi8(msg_alarm)
    rcall send_string
    
    rjmp main_logic_end
    
not_dark:
    ; Reset system active state if LDR not dark
    ldi r16, 0
    sts system_active, r16
    
main_logic_end:
    ; Delay between checks (100ms, so timer counts in tenth of seconds)
    ldi r24, 100
    rcall delay_ms
    
    ; Restore registers
    pop r31
    pop r30
    pop r29
    pop r28
    pop r27
    pop r26
    pop r25
    pop r24
    pop r23
    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    pop r1
    pop r0
    ret

; Strings in program memory
.section .progmem
msg_activated:
    .ascii "System Activated! Timer starting..."
    .byte 13, 10, 0
msg_timer:
    .ascii "Timer: "
    .byte 0
msg_alarm:
    .ascii "ALARM TRIGGERED!"
    .byte 13, 10, 0
msg_newline:
    .byte 13, 10, 0