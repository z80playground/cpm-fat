; test_uart.asm

test_uart:
	call message
	db 'Type some characters to test sending keys from the Z80 Playground over Serial, ', 13, 10
	db 'or send some characters from the other end of the Serial connection to test', 13, 10
	db 'how many are received. Whatever you send will be echoed after a carriage-return.', 13, 10
	db 'Just type "quit" to go back to the main monitor menu.', 13, 10
	db 'Or type "Z" to print a special message.', 13, 10, 0

test_uart0:
	ld de, test_buffer
	xor a
	ld (de), a                    ; Always make sure the buffer ends in null
	ld b, 255                     ; max buffer length

test_uart1:
	call char_in
	cp 0
	jr z, test_uart1
	cp 13
	jr z, test_uart2
	call print_a
	cp 'a'
	jr c, test_uart_ok
	cp 'z'+1
	jr nc, test_uart_ok
	sub 32
test_uart_ok:
	ld (de), a
	inc de
	xor a
	ld (de), a                    ; Always make sure the buffer ends in null
	djnz test_uart1               ; Keep going until we run out of buffer

test_uart2:
	call message
	db 13, 10, 0

	call did_they_type_quit
	ret z

	call did_they_type_Z
	jr z, show_z80_message

	ld hl, test_buffer
	call show_string_at_hl

	call message
	db 13, 10, 0

	jr test_uart0

show_z80_message:
	call message

	db '+-------------------------------------------------------------------------------+', 13, 10
	db '|   _________   ___    _____  _                                             _   |', 13, 10
	db '|  |___  / _ \ / _ \  |  __ \| |                                           | |  |', 13, 10
	db '|     / / (_) | | | | | |__) | | __ _ _   _  __ _ _ __ ___  _   _ _ __   __| |  |', 13, 10
	db '|    / / > _ <| | | | |  ___/| |/ _` | | | |/ _` | ''__/ _ \| | | | ''_ \ / _` |  |', 13, 10
	db '|   / /_| (_) | |_| | | |    | | (_| | |_| | (_| | | | (_) | |_| | | | | (_| |  |', 13, 10
	db '|  /_____\___/ \___/  |_|    |_|\__, _|\__, |\__, |_|  \___/ \__, _|_| |_|\__, _|  |', 13, 10
	db '|                                      __/ | __/ |                              |', 13, 10
	db '|                                     |___/ |___/                               |', 13, 10
	db '|                                                                               |', 13, 10
	db '|        _    _         _____ _______   _            _   _                      |', 13, 10
	db '|       | |  | |  /\   |  __ \__   __| | |          | | (_)                     |', 13, 10
	db '|       | |  | | /  \  | |__) | | |    | |_ ___  ___| |_ _ _ __   __ _          |', 13, 10
	db '|       | |  | |/ /\ \ |  _  /  | |    | __/ _ \/ __| __| | ''_ \ / _` |         |', 13, 10
	db '|       | |__| / ____ \| | \ \  | |    | ||  __/\__ \ |_| | | | | (_| |         |', 13, 10
	db '|        \____/_/    \_\_|  \_\ |_|     \__\___||___/\__|_|_| |_|\__, |         |', 13, 10
	db '|                                                                 __/ |         |', 13, 10
	db '|                                                                |___/          |', 13, 10
	db '|                                                                               |', 13, 10
	db '+-------------------------------------------------------------------------------+', 13, 10
	db 13, 10, 13, 10
	db 'This is a long text to test whether we can send a large amount of text to the', 13, 10
	db 'Serial port and still receive it correctly at the other end.', 13, 10
	db 0
	jp test_uart0

did_they_type_quit:
	ld hl, test_buffer

	ld a, (hl)
	cp 'Q'
	ret nz
	inc hl

	ld a, (hl)
	cp 'U'
	ret nz
	inc hl

	ld a, (hl)
	cp 'I'
	ret nz
	inc hl

	ld a, (hl)
	cp 'T'
	ret

did_they_type_Z:
	ld hl, test_buffer
	ld a, (hl)
	cp 'Z'
	ret nz
	inc hl

	ld a, (hl)
	cp 0
	ret

did_they_type_J:
	ld hl, test_buffer
	ld a, (hl)
	cp 'J'
	ret nz
	inc hl

	ld a, (hl)
	cp 0
	ret
