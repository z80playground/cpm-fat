; BIOS for CP/M v2.2 on Z80 Playground v1.2
;
; This occupies less than 0.5K

include "locations.asm"
include "core_jump.asm"

    org BIOS_START

bios_entry:
   	JP	BOOT	;COLD START
WBOOTE:	
    JP	WBOOT	;WARM START
    JP	CONST	;CONSOLE STATUS
    JP	CONIN	;CONSOLE CHARACTER IN
    JP	CONOUT	;CONSOLE CHARACTER OUT
    JP	LIST	;LIST CHARACTER OUT
    JP	PUNCH	;PUNCH CHARACTER OUT
    JP	READER	;READER CHARACTER OUT
    JP	HOME	;MOVE HEAD TO HOME POSITION
    JP	SELDSK	;SELECT DISK
    JP	SETTRK	;SET TRACK NUMBER
    JP	SETSEC	;SET SECTOR NUMBER
    JP	SETDMA	;SET DMA ADDRESS
    JP	READ	;READ DISK
    JP	WRITE	;WRITE DISK
    JP	LISTST	;RETURN LIST STATUS
    JP	SECTRAN	;SECTOR TRANSLATE

BOOT:
    ld sp, BIOS_STACK
    call CORE_message
    db 27,'[2J'                 ; clear screen
    db 27,'[H'                  ; cursor home
    db 27,'[0m'                  ; clear attributes
    db 'CP/M v2.2',13,10
    db 'Z80 Playground - 8bitStack.co.uk',13,10
    db 'Rel 1.05 (fast!)',13,10
    db 'Inspired by Digital Research',13,10
    db 13,10
    db '64K system with drives A thru P',13,10
    db 13,10
    db 0

    call CORE_message
    db 'CORE ',0
    ld hl, CORE_START
    call CORE_show_hl_as_hex
    call CORE_newline

    call CORE_message
    db 'BIOS ',0
    ld hl, BIOS_START
    call CORE_show_hl_as_hex
    call CORE_newline

    call CORE_message
    db 'BDOS ',0
    ld hl, BDOS_START
    call CORE_show_hl_as_hex
    call CORE_newline

    ld hl, ccp_name
show_ccp_name_loop:
    ld a, (hl)
    cp 0
    jr z, shown_ccp_name
    call CORE_print_a
    inc hl
    jr show_ccp_name_loop
shown_ccp_name:
    call CORE_space
    ld hl, (ccp_location)
    call CORE_show_hl_as_hex
    call CORE_newline

    call CORE_rom_off
    call CORE_user_off

    ; Set the drive and user to 0
    ld a, 0
    ld (UDFLAG), a

    ; Roll through to the warm boot...
WBOOT:	
    ld sp, BIOS_STACK

    call CORE_message
    db 27,'[0m',0                  ; clear attributes
    ;call CORE_message
    ; Load the CCP to the proper location
    ld hl, ccp_name
    call CORE_copy_filename_to_buffer
    ld de, (ccp_location)
    call CORE_load_bin_file

    ; Load the BDOS to the proper location - so we can do disk access etc
    ld hl, NAME_OF_BDOS
    call CORE_copy_filename_to_buffer
    ld de, BDOS_START
    call CORE_load_bin_file

    ; Pass the current drive and user to the CCP to start it
    ld a, (UDFLAG)
    ld c, a
    ld hl, (ccp_location)
    inc hl
    inc hl
    inc hl
    jp (hl) ; Note this means jump to hl, not jump to (hl)

CONST:	
    ; RETURN 0FFH IF CHARACTER READY, 00H IF NOT
	in a,(uart_LSR)			; get status from Line Status Register
	bit 0,a					; zero flag set to true if bit 0 is 0 (bit 0 = Receive Data Ready)
							; "logic 0 = no data in receive holding register."
	jp z,CONST1	            ; zero = no char received
	ld a, $FF		        ; return true
	ret						; in A
CONST1:
	ld a,0					; Return a zero in A
	ret

CONIN:	
    ;ld a, 'I'
    ;call BIOS_MOAN
    ; CONSOLE CHARACTER INTO REGISTER A
	in a,(uart_LSR)			; get status from Line Status Register
	bit 0,a					; zero flag set to true if bit 0 is 0 (bit 0 = Receive Data Ready)
							; "logic 0 = no data in receive holding register."
	jp z,CONIN	            ; zero = no char received
	in a,(uart_tx_rx)		; Get the incoming char
    ret

CONOUT:	
    ;push bc
    ;ld a, 'O'
    ;call BIOS_MOAN
    ;pop bc
    ld a, c
    call CORE_print_a
    ret

LIST:	
    jp CONOUT
PUNCH:	
    jp CONOUT
READER:	
    ld a, 'R'
    jp BIOS_MOAN
HOME:	
    ld a, 'H'
    jp BIOS_MOAN
SELDSK:	
    ld a, 'D'
    jp BIOS_MOAN
SETTRK:	
    ld a, 'T'
    jp BIOS_MOAN
SETSEC:	
    ld a, 'S'
    jp BIOS_MOAN
SETDMA:	
    ld a, 'D'
    jp BIOS_MOAN
READ:	
    ld a, '<'
    jp BIOS_MOAN
WRITE:	
    ld a, '>'
    jp BIOS_MOAN
LISTST:	
    ld a, ':'
    jp BIOS_MOAN
SECTRAN:	
    ld a, '+'
    jp BIOS_MOAN

BIOS_MOAN:
    call CORE_message
    db 'BAD BIOS CALL: ',0
    call CORE_print_a
    call CORE_newline
    jp $0000                    ; Totally abandon anything after a bad BIOS call!

NAME_OF_BDOS:
    db 'BDOS.BIN',0
NAME_OF_BIOS:
    db 'BIOS.BIN',0

BIOS_STACK_START:
    db 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0
BIOS_STACK:
    db 0,0

UDFLAG	EQU	4		;current drive name and user number.
