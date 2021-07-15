; monitor.asm
; The low-level monitor

monitor_start:
    call monitor_init

monitor_restart:
	call clear_screen
	call show_welcome_message

	; If there is an auto-run-character defined, use that instead of a key press.
	ld a, (auto_run_char)
	cp 0
	jr nz, monitor_loop2

monitor_loop:
	ld a, '>'
	call print_a
monitor_loop1:
	call char_in			; get a char from keyboard
monitor_loop2:
	cp 0					; If it's null, ignore it
	jr z,monitor_loop1
	cp '0'					; '0' = go to page 0
	jr nz,not0
	call goto_page_0
	jp monitor_loop
not0:
	cp 'u'					; User light toggle
	jr nz,notu
	call message
	db 'User LED toggled!',13,10,0
	call user_toggle
	jp monitor_loop
notu:
	cp '3'					; ROM light on
	jr nz,not3
	call message
	db 'ROM light is now ON',13,10,0
	call rom_on
	jp monitor_loop
not3:
	cp '4'					; ROM light off
	jr nz,not4
	call message
	db 'ROM light is now OFF',13,10,0
	call rom_off
	jp monitor_loop
not4:
	cp 'd'					; Disk LED toggle
	jr nz,notd
	call message
	db 'DISK LED toggled!',13,10,0
	call disk_toggle
	jp monitor_loop
notd:
	cp 'h'					; Higher page
	jr nz,noth
	ld a,(current_page)
	inc a
	ld (current_page),a
	call show_page
	jp monitor_loop
noth:
	cp 'l'					; Lower page
	jr nz,notl
	ld a,(current_page)
	dec a
	ld (current_page),a
	call show_page
	jp monitor_loop
notl:
	cp 'm'					; Memory map
	jr nz,notm
	call show_memory_map
	jp monitor_loop

notm:
	cp '/'					; Show Menu
	jr nz,not_slash
	call clear_screen
	call show_welcome_message
	jp monitor_loop

not_slash:
	cp '6'					; Test Uart
	jr nz,not6
	call clear_screen
	call test_uart
	call clear_screen
	call show_welcome_message
	jp monitor_loop

not6:
	cp '#'					; HALT
	jr nz,not_hash
	call message
	db 'HALTing Z80. You will need to press Reset after this!',13,10,0
	halt

not_hash:
	cp 'c'					; CP/M
	jr nz, not_c
    call message 
    db 'Starting CP/M... Make sure you have the "ROM Select" jumper set to "switched".',13,10,0
    jp start_cpm

not_c:
	cp 't'					; Tiny Basic
	jr nz, not_t
    call check_tbasic_structure
    call TBSTART
	jp monitor_restart

not_t:
	cp 'g'					; Game-of-Life
	jr nz, not_g
    call GOFL_Begin
	jp monitor_restart

not_g:
	cp 'b'					; Burn-in test
	jr nz, not_b
    call burn_in
	jp monitor_restart

not_b:
	cp 'j'					; Load jupiter.bin
	jr nz, unknown_char
    jp load_jupiter_ace

unknown_char:
	call print_a			; If we don't understand it, show it!
	call newline
	jp monitor_loop

show_welcome_message:
	call message
	db 13,10
	db 27,'[42m','+------------------+',13,10
	db 27,'[42m','|',27,'[40m','                  ',27,'[42m','|',13,10
	db 27,'[42m','|',27,'[40m','  Z80 Playground  ',27,'[42m','|',13,10
	db 27,'[42m','|',27,'[40m','                  ',27,'[42m','|',13,10
	db 27,'[42m','+------------------+',27,'[40m',13,10,13,10
	db 'Monitor v1.05 February 2021',13,10,13,10
	db 'c = CP/M', 13, 10
	db 't = Tiny Basic',13,10
	db 'g = Game-of-Life',13,10
	db 'm = Memory Map', 13, 10
	db '0 = Show Page 0 of Memory', 13, 10
	db 'h = Move to Higher Page', 13, 10
	db 'l = Move to Lower Page', 13, 10
	db 'u = User LED toggle', 13, 10
	db '3 = ROM ON', 13, 10
	db '4 = ROM OFF', 13, 10
	db 'd = Disk LED toggle', 13, 10
	db '# = Execute HALT instruction',13,10
	db 'b = Run burn-in test',13,10
	db '/ = Show this Menu',13,10
	;db 'j = Poor-Man''s Jupiter Ace',13,10
	db 13,10,0
	ret

