;====================================================
; SleepGuardian - Complete Assembly Implementation
;====================================================
#define __SFR_OFFSET 0x00
#include "avr/io.h"

;— Constants —
; SPI related
.equ SS_PIN,         2       ; PB2 (Arduino pin 10)
.equ MOSI_PIN,       3       ; PB3 (Arduino pin 11)
.equ MISO_PIN,       4       ; PB4 (Arduino pin 12)
.equ SCK_PIN,        5       ; PB5 (Arduino pin 13)

; Timing constants
.equ US_COUNT,       90
.equ MS_COUNT,       40
.equ TEMP_UPDATE_TIME, 2     ; seconds between temperature updates

; LCD display related
.equ LCD_EN,         0       ; EN pin on PORTB (LCD Enable)
.equ LCD_RS,         1       ; RS pin on PORTB (Register Select)

; DS3231 RTC related
.equ DS3231_ADDR,    0x68    ; DS3231 I2C address
.equ SDA_PIN,        2       ; PC2 (Analog pin A2) for I2C data
.equ SCL_PIN,        3       ; PC3 (Analog pin A3) for I2C clock
.equ SDA_PORT,       PORTC   ; PORT register for SDA
.equ SCL_PORT,       PORTC   ; PORT register for SCL
.equ SDA_DDR,        DDRC    ; Data direction register for SDA
.equ SCL_DDR,        DDRC    ; Data direction register for SCL
.equ SDA_PIN_REG,    PINC    ; PIN register for SDA

;— Global data addresses —
.equ TEMP_STORAGE,   0x100   ; SRAM address to store temperature

;— Public interface —
.global sleepguardian_main           ; Main entry point
.global request_spi_temperature_asm  ; Get temperature via SPI
.global ds3231_init                  ; Initialize DS3231
.global ds3231_set_time              ; Set time (hours, minutes, seconds)
.global ds3231_set_date              ; Set date (day, date, month, year)
.global ds3231_read_time             ; Read time into SRAM buffer
.global ds3231_read_temp             ; Read temperature

; External LCD and debug functions
.extern LCD_init_asm
.extern LCD_command_asm
.extern LCD_data_asm
.extern LCD_update_temp_asm
.extern debugPrintDateTime    ; Add this line for debug function

;================================================================
; Main entry point - initializes everything and runs the system
;================================================================
sleepguardian_main:
    ; Print welcome banner via serial - handled by Arduino setup
    
    ; Initialize SPI interface
    RCALL spi_init
    
    ; Initialize I2C and DS3231
    RCALL ds3231_init
    
    ; Set initial time and date (in BCD format)
    ; Time (hours:minutes:seconds)
    LDI   R24, 0x00      ; Seconds (00-59 in BCD)
    LDI   R22, 0x30      ; Minutes (00-59 in BCD)  
    LDI   R20, 0x14      ; Hours (00-23 in BCD)
    RCALL ds3231_set_time
    
    ; Date (day, date, month, year)
    LDI   R24, 0x06      ; Day of week (1=Sunday, 7=Saturday)
    LDI   R22, 0x18      ; Day of month (01-31 in BCD)
    LDI   R20, 0x05      ; Month (01-12 in BCD)
    LDI   R18, 0x25      ; Year (00-99 in BCD)
    RCALL ds3231_set_date
    
    ; Initialize LCD
    CALL  LCD_init_asm
    
    ; Show initial welcome message
    RCALL display_welcome
    
    ; Main loop - continuously read temperature and update display
main_loop:
    ; Request temperature via SPI or from DS3231
    LDI   R16, 0             ; 0 = use SPI, 1 = use RTC
    CPI   R16, 0
    BREQ  read_spi_temp
    
    ; Read from DS3231
    RCALL ds3231_read_temp
    RJMP  temp_read_done
    
read_spi_temp:
    ; Read from SPI
    RCALL request_spi_temperature_asm
    
