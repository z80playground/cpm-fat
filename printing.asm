; printing.asm

; -------------------------------------------------------------------------------------------------

clear_screen:
	call message
	db 27,'[2J',27,'[H',0
	ret

show_page:
	call clear_screen
	
	ld a,(current_page)
	ld d,a
	ld e,0					; de holds address of start of page to show
	
	ld c,16					; rows to show
row_loop:
	push de
	call show_de_as_hex		; show the address
	call space
	pop de

	push de
	ld b,16					; bytes per row
col_loop:
	ld a,(de)				; get the byte
	call show_a_as_hex
	ld a,' '
	call print_a			; leave a space
	inc de					; continue to next byte
	djnz col_loop			; continue to next column
	
	pop de					; now go over the line again in ASCII
	ld b,16					; bytes per row
ascii_loop:
	ld a,(de)				; get the byte
	call show_a_as_char
	inc de					; continue to next char
	djnz ascii_loop			; continue to next column
	
	call newline
	dec c
	ld a,c
	cp 0
	jr nz,row_loop			; continue to next row
	call newline
	ret

show_a_safe:
	cp 32
	jr c,show_blank			; jr c = jump if less than ( < )
	cp 127
	jr nc,show_blank		; jr nc = jump if equal to or greater than ( >= )
	call print_a
	ret
show_blank:
	push af
	ld a, '-'
	call show_a_as_char
	pop af
	ret

show_a_as_char:
	;cp 10
	;jr z, show_as_char1
	;cp 13
	;jr z, show_as_char1
	cp 32
	jr c,show_ctrl		; jr c = jump if less than ( < )
	cp 127
	jr nc,show_unknown		; jr nc = jump if equal to or greater than ( >= )
show_as_char1:
	call print_a
	ret
show_ctrl:
	push af
	call message
	db 27,'[7m',0
	pop af
	add a, 64
	call print_a
	call message
	db 27,'[0m',0
	ret
show_unknown:
	ld a,'?'
	call print_a
	ret
	
; SHOW_DE_AS_HEX
; Pass in a number in DE.
; It will be displayed in this format: FFFF	
show_de_as_hex:
	ld a,d
	call show_a_as_hex
	ld a,e
	call show_a_as_hex
	ret
	
; SHOW_STRING_AT_HL
; Pass in hl containing a pointer to a zero terminated string.
; It will be printed.
show_string_at_hl:
	push hl
show_string_at_hl_loop:
	ld a, (hl)
	cp 0
	jr z,show_string_at_hl_complete
	inc hl
	call print_a			; print it
	jr show_string_at_hl_loop
show_string_at_hl_complete:
	pop hl
	ret
