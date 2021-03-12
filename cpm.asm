; This monitor & loader has two functions:
; (1) The monitor part enables you to view ram, rom and various config parameters.
; (2) The Loader part loads CP/M

; CP/M v2.2 was implemented at the BDOS level by John Squires.
; The CORE, BIOS & BDOS are my own work.
;
; How the CP/M loader works:
; The 4 main sections need to end up at the top of memory.
; For now let's say at $C000, $D000 and $E000 & $F000.
; The CORE goes at the top of ram. This contains the routines to use the hardware.
; The BIOS is just a stub of a BIOS and does very little.
; The BDOS is the heart of CP/M and implements all the function.
; The CCP is the face of CP/M. The current one is the original from Digital Research 1978.
; In order to load CP/M we need a loader that grabs them from somewhere and copies them
; to those locations. That loader is this program, and is located in ROM at $0000.
; The CP/M loader's job is to:
; (1) Configure the Z80 Playground.
; (2) Load the CORE and BIOS from disk and put them in their corresponding locations.
; (3) Put the tiny jump table in place at the bottom of memory.
; (4) Switch off the ROM.
; (5) Jump into CP/M by calling BIOS cold boot.
; From there the BIOS loads the BDOS & CCP.

    org $0000

loader_entry:
    di
    ld sp, loader_stack
    jp skip_over_int_and_nmi

; INT routine. This runs when you press the /INT button. All it does is toggle the USER led.
	org $0038
int:
	ex af, af'
	exx
	call disk_toggle
	call short_pause
	exx
	ex af, af'
	ei
	reti

; NMI routine	
	org $0066
nmi:
	ex af, af'
	exx
	call user_toggle
	call short_pause
	exx
	ex af, af'
	retn

skip_over_int_and_nmi:
    ld b, $01                   ; 460,800 baud
    ld c, $00                   ; No flow control
    call configure_uart         ; Put these settings into the UART

    call message
   	db 27,'[2J',27,'[H'
    db 'Z80 Playground Monitor & CP/M Loader v1.03',13,10,0

    ; Check MCR
    ld a, %00100010
    out (uart_MCR), a
    call message
    db '16C550: ',0
    in a, (uart_MCR)
    call show_a_as_hex
    call newline

    call message
    db 'Configure USB Drive...',13,10,0
    call configure_memorystick
    call message
    db 'Check CH376 module exists...',13,10,0
    call check_module_exists
    call message
    db 'Get CH376 module version...',13,10,0
    call get_module_version

    ; Now read the baud rate configuration from uart.cfg
    ld a, $FF 
    ld (baud_rate_divisor), a           ; Reset the two UART parameters
    ld (flow_control_value), a
    ld hl, UART_CFG_NAME
    call load_config_file
    call parse_uart_config_file         ; this gets b=baud and c=flowcontrol

    ld a, (baud_rate_divisor)           ; Check if we managed to get both baudrate and flowcontrol
    cp $FF
    jr z, failed_to_read_uart_config    ; If not, don't reconfigure uart
    ld b, a

    ld a, (flow_control_value)
    cp $FF
    jr z, failed_to_read_uart_config
    ld c, a

    call message
    db 'Configuring UART to settings in UART.CFG',13,10,0

    push bc
    call message 
    db 'BAUD ',0
    ld a, b
    call show_a_as_hex
    pop bc

    push bc
    call message 
    db ', FLOW ',0
    ld a, c
    call show_a_as_hex
    call newline
    pop bc

    ;call configure_uart                 ; Put these settings into the UART
    jp start_monitor

failed_to_read_uart_config:
    call message
    db 'Could not read UART.CFG',13,10,0

start_monitor:
    jp monitor_start

