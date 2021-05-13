; message

; -------------------------------------------------------------------------------------------------

message:
; Use this handy helper function to display an inline message easily.
; It preserves all registers (which was tricky to do).
; This expects to be called from code where the message follows the "call debug" in-line, like this:
; 
; ld a, 10 ; (or whatever code you like)
; call message
; db "my message", 0
; ld b, 10 ; (or whatever code you like)
; 
; When we return we make sure sp is pointing to the next line of code after the message.

; sp -> ret-addr

	push af                       ; We have stored af
	push af                       ; We do this 3 times
	push af                       ; to allow spare stack space.
; sp -> AF, AF, AF, ret-addr
	push bc                       ; sp -> BC, AF, AF, AF, ret-addr
	push de                       ; sp -> DE, BC, AF, AF, AF, ret-addr
	push hl                       ; sp -> HL, DE, BC, AF, AF, AF, ret-addr

	inc sp
	inc sp                        ; adjust the stack to overlook the stored afx3, BC, DE & HL
; HL, sp -> DE, BC, AF, AF, AF, ret-addr
	inc sp
	inc sp                        ; HL, DE, sp -> BC, AF, AF, AF, ret-addr

	inc sp
	inc sp                        ; HL, DE, BC, sp -> AF, AF, AF, ret-addr

	inc sp
	inc sp

	inc sp
	inc sp

	inc sp
	inc sp                        ; HL, DE, BC, AF, AF, AF, sp -> ret-addr

	ex (sp), hl                   ; top of stack is now mangled, but hl is pointing to our message
; HL, DE, BC, AF, AF, AF, sp -> HL

message_loop:
	ld a, (hl)
	cp 0
	jr z, message_complete
	inc hl
	call print_a                  ; print a character (Mangles 2 items below top of stack)
	jr message_loop               ; Loop until done
; HL, DE, BC, AF, XX, XX, sp -> HL

message_complete:
	inc hl
	ex (sp), hl                   ; restore top of stack, after we have incremented it so it points to the subsequent instruction
; HL, DE, BC, AF, XX, XX, sp -> new-ret-addr
	dec sp
	dec sp

	dec sp
	dec sp

	dec sp
	dec sp                        ; adjust stack because of our pushed "af"
; HL, DE, BC, sp -> AF, XX, XX, new-ret-addr
	dec sp
	dec sp                        ; adjust stack because of our pushed "BC"
; HL, DE, sp -> BC, AF, XX, XX, new-ret-addr
	dec sp
	dec sp                        ; adjust stack because of our pushed "DE"
; HL, sp -> DE, BC, AF, XX, XX, new-ret-addr
	dec sp
	dec sp                        ; adjust stack because of our pushed "HL"
; sp -> HL, DE, BC, AF, XX, XX, new-ret-addr

	pop hl                        ; HL is restored
; sp -> DE, BC, AF, XX, XX, new-ret-addr
	pop de                        ; DE is restored
; sp -> BC, AF, XX, XX, new-ret-addr
	pop bc                        ; BC is restored
; sp -> AF, XX, XX, new-ret-addr
	pop af                        ; we have restored af
; sp -> XX, XX, new-ret-addr

	inc sp
	inc sp
	inc sp
	inc sp
; sp -> new-ret-addr

	ret                           ; return to the instruction after the message

show_hl_as_hex:
	ld a, h
	call show_a_as_hex
	ld a, l
	call show_a_as_hex
	ret

show_a_as_hex:
	push af
	srl a
	srl a
	srl a
	srl a
	add a, '0'
	cp ':'
	jr c, show_a_as_hex1
	add a, 7
show_a_as_hex1:
	call print_a
	pop af
	and %00001111
	add a, '0'
	cp ':'
	jr c, show_a_as_hex2
	add a, 7
show_a_as_hex2:
	call print_a
	ret

; ---------------------------------------------------
; show_all shows all the CPU registers!

show_all:
	ld (store_sp), sp
	push af
	push hl
	push de
	push bc

	call message
	db 'A=', 0
	call show_a_as_hex

	pop hl
	call message
	db ', BC=', 0
	call show_hl_as_hex
	push bc

	pop bc
	pop hl
	call message
	db ', DE=', 0
	call show_hl_as_hex
	push de
	push bc

	pop bc
	pop de
	pop hl
	call message
	db ', HL=', 0
	call show_hl_as_hex
	push hl
	push de
	push bc

	call message
	db ', SP=', 0
	ld hl, (store_sp)
	call show_hl_as_hex

	ld a, 13
	call print_a
	ld a, 10
	call print_a

	pop bc
	pop de
	pop hl
	pop af
	ret

store_sp:
	ds 2