temp_read_done:
    ; Temperature is now in R24, save it
    MOV   R16, R24
    
    ; Double the temperature value to fix the scaling issue
    LSL   R24        ; Logical shift left = multiply by 2
    
    ; Set to first line, first position
    LDI   R24, 0x80
    CALL  LCD_command_asm
    
    ; Display "Temp: "
    LDI   R24, 'T'
    CALL  LCD_data_asm
    LDI   R24, 'e'
    CALL  LCD_data_asm
    LDI   R24, 'm'
    CALL  LCD_data_asm
    LDI   R24, 'p'
    CALL  LCD_data_asm
    LDI   R24, ':'
    CALL  LCD_data_asm
    LDI   R24, ' '
    CALL  LCD_data_asm
    
    ; Update LCD with temperature
    MOV   R24, R16
    LSL   R24        ; Multiply by 2 again (to restore the double)
    CALL  LCD_update_temp_asm
    
    ; Read time and date from RTC
    RCALL ds3231_read_time
    
    ; Display date and time on second line
    RCALL display_date_time
    
    ; Wait before next reading
    LDI   R17, TEMP_UPDATE_TIME
delay_loop:
    RCALL delay_seconds
    DEC   R17
    BRNE  delay_loop
    
    ; Repeat forever
    RJMP  main_loop

;================================================================
; SPI Initialization Function
;================================================================
spi_init:
    ; Configure SPI pins
    SBI   DDRB, MOSI_PIN     ; MOSI as OUTPUT
    CBI   DDRB, MISO_PIN     ; MISO as INPUT  
    SBI   DDRB, SCK_PIN      ; SCK as OUTPUT
    SBI   DDRB, SS_PIN       ; SS as OUTPUT
    SBI   PORTB, SS_PIN      ; SS HIGH initially
    
    ; Configure SPI: Enable, Master mode, Clock / 16
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16
    
    RET

;================================================================
; Display welcome message on LCD
;================================================================
display_welcome:
    ; Clear display first
    LDI   R24, 0x01
    CALL  LCD_command_asm
    RCALL delay_ms
    
    ; Set to first line, first position
    LDI   R24, 0x80
    CALL  LCD_command_asm
    
    ; Display "SleepGuardian" on first line
    LDI   R24, 'S'
    CALL  LCD_data_asm
    LDI   R24, 'l'
    CALL  LCD_data_asm
    LDI   R24, 'e'
    CALL  LCD_data_asm
    LDI   R24, 'e'
    CALL  LCD_data_asm
    LDI   R24, 'p'
    CALL  LCD_data_asm
    LDI   R24, 'G'
    CALL  LCD_data_asm
    LDI   R24, 'u'
    CALL  LCD_data_asm
    LDI   R24, 'a'
    CALL  LCD_data_asm
    LDI   R24, 'r'
    CALL  LCD_data_asm
    LDI   R24, 'd'
    CALL  LCD_data_asm
    LDI   R24, 'i'
    CALL  LCD_data_asm
    LDI   R24, 'a'
    CALL  LCD_data_asm
    LDI   R24, 'n'
    CALL  LCD_data_asm
    
    ; Set to second line, first position
    LDI   R24, 0xC0
    CALL  LCD_command_asm
    
    ; Display "v1.0" on second line
    LDI   R24, 'v'
    CALL  LCD_data_asm
    LDI   R24, '1'
    CALL  LCD_data_asm
    LDI   R24, '.'
    CALL  LCD_data_asm
    LDI   R24, '0'
    CALL  LCD_data_asm
    
    ; Short delay to show welcome message
    LDI   R17, 4
welcome_delay:
    RCALL delay_seconds
    DEC   R17
    BRNE  welcome_delay
    
    RET

;================================================================
; Request temperature via SPI
; Returns temperature in R24
;================================================================
request_spi_temperature_asm:
    PUSH  R16
    PUSH  R17
    PUSH  R20
    PUSH  R21
    
    ; Try up to 3 times to get valid reading
    LDI   R20, 3
    
