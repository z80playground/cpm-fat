; Routines to help print file sizes for DIR commands.
; 1KB = 1024 bytes (00 00 04 00 h)
; 1MB = 1024 KB = 1,048,576 bytes (00 10 00 00 h)
; 1GB = 1024 MB = 40 00 00 00 h
; Largest 32 bit number is FFFFFFFF which is 4,294,967,295 which is 4.2GB
; So this routine can only display file sizes up to 4.2GB.
; However, I've allowed a 6 byte buffer to store it in for 2 reasons:
; (1) In the future I may want to use more digits (but probably not!!!)
; (2) We multiply in incoming number by 10 to show 1 decimal place later in the process.
; The largest number we ever need to actually show is 1023 because we
; always divide the number down into larger units.
; For example, 1023 would be shown as 1023 bytes
; but 1024 would be shown as 1K.
; This means we need a divide-by-1024 routine, which is simply Right Shift 10 times!
; Which is simplified by shifting the whole number right by one byte, then Right Shift twice.
; This is of course integer maths, so no decimal places.
; However, we use a trick! First we multiply the number by 10 so that once we have done all
; the calculations we can simply insert a dot before the last digit to give ourselves 1 decimal place.
; Therefore 2000 would be shown as 1.9K, but 2048 would be shown as 2.0K.
; We also do some post-processing to get rid of the leading zeros.
; 
; Any number less than 00000400h is shown in bytes.
; Any number less than 00100000h is shown in KB.
; Any number less than 40000000h is shown in MB.
; Higher numbers are show in GB.

show_filesize:
; Pass in 32 bit filesize in the lowest 4 bytes of the 6 byte filesize_buffer.
; First work out the units
	ld a, (filesize_buffer+2)
	ld h, a
	ld a, (filesize_buffer+3)
	ld l, a
	ld de, $4000
	or a
	sbc hl, de                    ; Compare hl with de
	jr nc, show_gigabytes

	ld a, (filesize_buffer+2)
	ld h, a
	ld a, (filesize_buffer+3)
	ld l, a
	ld de, $0010
	or a
	sbc hl, de                    ; Compare hl with de
	jr nc, show_megabytes

	ld a, (filesize_buffer+4)
	ld h, a
	ld a, (filesize_buffer+5)
	ld l, a
	ld de, $0400
	or a
	sbc hl, de                    ; Compare hl with de
	jr nc, show_kilobytes

show_bytes:
	call multiply_filesize_by_10
	ld a, 'B'
	ld (filesize_units), a
	jp show_filesize1
show_kilobytes:
	call multiply_filesize_by_10
	ld a, 'K'
	ld (filesize_units), a
	call divide_filesize_by_1024
	jp show_filesize1
show_megabytes:
	call multiply_filesize_by_10
	ld a, 'M'
	ld (filesize_units), a
	call divide_filesize_by_1024
	call divide_filesize_by_1024
	jp show_filesize1
show_gigabytes:
	call multiply_filesize_by_10
	ld a, 'G'
	ld (filesize_units), a
	call divide_filesize_by_1024
	call divide_filesize_by_1024
	call divide_filesize_by_1024
	jp show_filesize1

show_filesize1:
; We now have a number from 0 to 1023 in the filesize_buffer bytes 4 & 5.
	ld a, (filesize_buffer+4)
	ld h, a
	ld a, (filesize_buffer+5)
	ld l, a
	call show_hl_as_decimal_to_buffer

; By this point the number is in filesize_buffer as a string of 5 digits with leading zeros

	call remove_leading_zeros

; By this point the number is in filesize_buffer as a string of 5 digits with leading spaces

	ld de, filesize_buffer
	ld b, 4                       ; show first 4 digits of filesize
show_filesize2:
	ld a, (de)
	call print_a
	inc de
	djnz show_filesize2
	ld a, '.'                     ; then a dot
	call print_a
	ld a, (de)                    ; then the last digit
	call print_a
	call space

	ld a, (filesize_units)
	cp 'B'
	jr nz, show_filesize3
	call message
	db 'bytes', 0
	ret