monitor_init:
    ; Four flashes on the USER (blue) LED and disk (yellow) LED
    ld b, 4
monitor_init1:
    push bc    
	call user_off
	call disk_on
	call medium_pause
	call user_on
	call disk_off
	call medium_pause
    pop bc
    djnz monitor_init1
	call user_off

    call ram_fill
    ret

ram_fill:
    ; Copy the first 32k of ROM down to RAM
	ld hl,0
	ld de,0
	ld bc, 1024*32
	ldir
    ret

;--------------------------------------------------------------------------------------------------

	; If this memory crosses a 1K memory boundary there is the danger
	; that the memory testing will corrupt the code that is running.
	; If memory map crashes, this is why.
	; TODO: Relocate this code to a safe location, such as 1024.

	db 'DANGER AREA STARTS '

show_memory_map:
	; Look at the first byte of each 1K block.
	; If it is ROM show one char, if RAM show another.
	call clear_screen
	call newline
	ld de,0
	ld b,64
	
map_loop:
	push bc
	
	ld a,(de)			; get initial value
	ld b,a
	
	ld a,0
	ld (de),a			; see if a 0 stores
	ld a,(de)
	cp 0
	jr nz,rom_location
	
	ld a,255
	ld (de),a			; see if a 255 stores
	ld a,(de)
	cp 255
	jr nz,rom_location
	
ram_location:
	call message
	db ' ',0
	jp shown_location
rom_location:
	call message
	db 27,'[41m','R',27,'[0m',0
shown_location:
	
	ld a,b				; restore initial value
	ld (de),a
	
	pop bc
	ld hl, 1024
	add hl,de
	ex de,hl
	djnz map_loop

	call newline
	; Now show a row all of ram
	ld b, 64
ram_loop:
	push bc
	call message
	db 27,'[42m','r',27,'[0m',0
	pop bc
	djnz ram_loop

	call newline
	call message
	db '|       |       |       |       |       |       |       |      |',13,10
	db '0000    2000    4000    6000    8000    A000    C000    E000   FFFF',13,10
	db '0K      8K      16K     24K     32K     40K     48K     56K    64K',13,10,13,10
	db 27,'[41m','R',27,'[0m',' = ROM    '
	db 27,'[42m','r',27,'[0m',' = RAM',13,10
    db 13,10
	db '16C550C UART Ports     CH376S Module Ports',13,10
	db '-------------------    -------------------',13,10
	db 'TX / RX           8    Data Port        16',13,10
	db 'Interrupt Enable  9    Command Port     17',13,10
	db 'Interrup Status  10',13,10
	db 'Line Control     11',13,10
	db 'Modem Control    12 <---- 76543210',13,10
	db 'Line Status      13      Bit 0 = User LED',13,10
	db 'Modem Status     14      Bit 2 = Disk LED',13,10
	db 'Scratch          15      Bit 3 = ROM Enable',13,10
	db 13,10
	db 'The EEPROM is an ATMEL AT28C256',13,10
	db 13,10,0
	ret

	db 'DANGER ENDS '
	
; -------------------------------------------------------------------------------------------------
goto_page_0:
	ld a, 0
	ld (current_page),a
	call newline
	call show_page
	ret

; -------------------------------------------------------------------------------------------------

; This is the BURN-IN test.
; I use it on new Z80 Playground boards that I have assemmbled, to check them.
; It runs for about an hour, reads and writes files to the USB Drive,
; flashes the LEDs, prints things to the screen etc.
; The idea is that if it is still running after an hour, the board is good.
burn_x equ 39000
burn_y equ 39001
burn_in_dump_area equ 39002

burn_in:
	call rom_off					; Needs to be off for ram-test to work
	call user_toggle
	call clear_screen
	call message
	db 'Starting BURN-IN test. This takes about 30 minutes.',13,10,0

	; Draw empty box

	ld a, 1
	ld (burn_y), a				
draw_loop_y:
	call space
	ld b, 35