retry_spi:
    ; Select slave (SS low)
    CBI   PORTB, SS_PIN
    
    ; Small delay for slave to prepare
    LDI   R21, 40
us_delay_loop:
    NOP
    NOP
    NOP
    DEC   R21
    BRNE  us_delay_loop
    
    ; Send command 0x00
    LDI   R16, 0x00
    OUT   SPDR, R16
    
    ; Wait for transfer to complete
wait_spi:
    IN    R17, SPSR
    SBRS  R17, SPIF
    RJMP  wait_spi
    
    ; Read result
    IN    R16, SPDR
    
    ; Deselect slave (SS high)
    SBI   PORTB, SS_PIN
    
    ; Check if reading is valid (≥ 2)
    CPI   R16, 2
    BRSH  valid_reading
    
    ; Try again if attempts remain
    DEC   R20
    BRNE  retry_spi
    
    ; Default temperature if all attempts fail
    LDI   R16, 25
    
valid_reading:
    ; Store temperature in SRAM for reference
    STS   TEMP_STORAGE, R16
    
    ; Return value in R24 (C calling convention)
    MOV   R24, R16
    
    POP   R21
    POP   R20
    POP   R17
    POP   R16
    RET

;================================================================
; I2C bit-banging implementation
;================================================================
i2c_init:
    ; Configure SDA and SCL as outputs (initially high - idle state)
    SBI   SDA_DDR, SDA_PIN   ; SDA as output
    SBI   SCL_DDR, SCL_PIN   ; SCL as output
    SBI   SDA_PORT, SDA_PIN  ; SDA high
    SBI   SCL_PORT, SCL_PIN  ; SCL high
    RET

i2c_start:
    ; START condition: SDA goes LOW while SCL is HIGH
    SBI   SDA_PORT, SDA_PIN  ; SDA high
    SBI   SCL_PORT, SCL_PIN  ; SCL high
    RCALL i2c_delay
    CBI   SDA_PORT, SDA_PIN  ; SDA low
    RCALL i2c_delay
    CBI   SCL_PORT, SCL_PIN  ; SCL low
    RCALL i2c_delay
    RET

i2c_stop:
    ; STOP condition: SDA goes HIGH while SCL is HIGH
    CBI   SDA_PORT, SDA_PIN  ; SDA low
    RCALL i2c_delay
    SBI   SCL_PORT, SCL_PIN  ; SCL high
    RCALL i2c_delay
    SBI   SDA_PORT, SDA_PIN  ; SDA high
    RCALL i2c_delay
    RET

i2c_write_byte:
    ; R24 contains byte to write
    PUSH  R16
    PUSH  R17
    
    LDI   R16, 8             ; 8 bits to send
    MOV   R17, R24           ; Move data to R17

i2c_write_bit:
    ; Check if current bit is 1 or 0
    ROL   R17                ; Rotate left through carry
    BRCS  i2c_write_one      ; If carry set, write 1
    
    ; Write 0: SDA low
    CBI   SDA_PORT, SDA_PIN
    RJMP  i2c_write_clock
    
i2c_write_one:
    ; Write 1: SDA high
    SBI   SDA_PORT, SDA_PIN
    
i2c_write_clock:
    RCALL i2c_delay
    SBI   SCL_PORT, SCL_PIN  ; SCL high
    RCALL i2c_delay
    CBI   SCL_PORT, SCL_PIN  ; SCL low
    RCALL i2c_delay
    
    DEC   R16
    BRNE  i2c_write_bit
    
    ; Release SDA for ACK
    SBI   SDA_PORT, SDA_PIN
    RCALL i2c_delay
    
    ; Clock for ACK
    SBI   SCL_PORT, SCL_PIN  ; SCL high
    RCALL i2c_delay
    
    ; Read ACK (0 = ACK, 1 = NACK)
    CBI   SDA_DDR, SDA_PIN   ; SDA as input
    RCALL i2c_delay
    
    ; Read SDA pin
    IN    R16, SDA_PIN_REG
    ANDI  R16, (1<<SDA_PIN)
    
    CBI   SCL_PORT, SCL_PIN  ; SCL low
    RCALL i2c_delay
    
    ; Restore SDA as output
    SBI   SDA_DDR, SDA_PIN
    
    ; Return 0 if ACK received (SDA was low)
    MOV   R24, R16
    
    POP   R17
    POP   R16
    RET