start_cpm:
    call message
    db 'Checking disks...',13,10,0
    call check_cpmdisks_structure

    ; Copy 8 byte bootstrap sequence into Low Storage at location 0
    ; but note that we patch it up in a bit with the real jump locations.
    ld de, 0
    ld hl, first_eight_bytes
    ld bc, 8
    ldir

    ; Load CPM config file into memory
    ld hl, CPM_CFG_NAME
    call load_config_file
    ; Parse it to get out the locations
    call parse_cpm_config_file
    call show_config    
    call validate_config

    ; Load CORE.BIN into its proper location
    ld hl, NAME_OF_CORE
    call copy_filename_to_buffer
    ld de, (core_location)
    call load_bin_file
    call message
    db 'CORE loaded!',13,10,0

    ; Load the BIOS to the proper location
    ld hl, NAME_OF_BIOS
    call copy_filename_to_buffer
    ld de, (bios_location)
    call load_bin_file
    call message
    db 'BIOS loaded!',13,10,0

    ; copy bios_start into bytes 1 & 2 after adding 3 to it
    ld hl, (bios_location)
    inc hl
    inc hl
    inc hl                              ; hl now point to BIOS warm boot
    ld (1), hl

    ; copy bdos_start into bytes 6 & 7
    ld hl, (bdos_location)
    ld (6), hl

    ; OK, let's go!
    ld hl, (bios_location)
    jp (hl) ; BIOS COLD BOOT - Note that this is PC=HL not PC=(HL). Confusing eh?
    halt    ; Just in case we ever get back here somehow


load_config_file:
    call message
    db 'Loading config file...',13,10,0
    ; Opens the file such as /CPM/cpm.cfg or /CPM/uart.cfg. Point to one of these names in hl.
    ; Read it into an area of memory starting at config_file_loc
    ; and puts \0 at the end so we can spot the end of the file later
    call copy_filename_to_buffer
    ld de, config_file_loc             
    call load_bin_file                      ; hl comes back with end location of file. Z set if success.
    jp nz, load_config_file_error
    ld (hl), 0
    ret

parse_cpm_config_file:
    call message
    db 'Parsing the CPM config file...',13,10,0
    ; Go through the config file one line at a time.
    ; If we encounter a \0 then the file has ended.
    ; If a line starts with ";" then ignore it.
    ; If a line starts with "CORE" then read in the bex value for CORE_START
    ld hl, config_file_loc
parse_cpm_config_file_loop:
    call has_file_ended
    jp z, parse_config_file_end

    call is_this_line_a_comment
    jp nz, not_a_comment
    call go_to_next_line
    jr parse_cpm_config_file_loop

not_a_comment:
    call is_this_line_the_core_location
    jr nz, not_core_location
    ld de, core_location
consume_location:
    call parse_4_digit_hex_value
    call go_to_next_line
    jr parse_cpm_config_file_loop

not_core_location:
    call is_this_line_the_bios_location
    jr nz, not_bios_location
    ld de, bios_location
    jr consume_location

not_bios_location:
    call is_this_line_the_bdos_location
    jr nz, not_bdos_location
    ld de, bdos_location
    jr consume_location

not_bdos_location:
    call is_this_line_the_ccp_location
    jr nz, not_ccp_location
    ld de, ccp_location
    jr consume_location

not_ccp_location:
    call is_this_line_the_ccp_name
    jr nz, not_ccp_name
    ld de, ccp_name
    jr consume_name

not_ccp_name:
    ; Unknown line so ignore it
    call go_to_next_line
    jp parse_cpm_config_file_loop

consume_name:
    ; hl points to the name in the file
    ; de points to where we want to store it
    call parse_name
    call go_to_next_line
    jr parse_cpm_config_file_loop

parse_config_file_end:
    ret

load_config_file_error:
    call message
    db 'Error loading config file',13,10,0
    halt

parse_name:
    ; hl = current location in file
    ; de = where we want to put the parsed filename
    ld b, 9                 ; max 8 chars in filename
parse_name_loop:
    call get_cfg_char
    cp ' '+1
    jp c, bad_hex_digit
    cp '.'
    jr z, parse_extension
    ld (de), a
    inc de
    djnz parse_name_loop
    jp bad_hex_digit