show_filesize3:
	call print_a
	ld a, 'B'
	call print_a
	ret

remove_leading_zeros:
	ld a, (filesize_buffer)
	cp '0'
	ret nz
	ld a, ' '
	ld (filesize_buffer), a

	ld a, (filesize_buffer+1)
	cp '0'
	ret nz
	ld a, ' '
	ld (filesize_buffer+1), a

	ld a, (filesize_buffer+2)
	cp '0'
	ret nz
	ld a, ' '
	ld (filesize_buffer+2), a
	ret

multiply_filesize_by_10:
; To multiply N by 10 we do this:
; Shift-left to get N x 2
; Shift-left twice more to get N x 8
; Add the two totals together
	call shift_left_filesize_buffer
	call copy_filesize_buffer     ; This is N x 2
	call shift_left_filesize_buffer
	call shift_left_filesize_buffer ; Buffer has N x 8
	call add_filesize_buffer_copy ; Add N*8 and N*2
	ret

add_filesize_buffer_copy:
; Add the copy of the filesize_buffer back onto the real one
	ld de, filesize_buffer+5
	ld hl, filesize_buffer_copy+5
	ld a, (de)
	or a                          ; clear carry
	adc a, (hl)
	ld (de), a
	dec de
	dec hl

	ld a, (de)
	adc a, (hl)
	ld (de), a
	dec de
	dec hl

	ld a, (de)
	adc a, (hl)
	ld (de), a
	dec de
	dec hl

	ld a, (de)
	adc a, (hl)
	ld (de), a
	dec de
	dec hl

	ld a, (de)
	adc a, (hl)
	ld (de), a
	dec de
	dec hl

	ld a, (de)
	adc a, (hl)
	ld (de), a

	ret

copy_filesize_buffer:
	ld de, filesize_buffer_copy
	ld hl, filesize_buffer
	ld bc, 6
	ldir
	ret

divide_filesize_by_1024:
; Shift everything right by 1 byte
	ld a, (filesize_buffer+4)
	ld (filesize_buffer+5), a
	ld a, (filesize_buffer+3)
	ld (filesize_buffer+4), a
	ld a, (filesize_buffer+2)
	ld (filesize_buffer+3), a
	ld a, (filesize_buffer+1)
	ld (filesize_buffer+2), a
	ld a, (filesize_buffer+0)
	ld (filesize_buffer+1), a
	sub a                         ; Put zero in top byte
	ld (filesize_buffer+0), a

; Then SHIFT-RIGHT by two bits
	call shift_right_filesize_buffer
	call shift_right_filesize_buffer
	ret

shift_right_filesize_buffer:
	ld hl, filesize_buffer
	or a                          ; clear carry
	rr (hl)
	inc hl
	rr (hl)
	inc hl
	rr (hl)
	inc hl
	rr (hl)
	inc hl
	rr (hl)
	inc hl
	rr (hl)
	ret

shift_left_filesize_buffer:
	ld hl, filesize_buffer+5
	or a                          ; clear carry
	rl (hl)
	dec hl
	rl (hl)
	dec hl
	rl (hl)
	dec hl
	rl (hl)
	dec hl
	rl (hl)
	dec hl
	rl (hl)
	ret

show_hl_as_decimal_to_buffer:
; Routine adapted from https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispHL
	ld de, filesize_buffer        ; We put the result here as a string
	ld	bc, -10000
	call	show_hl_as_decimal_to_buffer1
	ld	bc, -1000
	call	show_hl_as_decimal_to_buffer1
	ld	bc, -100
	call	show_hl_as_decimal_to_buffer1
	ld	c, -10
	call	show_hl_as_decimal_to_buffer1
	ld	c, -1
show_hl_as_decimal_to_buffer1:
	ld	a, '0'-1
show_hl_as_decimal_to_buffer2:
	inc	a
	add	hl, bc
	jr	c, show_hl_as_decimal_to_buffer2
	sbc	hl, bc
	ld (de), a
	inc de
	ret