i2c_read_byte:
    ; R24 = 0 to ACK after reading, 1 to NACK
    PUSH  R16
    PUSH  R17
    PUSH  R18
    
    MOV   R18, R24           ; Save ACK/NACK flag
    LDI   R17, 0             ; Clear result
    LDI   R16, 8             ; 8 bits to read
    
    ; Release SDA line
    CBI   SDA_DDR, SDA_PIN   ; SDA as input
    
i2c_read_bit:
    RCALL i2c_delay
    SBI   SCL_PORT, SCL_PIN  ; SCL high
    RCALL i2c_delay
    
    ; Read bit
    LSL   R17                ; Shift left
    IN    R24, SDA_PIN_REG
    SBRC  R24, SDA_PIN
    ORI   R17, 1             ; Set bit 0 if SDA was high
    
    CBI   SCL_PORT, SCL_PIN  ; SCL low
    RCALL i2c_delay
    
    DEC   R16
    BRNE  i2c_read_bit
    
    ; Restore SDA as output
    SBI   SDA_DDR, SDA_PIN
    
    ; Send ACK/NACK
    CPI   R18, 0
    BREQ  i2c_send_ack
    
    ; Send NACK (SDA high)
    SBI   SDA_PORT, SDA_PIN
    RJMP  i2c_ack_clock
    
i2c_send_ack:
    ; Send ACK (SDA low)
    CBI   SDA_PORT, SDA_PIN
    
i2c_ack_clock:
    RCALL i2c_delay
    SBI   SCL_PORT, SCL_PIN  ; SCL high
    RCALL i2c_delay
    CBI   SCL_PORT, SCL_PIN  ; SCL low
    RCALL i2c_delay
    
    ; Return read byte
    MOV   R24, R17
    
    POP   R18
    POP   R17
    POP   R16
    RET

i2c_delay:
    ; Small delay for I2C timing
    PUSH  R16
    LDI   R16, 10
i2c_delay_loop:
    NOP
    DEC   R16
    BRNE  i2c_delay_loop
    POP   R16
    RET

;================================================================
; DS3231 RTC Implementation
;================================================================
ds3231_init:
    ; Initialize I2C bus
    RCALL i2c_init
    RCALL i2c_delay
    
    ; Perform a dummy write to check if device exists
    RCALL i2c_start
    
    ; Send device address (write mode)
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    
    ; Send register address (0x0F - control register)
    LDI   R24, 0x0F
    RCALL i2c_write_byte
    
    ; Read current control value
    RCALL i2c_start
    
    ; Send device address (read mode)
    LDI   R24, ((DS3231_ADDR << 1) | 1)
    RCALL i2c_write_byte
    
    ; Read byte (with NACK)
    LDI   R24, 1
    RCALL i2c_read_byte
    
    ; Save control value
    MOV   R16, R24
    
    ; Stop I2C
    RCALL i2c_stop
    
    ; Set control register - enable oscillator (clear bit 7)
    ANDI  R16, 0x7F
    
    RCALL i2c_start
    
    ; Send device address (write mode)
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    
    ; Send register address (0x0F - control register)
    LDI   R24, 0x0F
    RCALL i2c_write_byte
    
    ; Write control value
    MOV   R24, R16
    RCALL i2c_write_byte
    
    RCALL i2c_stop
    RET