parse_extension:
    ld a, '.'
    ld (de), a
    inc de

    ld b, 3                 ; max 3 chars in filename
parse_extension_loop:
    call get_cfg_char
    cp ' '+1
    jr c, parse_name_done
    ld (de), a
    inc de
    djnz parse_extension_loop
    ; fall through to...

parse_name_done:
    ld a, 0                         ; null terminator for the name
    ld (de), a
    cp a                            ; Set zero flag for success
    ret

parse_uart_config_file:
    call message
    db 'Parsing the UART config file...',13,10,0
    ; Go through the config file one line at a time.
    ; If we encounter a \0 then the file has ended.
    ; If a line starts with ";" then ignore it.
    ; If a line starts with "BAUD" or "FLOW" then read in the hex value
    ld hl, config_file_loc
parse_uart_config_file_loop:
    call has_file_ended
    jp z, parse_config_file_end

    call is_this_line_a_comment
    jp nz, not_a_uart_comment
    call go_to_next_line
    jr parse_uart_config_file_loop

not_a_uart_comment:
    call is_this_line_the_baud_rate
    jr nz, not_baud_rate
    ld de, baud_rate_divisor
consume_uart_value:
    call parse_2_digit_hex_value
    call go_to_next_line
    jr parse_uart_config_file_loop

not_baud_rate:
    call is_this_line_the_flow_control
    jr nz, not_flow_control
    ld de, flow_control_value
    jr consume_uart_value

not_flow_control:
    ; Unknown line so ignore it
    call go_to_next_line
    jp parse_uart_config_file_loop

parse_4_digit_hex_value:
    ; hl = current location in file
    ; de = where we want to put the parsed value
    ld a, 0                                 ; First, clear out the result area to zeros
    ld (de), a
    inc de
    ld (de), a                              ; de now pointing to high byte of result area

    call get_cfg_char
    call parse_hex_digit
    jp nz, load_config_file_error
    add a, a                                ; a = a * 2
    add a, a                                ; a = a * 4
    add a, a                                ; a = a * 8
    add a, a                                ; a = a * 16
    ld (de), a                              ; Store highest 4 bits of high byte

    call get_cfg_char
    call parse_hex_digit
    jp nz, load_config_file_error
    ld b, a
    ld a, (de)
    add a, b
    ld (de), a                              ; Stored all of high byte now
    dec de                                  ; de now points to low byte of result

    call get_cfg_char
    call parse_hex_digit
    jp nz, load_config_file_error
    add a, a                                ; a = a * 2
    add a, a                                ; a = a * 4
    add a, a                                ; a = a * 8
    add a, a                                ; a = a * 16
    ld (de), a                              ; Store highest 4 bits of low byte

    call get_cfg_char
    call parse_hex_digit
    jp nz, load_config_file_error
    ld b, a
    ld a, (de)
    add a, b
    ld (de), a                              ; Stored all of low byte now

    ret

parse_2_digit_hex_value:
    ; hl = current location in file
    ; de = where we want to put the parsed value
    ld a, 0                                 ; First, clear out the result area to zeros
    ld (de), a

    call get_cfg_char
    call parse_hex_digit
    jp nz, load_config_file_error
    add a, a                                ; a = a * 2
    add a, a                                ; a = a * 4
    add a, a                                ; a = a * 8
    add a, a                                ; a = a * 16
    ld (de), a                              ; Store highest 4 bits of byte

    call get_cfg_char
    call parse_hex_digit
    jp nz, load_config_file_error
    ld b, a
    ld a, (de)
    add a, b
    ld (de), a                              ; Stored all of byte now
    ret

parse_hex_digit:
    ; Parses the hex ascii char in A into a hex value 0-15 in A
    ; returns NZ if not valid
    ; Preserves hl & de
    cp '0'
    jr c, bad_hex_digit
    cp '9'+1
    jr nc, not_09
    sub '0'
    jr parse_hex_digit_done