draw_loop_x:
	ld a, 178
	call print_a
	djnz draw_loop_x

	call newline

	ld a, (burn_y)
	inc a
	ld (burn_y), a
	cp 20
	jr c, draw_loop_y

	; Now main burn in loop

	ld a, 0
	ld (burn_y), a				
burn_in_loop_y:
	ld a, 0
	ld (burn_x), a				
burn_in_loop_x:
	call full_ram_test
	jp nz, burn_in_ram_error
	call one_minute_burn_in
	ld a, (burn_x)
	inc a
	ld (burn_x), a
	cp 32
	jr nz, burn_in_loop_x
	ld a, (burn_y)
	inc a
	ld (burn_y), a
	cp 16
	jr nz, burn_in_loop_y

	call newline
	call message
	db 13,10,'YAY! All tests pass! Press a key to continue...',13,10,0
burn_in_wait:
	call char_in			; get a char from keyboard
	cp 0					; If it's null, ignore it
	jr z,burn_in_wait	
	ret

full_ram_test:
	; Tests all of ram.
	; Returns Z set if success.
	ld hl, $FFFF 
full_ram_test1:
	ld b, (hl)

	ld (hl), %01010101
	ld a, (hl)
	cp %01010101
	ret nz

	ld (hl), %10101010
	ld a, (hl)
	cp %10101010
	ret nz

	ld (hl), b
	dec hl 
	ld a, h
	or l
	jr nz, full_ram_test1
    cp a                                ; set zero flag for success
	ret

one_minute_burn_in:
	; set cursor position
    ld a, ESC
    call print_a
    ld a, '['
    call print_a
    ld a, (burn_y)
	add a, 3
    call print_a_as_decimal
    ld a, ';'
    call print_a
    ld a, (burn_x)
	add a, 3
    call print_a_as_decimal
    ld a, 'H'
    call print_a

	; set foreground colour
    ld a, ESC
    call print_a
    ld a, '['
    call print_a
    ld a, '3'
    call print_a
    ld a, (burn_x)
	srl a
	srl a
	add a, '0'
    call print_a
    ld a, 'm'
    call print_a

	; set background colour
    ld a, ESC
    call print_a
    ld a, '['
    call print_a
    ld a, '4'
    call print_a
    ld a, (burn_y)
	srl a
	srl a
	add a, '0'
    call print_a
    ld a, 'm'
    call print_a

	ld a, 221
	call print_a

	; Normal colour again
    ld a, ESC
    call print_a
    ld a, '['
    call print_a
    ld a, '0'
    call print_a
    ld a, 'm'
    call print_a

	call burn_in_write_file

burn_in_inner_loop:
	call user_toggle
	call disk_toggle

	call burn_in_read_file

	call burn_in_erase_file
	ret

burn_in_read_file:
	; Read the file and check the content.
	; If not good, halt the processor.
	ld hl, ROOT_NAME
	call open_file
	ld hl, BURN_IN_NAME
	call open_file

	ld a, BYTE_READ
	call send_command_byte
	ld a, 255                           ; Request all of the file
	call send_data_byte
	ld a, 255                           ; Yes, all!
	call send_data_byte

	ld a, GET_STATUS
	call send_command_byte
	call read_data_byte
	ld hl, burn_in_dump_area                       
burn_in_load_loop1:
	cp USB_INT_DISK_READ
	jr nz, burn_in_load_finished

	push hl
	call disk_on
	ld a, RD_USB_DATA0
	call send_command_byte
	call read_data_byte
	pop hl
	call read_data_bytes_into_hl
	push hl
	call disk_off
	ld a, BYTE_RD_GO
	call send_command_byte
	ld a, GET_STATUS
	call send_command_byte
	call read_data_byte
	pop hl
	jp burn_in_load_loop1
burn_in_load_finished:
	call close_file

	; Now compare file content with what we wrote there originally
	ld de, config_file_loc
	ld hl, burn_in_dump_area
	ld b, 10
burn_in_compare_loop:	
	ld a, (de)
	cp (hl)
	jr nz, burn_in_compare_failed
	inc de
	inc hl
	djnz burn_in_compare_loop
	ret

burn_in_ram_error:
	call message
	db 'RAM error at ',0
	call show_hl_as_hex
	call message
	db 13,10,0
	halt