;================================================================
; Set Time (seconds, minutes, hours)
; Parameters: 
;   R24 = seconds in BCD
;   R22 = minutes in BCD
;   R20 = hours in BCD
;================================================================
ds3231_set_time:
    ; Save parameters
    PUSH  R24
    PUSH  R22
    PUSH  R20
    
    ; Start I2C
    RCALL i2c_start
    
    ; Send device address (write mode)
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    
    ; Send register address (0x00 - seconds register)
    LDI   R24, 0x00
    RCALL i2c_write_byte
    
    ; Send seconds
    POP   R20
    POP   R22
    POP   R24
    PUSH  R24
    RCALL i2c_write_byte
    
    ; Send minutes
    MOV   R24, R22
    RCALL i2c_write_byte
    
    ; Send hours
    MOV   R24, R20
    RCALL i2c_write_byte
    
    ; Stop I2C
    RCALL i2c_stop
    
    POP   R24
    RET

;================================================================
; Set Date (day, date, month, year)
; Parameters:
;   R24 = day (1-7)
;   R22 = date in BCD
;   R20 = month in BCD
;   R18 = year in BCD
;================================================================
ds3231_set_date:
    ; Save parameters
    PUSH  R24
    PUSH  R22
    PUSH  R20
    PUSH  R18
    
    ; Start I2C
    RCALL i2c_start
    
    ; Send device address (write mode)
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    
    ; Send register address (0x03 - day register)
    LDI   R24, 0x03
    RCALL i2c_write_byte
    
    ; Send day
    POP   R18
    POP   R20
    POP   R22
    POP   R24
    PUSH  R24
    RCALL i2c_write_byte
    
    ; Send date
    MOV   R24, R22
    RCALL i2c_write_byte
    
    ; Send month
    MOV   R24, R20
    RCALL i2c_write_byte
    
    ; Send year
    MOV   R24, R18
    RCALL i2c_write_byte
    
    ; Stop I2C
    RCALL i2c_stop
    
    POP   R24
    RET

;================================================================
; Read Time (seconds, minutes, hours, day, date, month, year)
; Stores results in SRAM (address defined by .equ)
;================================================================
ds3231_read_time:
    ; Start I2C
    RCALL i2c_start
    
    ; Send device address (write mode)
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    
    ; Send register address (0x00 - seconds register)
    LDI   R24, 0x00
    RCALL i2c_write_byte
    
    ; Restart I2C for reading
    RCALL i2c_start
    
    ; Send device address (read mode)
    LDI   R24, ((DS3231_ADDR << 1) | 1)
    RCALL i2c_write_byte
    
    ; Read seconds (with ACK)
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+1, R24   ; Store seconds at TEMP_STORAGE+1
    
    ; Read minutes (with ACK)
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+2, R24   ; Store minutes at TEMP_STORAGE+2
    
    ; Read hours (with ACK)
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+3, R24   ; Store hours at TEMP_STORAGE+3
    
    ; Read day (with ACK)
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+4, R24   ; Store day at TEMP_STORAGE+4
    
    ; Read date (with ACK)
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+5, R24   ; Store date at TEMP_STORAGE+5
    
    ; Read month (with ACK)
    LDI   R24, 0
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+6, R24   ; Store month at TEMP_STORAGE+6
    
    ; Read year (with NACK)
    LDI   R24, 1
    RCALL i2c_read_byte
    STS   TEMP_STORAGE+7, R24   ; Store year at TEMP_STORAGE+7
    
    ; Stop I2C
    RCALL i2c_stop
    RET