not_09:
    cp 'A'
    jr c, bad_hex_digit
    cp 'F'+1
    jr nc, not_AZ_uppercase
    sub 55
    jr parse_hex_digit_done
not_AZ_uppercase:
    cp 'a'
    jr c, bad_hex_digit
    cp 'f'+1
    jr nc, bad_hex_digit
    sub 87
    ; fall through to...
parse_hex_digit_done:
    cp a                            ; Set zero flag for success
    ret

bad_hex_digit:
    or 1                            ; clear zero flag for failure
    ret

is_this_line_a_comment:
    ; Check if the line starts with ";"
    ; Returns Z if so.
    ; Always leaves hl at the start of the line
    push hl
    call get_cfg_char
    pop hl
    cp ';'
    ret

is_this_line_the_core_location:
    ; Checks if the line starts with "CORE"
    ; Returns Z if so and leaves hl pointing to the start of the address after the word.
    ; If not returns NZ and leaves hl pointing to the start of the line
    push hl
    call get_cfg_char
    cp 'C'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'O'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'R'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'E'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp ' '
    jp nz, is_this_line_NO
    pop de                          ; throw away the value we pushed
    ret                             ; returns Z

is_this_line_the_baud_rate:
    ; Checks if the line starts with "BAUD"
    ; Returns Z if so and leaves hl pointing to the start of the address after the word.
    ; If not returns NZ and leaves hl pointing to the start of the line
    push hl
    call get_cfg_char
    cp 'B'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'A'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'U'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'D'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp ' '
    jp nz, is_this_line_NO
    pop de                          ; throw away the value we pushed
    ret                             ; returns Z

is_this_line_the_flow_control:
    ; Checks if the line starts with "FLOW"
    ; Returns Z if so and leaves hl pointing to the start of the address after the word.
    ; If not returns NZ and leaves hl pointing to the start of the line
    push hl
    call get_cfg_char
    cp 'F'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'L'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'O'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'W'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp ' '
    jp nz, is_this_line_NO
    pop de                          ; throw away the value we pushed
    ret                             ; returns Z

is_this_line_the_bios_location:
    ; Checks if the line starts with "BIOS "
    ; Returns Z if so and leaves hl pointing to the start of the address after the word.
    ; If not returns NZ and leaves hl pointing to the start of the line
    push hl
    call get_cfg_char
    cp 'B'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'I'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'O'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'S'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp ' '
    jp nz, is_this_line_NO
    pop de
    ret                             ; returns Z

is_this_line_the_bdos_location:
    ; Checks if the line starts with "BDOS "
    ; Returns Z if so and leaves hl pointing to the start of the address after the word.
    ; If not returns NZ and leaves hl pointing to the start of the line
    push hl
    call get_cfg_char
    cp 'B'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'D'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'O'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp 'S'
    jp nz, is_this_line_NO

    call get_cfg_char
    cp ' '
    jp nz, is_this_line_NO
    pop de
    ret                             ; returns Z

is_this_line_the_ccp_location:
    ; Checks if the line starts with "CCPL "
    ; Returns Z if so and leaves hl pointing to the start of the address after the word.
    ; If not returns NZ and leaves hl pointing to the start of the line
    push hl
    call get_cfg_char
    cp 'C'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp 'C'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp 'P'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp 'L'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp ' '
    jr nz, is_this_line_NO
    pop de
    ret                             ; returns Z

is_this_line_the_ccp_name:
    ; Checks if the line starts with "CCPN "
    ; Returns Z if so and leaves hl pointing to the start of the filename after the word.
    ; If not returns NZ and leaves hl pointing to the start of the line
    push hl
    call get_cfg_char
    cp 'C'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp 'C'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp 'P'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp 'N'
    jr nz, is_this_line_NO

    call get_cfg_char
    cp ' '
    jr nz, is_this_line_NO
    pop de
    ret                             ; returns Z