burn_in_compare_failed:
	call message
	db 'Files were different!',13,10,0
	call message
	db 'Expected: ',0
	ld hl, config_file_loc
	call show_string_at_hl
	call newline

	call message
	db 'Actual  : ',0
	ld hl, burn_in_dump_area
	call show_string_at_hl
	call newline
	
	halt

burn_in_erase_file:
	; Try to open the test file	
	call close_file
	ld hl, ROOT_NAME
	call open_file
	ld hl, BURN_IN_NAME
	call open_file
	jr nz, burn_in_file_not_found
	call close_file

	; Erase it if it exists
	ld hl, ROOT_NAME
	call open_file
	ld a, SET_FILE_NAME
	call send_command_byte
	ld hl, BURN_IN_NAME
	call send_data_string
	ld a, FILE_ERASE
	call send_command_byte
	call read_status_byte
burn_in_file_not_found:
	call close_file
	ret

burn_in_write_file:
	call burn_in_erase_file

	; Create it and put a value in it
	ld hl, ROOT_NAME
	call open_file
	ld de, BURN_IN_NAME
	call create_file
	jr z, burnin_create_ok 
	call message
	db 'ERROR creating burn-in file.',13,10,0
	halt

burnin_create_ok:
	ld a, BYTE_WRITE
	call send_command_byte

	; Send number of bytes we are about to write, as 16 bit number, low first
	call get_program_size
	ld a, 10
	call send_data_byte
	ld a, 0
	call send_data_byte

	ld hl, config_file_loc
	ld (hl), 'H'
	inc hl
	ld (hl), 'e'
	inc hl
	ld (hl), 'l'
	inc hl
	ld (hl), 'l'
	inc hl
	ld (hl), 'o'
	inc hl
	ld a, (burn_x)
	add a, 33
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), 0

	ld hl, config_file_loc			; Write the bytes that are in this temp area
	call write_loop
	call close_file
	ret

print_a_as_decimal:
	ld b, 0
print_a_as_decimal1:
	cp 10
	jr c, print_a_as_decimal_units
	inc b
	ld c, 10
	sub c
	jr print_a_as_decimal1

print_a_as_decimal_units:
	push af
	ld a, b
	cp 0
	jr z, print_a_as_decimal_units1
	add a, '0'
	call print_a
print_a_as_decimal_units1:
	pop af
	add a, '0'
	call print_a
	ret

BURN_IN_NAME:
	db 'BURNIN.TXT',0

include "printing.asm"
include "test_uart.asm"

load_jupiter_ace:
    ; Load CORE.BIN into its proper location
    ld hl, NAME_OF_CORE
    call copy_filename_to_buffer
    ld de, $F600 							; TODO: This can't be hardcoded, can it???
    call load_bin_file
	jr z, loaded_core_file
	call message
	db 'Failed to load CORE.BIN',13,10,0
	halt

loaded_core_file:	
    call message
    db 'CORE loaded!',13,10,0

	; Get the file Jupiter.bin into memory at location 0.
    ld hl, JUPITER_ACE_NAME
    call copy_filename_to_buffer
    ld de, 0								; Load it into location $0000             
    call load_bin_file                      ; hl comes back with end location of file. Z set if success.
	jr z, load_jupiter_ace1
	call message
	db 'Failed to load jupiter ace file.',13,10,0
	halt
load_jupiter_ace1:
	call message
	db 'Loaded jupiter ace file!',13,10,0
	; Just a quick test:
	call $F600+57
	db 'Starting Juniper Deuce...',13,10,0

	; Clear the screen
	; ld hl, $2400
	; ld (hl), '#'
	; ld de, $2401
	; ld bc, 767
	; ldir

	; Now run it.
	; Now we need the ROM turned off:
	call rom_off
	jp 0									

JUPITER_ACE_NAME:
    db 'JUPITER.BIN',0



the_end:
	db 'A message at the end ****************',0
	
; ---------------------------------------------------------
; These are variables so need to be in RAM.
; Unfortunately I am dumb and initially put them in ROM.
; I have learned my lesson!	

;store_hl		equ	60000					; Temporary store for hl
;store_de 		equ 60002					; Temporary store for de
current_page 	equ 60004					; Currently displayed monitor page

test_buffer 	equ 60006					; 32 x 24 char buffer (768 bytes)