;================================================================
; Read Temperature from DS3231
; Returns temperature value in R24
;================================================================
ds3231_read_temp:
    ; Start I2C
    RCALL i2c_start
    
    ; Send device address (write mode)
    LDI   R24, (DS3231_ADDR << 1)
    RCALL i2c_write_byte
    
    ; Send register address (0x11 - temperature register)
    LDI   R24, 0x11
    RCALL i2c_write_byte
    
    ; Restart I2C for reading
    RCALL i2c_start
    
    ; Send device address (read mode)
    LDI   R24, ((DS3231_ADDR << 1) | 1)
    RCALL i2c_write_byte
    
    ; Read temperature (with NACK)
    LDI   R24, 1
    RCALL i2c_read_byte
    
    ; Save temperature value
    MOV   R16, R24
    
    ; Stop I2C
    RCALL i2c_stop
    
    ; Return temperature
    MOV   R24, R16
    RET

;================================================================
; Display Date and Time from RTC on LCD
;================================================================
display_date_time:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    
    ; Set to second line, first position
    LDI   R24, 0xC0
    CALL  LCD_command_asm
    
    ; Load month from SRAM
    LDS   R16, TEMP_STORAGE+6
    ; Convert from BCD
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        ; R17 = tens digit
    ANDI  R16, 0x0F        ; R16 = ones digit
    
    ; Display month (add '0' to convert to ASCII)
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; tens digit
    
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; ones digit
    
    ; Display separator
    LDI   R24, '/'
    CALL  LCD_data_asm
    
    ; Load date (day of month) from SRAM
    LDS   R16, TEMP_STORAGE+5
    ; Convert from BCD
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        ; R17 = tens digit
    ANDI  R16, 0x0F        ; R16 = ones digit
    
    ; Display date
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; tens digit
    
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; ones digit
    
    ; Display separator
    LDI   R24, '/'
    CALL  LCD_data_asm
    
    ; Load year from SRAM
    LDS   R16, TEMP_STORAGE+7
    ; Convert from BCD
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        ; R17 = tens digit
    ANDI  R16, 0x0F        ; R16 = ones digit
    
    ; Display "20" prefix for year
    LDI   R24, '2'
    CALL  LCD_data_asm
    LDI   R24, '0'
    CALL  LCD_data_asm
    
    ; Display year
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; tens digit
    
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; ones digit
    
    ; Display space
    LDI   R24, ' '
    CALL  LCD_data_asm
    
    ; Load hours from SRAM
    LDS   R16, TEMP_STORAGE+3
    ; Convert from BCD
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        ; R17 = tens digit
    ANDI  R16, 0x0F        ; R16 = ones digit
    
    ; Display hours
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; tens digit
    
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; ones digit
    
    ; Display separator
    LDI   R24, ':'
    CALL  LCD_data_asm
    
    ; Load minutes from SRAM
    LDS   R16, TEMP_STORAGE+2
    ; Convert from BCD
    MOV   R17, R16
    SWAP  R17
    ANDI  R17, 0x0F        ; R17 = tens digit
    ANDI  R16, 0x0F        ; R16 = ones digit
    
    ; Display minutes
    MOV   R24, R17
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; tens digit
    
    MOV   R24, R16
    ORI   R24, 0x30
    CALL  LCD_data_asm     ; ones digit
    
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

;================================================================
; Delay functions
;================================================================
delay_short:
    NOP
    NOP
    RET

delay_us:
    LDI   R20, US_COUNT
us_loop:
    RCALL delay_short
    DEC   R20
    BRNE  us_loop
    RET

delay_ms:
    LDI   R21, MS_COUNT
ms_loop:
    RCALL delay_us
    DEC   R21
    BRNE  ms_loop
    RET

delay_seconds:
    LDI   R20, 255          ; outer loop counter 
ds_loop1:
    LDI   R21, 255          ; mid loop counter
ds_loop2:
    LDI   R22, 20           ; inner loop counter to give ~0.25s delay
ds_loop3:
    DEC   R22               ; decrement inner loop
    BRNE  ds_loop3          ; loop if not zero
    DEC   R21               ; decrement mid loop
    BRNE  ds_loop2          ; loop if not zero
    DEC   R20               ; decrement outer loop
    BRNE  ds_loop1          ; loop if not zero
    RET                     ; return to caller