is_this_line_NO:
    pop hl
    or 1                            ; clear zero flag for failure
    ret    

has_file_ended:
    ; The file has ended if the next char is a \0
    ld a, (hl)
    cp 0
    ret

get_cfg_char:
    ; Gets A from the next location in the config file, pointed to by HL.
    ; Increases hl so we skip over the char.
    ; If the char is a \0 then we are at the end of the file, so return \0 and don't increase hl 
    ld a, (hl)
    cp 0                            ; Have we found the end of the file?
    ret z                           ; and return
get_cfg_char1:    
    inc hl
    cp a                            ; Set zero flag for success
    ret

go_to_next_line:
    ld a, (hl)
    cp 0                            ; Have we found the end of the file?
    ret z                           ; if so return

    cp 32
    jr nc, skip_letters
skip_control_chars:
    inc hl
    ld a, (hl)
    cp 0
    ret z
    cp 32
    jr c, skip_control_chars
    ret

skip_letters:
    inc hl
    ld a, (hl)
    cp 0
    ret z
    cp 32
    jr nc, skip_letters
    jr skip_control_chars

show_config:
    call message
    db 'CORE: ',0
    ld hl, (core_location)
    call show_hl_as_hex

    call message
    db ', BIOS: ',0
    ld hl, (bios_location)
    call show_hl_as_hex

    call message
    db ', BDOS: ',0
    ld hl, (bdos_location)
    call show_hl_as_hex

    call message
    db ', CCPL: ',0
    ld hl, (ccp_location)
    call show_hl_as_hex

    call message
    db ', CCPN: ',0
    ld hl, ccp_name
show_name_loop:
    ld a, (hl)
    cp 0
    jr z, finished_showing_name
    push hl
    call print_a
    pop hl
    inc hl
    jr show_name_loop
finished_showing_name:
    call newline
    ret

validate_config:
    ld hl, core_location
    call must_not_be_zero
    ld hl, bios_location
    call must_not_be_zero
    ld hl, bdos_location
    call must_not_be_zero
    ld hl, ccp_location
    call must_not_be_zero
    ret

must_not_be_zero:
    ld a, (hl)
    cp 0
    ret nz
    inc hl
    ld a, (hl)
    cp 0
    ret nz
    call message
    db 'Invalid configuration',13,10,0
    halt



NAME_OF_BDOS:
    db '/BDOS.BIN',0
NAME_OF_BIOS:
    db 'BIOS.BIN',0
NAME_OF_CORE:
    db 'CORE.BIN',0
NAME_OF_CCP:
    db '/CCP.BIN',0

CPM_CFG_NAME:
    db 'CPM.CFG',0
UART_CFG_NAME:
    db 'UART.CFG',0


first_eight_bytes:
    db $C3, $03, $F4, $00, $00, $C3, $00, $EA
; JP BIOS-warm-boot, 0, 0, JP BDOS


filesize_buffer equ $C000

filesize_buffer_copy equ filesize_buffer+6

loader_stack equ filesize_buffer_copy+100


filesize_units:
    ds 1

dma_address:
    ds 2

config_file_loc equ $9000

filename_buffer equ 65535-20
DRIVE_NAME equ filename_buffer-2
disk_buffer equ DRIVE_NAME-36

core_location equ disk_buffer-2         ; Stores the core_start location
bios_location equ core_location-2       ; Stores the bios_start location
bdos_location equ bios_location-2       ; Stores the bdos_start location
ccp_location equ bdos_location-2        ; Stores the ccp_start location
ccp_name equ ccp_location-13            ; stores the name of the ccp file, e.g. MYCCP.BIN with a zero terminator

baud_rate_divisor equ ccp_name-1
flow_control_value equ baud_rate_divisor-1

include "uart.asm"
include "message.asm"
include "memorystick.asm"
include "filesize.asm"
include "monitor.asm"

include "tiny-basic.asm"
include "GOFL.asm"