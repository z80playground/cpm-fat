; monitor.asm
; The low-level monitor

monitor_start:
    call monitor_init

monitor_loop:
	ld a, '>'
	call print_a
monitor_loop1:
	call char_in			; get a char from keyboard
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
	jr nz, unknown_char

    call message 
    db 'Starting CP/M... Make sure you have the "ROM Select" jumper set to "switched".',13,10,0
    jp start_cpm

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
	db 'Monitor v1.04 December 2020',13,10,13,10
	db 'c = Boot CP/M', 13, 10
	db 'm = Memory Map', 13, 10
	db '0 = Show Page 0 of Memory', 13, 10
	db 'h = Move to Higher Page', 13, 10
	db 'l = Move to Lower Page', 13, 10
	db 'u = User LED toggle', 13, 10
	db '3 = ROM ON', 13, 10
	db '4 = ROM OFF', 13, 10
	db 'd = Disk LED toggle', 13, 10
	db '# = Execute HALT instruction.',13,10
	db '/ = Show this Menu',13,10
	db 13,10,0
	ret

monitor_init:
    ; Three flashes on the USER (blue) LED
    ld b, 3
monitor_init1:
    push bc    
	call user_on
	call short_pause
	call user_off
	call short_pause
    pop bc
    djnz monitor_init1

    call ram_fill

	call clear_screen
	call show_welcome_message
    ret

ram_fill:
    ; Copy the first 8k of ROM down to ram
	ld hl,0
	ld de,0
	ld bc, 8192
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
	db 'Modem Control    12',13,10
	db 'Line Status      13',13,10
	db 'Modem Status     14',13,10
	db 'Scratch          15',13,10
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

include "printing.asm"
; include "uart.asm"
; include "debug.asm"
; include "lights.asm"	
; include "pauses.asm" 
; include "memorystick.asm"
; include "numbers.asm"
; include "workspace.asm"
 include "test_uart.asm"


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
