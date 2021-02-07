; CP/M BDOS

include "locations.asm"
include "core_jump.asm"

    org BDOS_START

    ; BDOS size is 2.5K

DEBUG_BDOS equ 0

bdos_entry:
    ; The function number is passed in Register C.
    ; The parameter is passed in DE.
    ; Result returned in A or HL. Also, A=L and B=H on return for compatibility reasons.
    ; If function number is unknown we return A=0.

    ld a, c
    cp 49
    jr c, BDOS_ok

    cp $66                      ; 102 = BDOS_Get_Date_Time
    jr z, return_255_in_a

    call CORE_message
    db 'BAD BDOS CALL: ',0
    ld l, c
    ld h, 0
    call CORE_show_hl_as_hex
    call CORE_message
    db 13, 10, 0
    jp $0000                    ; Totally abandon anything after a bad BDOS call!

BDOS_ok:
    push de
    ld hl, BDOS_jump_table
    ld e, c
    ld d, 0
    add hl, de
    add hl, de
    ; Jump to actual BDOS entry
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl                   ; hl now holds address of the BDOS call
    pop de

    call call_hl

    ; Now return. So anything that wants to return a value in HL should do ld a,l ld b,h first
    ld l, a                     ; This is how the
    ld h, b                     ; BDOS returns values.
    ret                         ; Note that it is important to some programs that both A and B are set.

call_hl:
    ; This crazy-looking code does a jump to the address in hl.
    ; Because we called this routine, it was like we did "call hl".
	push hl
    ret

show_bdos_message:
    call CORE_message
    db 13,10,'BDOS_',0
    ret

BDOS_System_Reset:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'reset',13,10,0
    ENDIF

    call clear_current_fcb                          ; Clear the Current_fcb
    jp $0000

return_0_in_a:
    xor a                                           ; a = 0
    ld b, a
    ret
return_1_in_a:
    ld a, 1
    ld b, a
    ret
return_255_in_a:
    ld a, 255
    ld b, a
    ret

BDOS_Console_Input:
    ; Read a key from the keyboard.
    ; If there is none, wait until there is.
    ; Echo it to screen, and obey things like Tab, Backspace etc
    call CORE_char_in
    cp 0                                ; Keep trying til they press something
    jr z, BDOS_Console_Input
    cp 32                               ; Don't echo control chars
    ret c
    call CORE_print_a                   ; But do echo everything else
    ret

BDOS_Console_Output:
    ; Prints to screen the char in e.
    ld a, e
    call CORE_print_a
    ret

BDOS_Reader_Input:
    ; call show_bdos_message
	; call CORE_message
	; db 'Rdr_In',13,10,0
    jp return_255_in_a

BDOS_Punch_Output:
    ; call show_bdos_message
	; call CORE_message
	; db 'Punch',13,10,0
    jp return_255_in_a

BDOS_List_Output:
    ; call show_bdos_message
	; call CORE_message
	; db 'List',13,10,0
    jp return_255_in_a

BDOS_Direct_Console_IO:
    ; If "E" contains FF then we are reading from the keyboard.
    ;   If there is a key, return it in A, otherwise return 0.
    ; If "E" is not FF then we are writing to screen.
    ;   Print the char directly
    ld a, e
    cp $FF
    jr nz, BDOS_Direct_Console_IO_Write
    call CORE_char_in
    ld b, 1
    ret
BDOS_Direct_Console_IO_Write:
    call CORE_print_a
    jp return_0_in_a

BDOS_Get_IO_Byte:
    ; call show_bdos_message
	; call CORE_message
	; db 'Get_IO_Byte',13,10,0
    jp return_0_in_a

BDOS_Set_IO_Byte:
    ; call show_bdos_message
	; call CORE_message
	; db 'Set_IO_Byte',13,10,0
    jp return_1_in_a

BDOS_Print_String:
    ; Print the string at "de" until we see a "$"
BDOS_Print_String1:
    ld a, (de)
    inc de
    cp '$'
    jr z, BDOS_Print_String2
    call CORE_print_a
    jr BDOS_Print_String1
BDOS_Print_String2
    jp return_0_in_a

BDOS_Read_Console_Buffer:
    ; Read a line of input from the keyboard into a buffer.
    ; The buffer is pointed to by DE.
    ; The first two bytes of the buffer contain its max length and final length.
    ; Read in keys and put them into the buffer until the max length is reached,
    ; or the user presses Enter.
    ; Obey chars like Tab and Backspace.
    ex de, hl
    ld d, (hl)                  ; d = max buffer length
    inc hl
    ld (hl), 0                  ; reset the "final length" byte.
    ld c, l                     
    ld b, h                     ; store this location
    ld e, 0                 
    inc hl
    ex de, hl                   ; DE points to the start of the buffer spare space
    push hl
    push bc
    pop hl                      ; HL points to the "final length" byte
    pop bc                      ; B contains the max buffer length
                                ; DE points to our target location in buffer
BDOS_Read_Console_Buffer1:
    push hl
    push de
    push bc
    call BDOS_Console_Input     ; Get a char and echo it
    pop bc
    pop de
    pop hl
    cp 13                       ; Done?
    jr z, BDOS_Read_Console_Buffer2
    cp 8                        ; Backspace key?
    jr z, BDOS_Read_Console_Buffer_Backspace
    ld (de), a                  ; Store the char in the buffer
    inc (hl)                    ; Increase the final-chars-count
    inc de                      ; Move on to next place in buffer
                                ; Decrease the max-chars counter and continue if any left
    djnz  BDOS_Read_Console_Buffer1
BDOS_Read_Console_Buffer2:
    ld b, 0
	ret
BDOS_Read_Console_Buffer_Backspace:
    ld a, (hl)                  ; If final-chars is zero we can't go back any more
    cp 0
    jr z, BDOS_Read_Console_Buffer1
    ld a, ' '                   ; Otherwise continue...
    dec de
    ld (de), a                  ; Clear out most recent char
    dec (hl)                    ; Decrease final-chars-count
    ld a, 8
    call CORE_print_a                ; Print it to go back one space
    ld a, ' '
    call CORE_print_a                ; Cover over most recent char with space
    ld a, 8
    call CORE_print_a                ; Print it to go back one space
    inc b                       ; Increase max-chars-counter
    jr BDOS_Read_Console_Buffer1

BDOS_Get_Console_Status:
    ; Is there a key available? If there is, FF, otherwise 00
    jp CORE_char_available

BDOS_Return_Version_Number:
    ld a, $22                   ; This is CP/M v2.2
    ld b, 0
	ret

BDOS_Reset_Disk_System:
    if DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Rst_Disks',13,10,0
    ENDIF

    call clear_current_fcb                          ; Clear out current FCB
    ld e, 0
    call BDOS_Select_Disk                           ; Choose disk A:

    ld hl, $0080
    ld (dma_address), hl                            ; Set standard DMA location
	ret

BDOS_Select_Disk:
    if DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Sel_Disk ',0
    ENDIF

    ; Disk is in "E". 0 = A:, 15 = P:
    ld a, (current_disk)                                    ; Are we already on the desired disk?
    ld b, a
    ld a, e
    and %00001111                                           ; Make sure desired disk is in range 0..15
    cp b                                                    ; If current and desired are the same
    jp z, return_0_in_a                                     ; ignore this call.

    ld (current_disk), a                                    ; Store disk

    ; Now check that directory actually exists, and if not, make it
    add a, 'A'
    push af

    if DEBUG_BDOS
    call CORE_print_a
    call CORE_newline
    ENDIF

    ld hl, CPM_FOLDER_NAME                ; Start at /CPM
    call CORE_open_file
    ld hl, CPM_DISKS_NAME                ; Start at /CPM/DISKS
    call CORE_open_file

    ld hl, filename_buffer              ; Move to "A" .. "P" for required disk
    pop af
    ld (hl), a
    inc hl
    ld (hl), 0
    dec hl
    call CORE_open_file
    cp YES_OPEN_DIR                     
    jr z, BDOS_Select_Disk_ok

    ld hl, filename_buffer              ; If drive "X" is not found, create the folder for it
    call CORE_create_directory

BDOS_Select_Disk_ok:
    ld a, (current_user)                ; If they are user 0 then all is done
    cp 0
    jr z, BDOS_Select_Disk_User_ok

    ; Now check if the User folder exists (User 1 = "1", User 15 = "F")
    call CORE_convert_user_number_to_folder_name
    ld hl, filename_buffer              ; Move to "1" .. "F" for required user area
    ld (hl), a
    inc hl
    ld (hl), 0
    dec hl
    call CORE_open_file
    cp YES_OPEN_DIR                     
    jr z, BDOS_Select_Disk_User_ok

    ld hl, filename_buffer              ; Create folder if not found
    call CORE_create_directory

BDOS_Select_Disk_User_ok:    
    call clear_current_fcb                          ; Clear out current FCB
	jp return_0_in_a

BDOS_Open_File:
    ; Pass in de -> FCB
    ; return a = 0 for success, a = 255 for error.
    ; The FCB that was passed in gets copied into the Current_FCB so we know which file is open.

    if DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Open_File',13,10,0
    call show_fcb
    ENDIF

    ld a, 0
    jp bdos_open_file_internal

bdos_open_file_internal:
    ; Pass in de -> FCB
    ; Pass in a = 0 for resetting the file pointer to 0, or a = 1 for don't-mess-with-file-pointer.
    ; return a = 0 for success, a = 255 for error.
    ; The FCB that was passed in gets copied into the Current_FCB so we know which file is open.
    push af
    push de

    call CORE_close_file ; just in case?

    pop de                              ; Now use FCB to open the file
    pop af
    cp 0
    jr nz, bdos_open_file_internal1     ; If a=0 then clear the file pointer, otherwise leave as is.
    ex de, hl
    ld bc, 0
    ld de, 0
    call set_file_pointer_in_fcb
    ex de, hl
bdos_open_file_internal1:
    ;call show_fcb
    push de
    call copy_fcb_to_filename_buffer
    ;call show_filename_buffer
    call open_cpm_disk_directory

    ld hl, filename_buffer+2            ; Specify search pattern "*"
    call CORE_open_file
    jr z, open_file_success

    pop de
    call clear_current_fcb              ; No file open so clear out the Current FCB
    jp return_255_in_a                  ; error
open_file_success:
    pop de
    call copy_fcb_to_current_fcb        ; File is now open, so copy FCB to Current FCB
    jp return_0_in_a

open_cpm_disk_directory:
    ; This opens the directory for a file on a CP/M disk, such as /CPM/DISKS/A or /CPM/DISKS/B/1
    ld hl, CPM_FOLDER_NAME                ; Start at "/CPM"
    call CORE_open_file
    ld hl, CPM_DISKS_NAME                ; Then "DISKS"
    call CORE_open_file

    ; Now drive letter
    ld hl, filename_buffer
    ld a, (hl)
    ld hl, DRIVE_NAME                   ; Move to "A" .. "P" for required disk
    ld (hl), a
    inc hl
    ld (hl), 0
    dec hl
    call CORE_open_file

    ; Now user number (if greater than 0)
    ld a, (current_user)
    cp 0
    ret z

    call CORE_convert_user_number_to_folder_name
    ld hl, DRIVE_NAME                   ; Move to "1" .. "F" for required user
    ld (hl), a
    inc hl
    ld (hl), 0
    dec hl
    call CORE_open_file
    ret

BDOS_Close_File:
    ; Pass in de -> FCB
    ; return 0 for success, 255 for fail
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Close',13,10,0
    ENDIF

    call CORE_close_file
    call clear_current_fcb                          ; Clear out current FCB

    jp return_0_in_a

BDOS_Search_for_First:
    ; Input is DE -> FCB
    ; Output is $FF if nothing found, otherwise 0 in A and the directory entry will have
    ; been copied into the current DMA location.

    ; The FCB contains the drive and file name.
    ; The drive can be 0 to 15 for A to P, or '?' to mean current drive.
    ; The filename and extension can be letters, or "?" or "*" for wildcards.
    ; This leaves the disk in such a position that "search_for_next" cen get the next entry.
    ; What we do is:
    ; - Open the correct folder, e.g. /CPM/DISKS/A/user
    ; - Read in a filename and put it into the DMA area.
    ; - Check if it matches. If not, try the next.

    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Search_Fst',13,10,0
    call show_fcb
    ENDIF

    call copy_fcb_to_filename_buffer_preserving_spaces

    ld de, (dma_address)
    ld a, (current_user)
    call CORE_dir                            ; returns 0 = success, 255 = fail
    cp 0
    jr z, search_first_found

    IF DEBUG_BDOS
    call CORE_message
    db 'DIR NONE',13,10,0
    ENDIF

    jp return_255_in_a                          ; Found nothing

search_first_found:
    IF DEBUG_BDOS
    call CORE_message
    db 'DIR ret:',13,10,0
    ld de, (dma_address)
    call show_fcb
    ENDIF

    jp return_0_in_a                            ; Success!

BDOS_Search_for_Next:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Search_Nxt',13,10,0
    ENDIF

    ld de, (dma_address)
    ld a, (current_user)
    call CORE_dir_next                            ; returns 0 = success, 255 = fail
    cp 0
    jr z, search_next_found

    IF DEBUG_BDOS
    call CORE_message
    db 'NEXT NONE',13,10,0
    ENDIF

    jp return_255_in_a                          ; Found nothing

search_next_found:
    IF DEBUG_BDOS
    call CORE_message
    db 'NEXT ret:',13,10,0
    ld de, (dma_address)
    call show_fcb
    ENDIF

    jp return_0_in_a                            ; Success!

BDOS_Delete_File:
    ; Delete File passes in DE->FCB
    ; Returns a = 0 for success and a = 255 for failure.
    ; I think that we return 0 if we delete a file, and 255 if we don't, even though
    ; that is not exactly an error condition.
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Del_File',13,10,0
    call show_fcb
    ENDIF

    ; We enter with DE pointing to a FCB, such as "file.xyz" or "*.txt".
    ; We use this to run a DIR-search-first, returning a result in A (0=good) and 
    ; storing its resulting FCB in a temporary FCB.
    ; If no file was found then we are done.
    ; If a file was found then we need to delete that file, and loop back to the start. 

    ld a, 255
    ld (delete_flag), a                             ; Store the result

    ; Do a DIR-search-first, using the fcb passed in DE
    push de
    call clear_current_fcb                          ; Clear out current FCB
    pop de

 BDOS_Delete_File_loop:
    push de

    call copy_fcb_to_filename_buffer_preserving_spaces
    ld de, temp_fcb
    ld a, (current_user)
    call CORE_dir                                   ; returns 0 = success, 255 = fail
    cp 255
    jr z, BDOS_Delete_File_done

    ; File found, so delete it

    ld a, 0
    ld (delete_flag), a                             ; Store a success reult

    ld de, temp_fcb
    call copy_fcb_to_filename_buffer
    call CORE_close_file                            ; just in case there is an open one.
    call open_cpm_disk_directory

    ld hl, filename_buffer+2                        ; Specify filename
    call CORE_open_file
    jr nz, delete_error                             ; Don't delete if not found
    call CORE_erase_file

    pop de                                  ; Get original FCB back
    jr BDOS_Delete_File_loop

BDOS_Delete_File_done:
    pop de
    ld a, (delete_flag)
    ld b, 0
	ret

delete_error:
    pop de
    jp return_255_in_a

BDOS_Read_Sequential:
    ; Pass in de -> FCB
    ; Return a = 0 on success, or a = 255 on error
    ; We need to read 128 bytes from the current position of the file referenced in FCB
    ; to DMA address.
    ; If there are less than 128 bytes, made sure the rest is padded with nulls.
    ; Start by checking that the FCB equals the Current FCB.
    ; If not, close the current file and open the new one, jumping to the right place.
    ; If so just proceed.
    ; Then increase the pointer in the FCB and copy it to Current_FCB.
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Read_Seq',13,10,0
    call show_fcb    
    ENDIF

    push de
    call disk_activity_start

    call compare_current_fcb
    jr z, BDOS_Read_Sequential1
    ; Need to close existing file and open the new one.
    ld a, 1                                     ; Open new file but don't update file pointer
    call bdos_open_file_internal
    pop de
    push de
    ; Now jump to the right place in the file
    call get_file_pointer_from_fcb              ; bcde = file pointer
    call multiply_bcde_by_128                   ; bcde = byte location in file
    call CORE_move_to_file_pointer                   ; move to that location
    cp USB_INT_SUCCESS
    jr nz, read_from_file_fail
BDOS_Read_Sequential1:
    ld de, (dma_address)
    call CORE_read_from_file
    jr nz, read_from_file_fail                  ; ADDED IN, BUT MAKES SENSE???
    pop de                                      ; Get the FCB location back
    push de
    call get_file_pointer_from_fcb              ; bcde = file pointer
    call increase_bcde
    pop hl
    call set_file_pointer_in_fcb
    ex de, hl
    call copy_fcb_to_current_fcb                ; Make a note of the state of the currently open file
    call CORE_disk_off
    jp return_0_in_a                            ; Success
read_from_file_fail:
    pop de
    call CORE_disk_off
    ld a, 1                                     ; 1 = seek to unwritten extent
    ld b, 0
    ret

BDOS_Write_Sequential:
    ; Pass in de -> FCB
    ; Return a = 0 on success, or a = 255 on error
    ; We need to write 128 bytes from the current DMA address to the
    ; current position of the file referenced in FCB.
    ; Start by checking that the FCB equals the Current FCB.
    ; If not, close the current file and open the new one, jumping to the right place.
    ; If so just proceed.
    ; Then increase the pointer in the FCB and copy it to Current_FCB.
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Write_Sequential',13,10,0
    call show_fcb
    ENDIF

    push de
    call disk_activity_start
dont_turn_on:    
    call compare_current_fcb
    jr z, BDOS_Write_Sequential1
    ; Need to close existing file and open the new one.
    ld a, 1                                     ; Open new file but don't update file pointer
    call bdos_open_file_internal
    pop de
    push de
    ; Now jump to the right place in the file
    call get_file_pointer_from_fcb              ; bcde = file pointer
    call multiply_bcde_by_128                   ; bcde = byte location in file
    call CORE_move_to_file_pointer                   ; move to that location
    cp USB_INT_SUCCESS
    jr nz, BDOS_Write_Sequential_fail
BDOS_Write_Sequential1:
    ld de, (dma_address)
    call CORE_write_to_file
    call CORE_disk_off
    pop de                                      ; Get the FCB location back
    push de
    call get_file_pointer_from_fcb              ; bcde = file pointer
    call increase_bcde
    pop hl
    call set_file_pointer_in_fcb
    ex de, hl
    call copy_fcb_to_current_fcb                ; Make a note of the state of the currently open file
    jp return_0_in_a

BDOS_Write_Sequential_fail:
    call CORE_disk_off
    jp return_255_in_a

BDOS_Make_File:
    ; Make File passes in DE->FCB
    ; Returns a = 0 for success and a = 255 for failure
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Mk_File',13,10,0
    call show_fcb
    ENDIF

    push de

    call CORE_close_file                                 ; just in case another file is open

    pop de
    push de
    call copy_fcb_to_filename_buffer

    call CORE_disk_on
    call CORE_connect_to_disk
    call CORE_mount_disk

    call open_cpm_disk_directory

    ld de, filename_buffer+2            ; Specify filename
    call CORE_create_file

    jr z, make_file_success

    call CORE_disk_off
    pop de
    call clear_current_fcb                          ; Clear out current FCB because of fail.
    jp return_255_in_a                              ; error
make_file_success:
    call CORE_disk_off
    pop de
    call copy_fcb_to_current_fcb                    ; This is now the currently open file
    jp return_0_in_a

BDOS_Rename_File:
    ; DE points to a FCB with the 
    ; SOURCE filename at FCB+0 and
    ; TARGET filename at FCB+16.
    ; The disk drive must be the same in both names, or else error.
    ; Check if the target file already exists. If so return with error.
    ; Success a = 0
    ; Error a = 255

    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Ren_File',13,10,0
    ENDIF

    push de                                         ; Store source FCB pointer for now
    call CORE_close_file                                 ; just in case there is an open one.

    ;call CORE_message
    ;db 'Source file:',13,10,0
    ;pop de
    ;push de
    ;call show_fcb

    ;call CORE_message
    ;db 'Target file:',13,10,0

    pop de
    push de
    ld hl, 16
    add hl, de
    push hl                                         ; And store the target FCB for now
    ex de, hl

    ;call show_fcb

    ; Try opening target file. If we can then return an error.
    call copy_fcb_to_filename_buffer

    call open_cpm_disk_directory

    ld hl, filename_buffer+2                        ; Specify filename
    call CORE_open_file
    jr z, BDOS_Rename_File_exists

    ; Check if both drives are the same (or the target one is DEFAULT). If not return error.
    pop hl                                          ; retrieve pointer to target file
    ld a, (hl)                                      ; Target file drive letter
    cp 0
    jr z, BDOS_Rename_File_same_drives              ; If target is default, all is good
    pop hl
    push de
    ld b, (hl)                                      ; Source file drive letter
    cp b                                            ; Are drive letters the same?
    jr nz, BDOS_Rename_File_different_drives

BDOS_Rename_File_same_drives:
    ; Open the original file.
    pop de
    push hl                                         ; Store target FCB location
    call copy_fcb_to_filename_buffer
    ld hl, filename_buffer+2                        ; Specify source filename
    call CORE_open_file
    jp nz, BDOS_Rename_File_no_source

    ; Read in the P_FAT_DIR_INFO
    call CORE_dir_info_read    
    jr nz, BDOS_Rename_File_no_source

    ; Update the name.
    pop hl
    inc hl
    ld de, disk_buffer
    ld bc, 11
    ldir

    ; Write it back again.
    call CORE_dir_info_write

    ; Close the file.
    call CORE_close_file

    call clear_current_fcb                          ; Clear out current FCB
    jp return_0_in_a                                ; success
BDOS_Rename_File_exists:
    pop de                                          ; Drain the stack
    pop de
    ;call CORE_message
    ;db 'Target file already exists!',13,10,0
    jp return_255_in_a
BDOS_Rename_File_different_drives:
    pop de                                          ; Drain the stack
    ;call CORE_message
    ;db 'Source and Target files must be on same drive!',13,10,0
    jp return_255_in_a

BDOS_Rename_File_no_source:
    pop de                                          ; Drain the stack
    ;call CORE_message
    ;db 'Can''t find source file!',13,10,0
    jp return_255_in_a

BDOS_Return_Login_Vector:
    ;call show_bdos_message
	;call CORE_message
	;db 'Ret_Log_Vec',13,10,0
    ld hl, $FFFF ; All drives are always logged in
    ld a, l 
    ld b, h
	ret

BDOS_Return_Current_Disk:
    ;call show_bdos_message
	;call CORE_message
	;db 'Ret_Curr_Disk',13,10,0
    ; The value is 0 = A .. 15 = P
    ld a, (current_disk)
    and %00001111                       ; Make sure it is 0-15
    ;push af
    ;add a, 'A'
    ;call CORE_print_a
    ;call newline
    ;pop af
    ld b, 0
	ret

BDOS_Set_DMA_Address:
    ; Pass in de -> DMA Address
    ld (dma_address), de

    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Set_DMA ',0
    ex de, hl
    call CORE_show_hl_as_hex
    call CORE_newline
    ENDIF

    jp return_0_in_a

BDOS_Get_Addr_Alloc:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Get_DSKALLOC',13,10,0
    ENDIF

    ld hl, DISKALLOC
    ld a, l 
    ld b, h
	ret

BDOS_Write_Protect_Disk:
    ;call show_bdos_message
	;call CORE_message
	;db 'Wr_Prot_Disk',13,10,0
    jp return_1_in_a

BDOS_Get_RO_Vector:
    ;call show_bdos_message
	;call CORE_message
	;db 'Get_RO_Vect',13,10,0
    jp return_1_in_a

BDOS_Set_File_Attributes:
    ;call show_bdos_message
	;call CORE_message
	;db 'Set_File_Attr',13,10,0
    jp return_1_in_a

BDOS_Get_Addr_Disk_Parms:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Get_DPB ',0
    ENDIF

    ; Returns address in HL
    ld hl, dpblk
    ld a, l 
    ld b, h
	ret

BDOS_Set_Get_User_Code:
    ;call show_bdos_message
	;call CORE_message
	;db 'Set_Get_User',13,10,0

    ; The user to set is passed in E. This is a value from 0 to 15.
    ; If the value is 255 then we are asking for the current user to be returned in a.

    ld a, e
    cp 255
    jr z, get_user_code
set_user_code:
    ld a, e
    and %00001111           ; Make sure it is 0-15
    ld (current_user), a    ; Store new value
    ld a, (current_disk)
    ld e, a
    call BDOS_Select_Disk   ; Change to the appropriate folder
    ret
get_user_code:
    ld a, (current_user)
    ld b, 0
	ret

BDOS_Read_Random:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Rd_Rnd',13,10,0
    call show_fcb
    ENDIF
BDOS_Read_Random1:    
    push de                                         ; store FCB for now
    call disk_activity_start
    call get_random_pointer_from_fcb                ; random is in hl
    call convert_random_pointer_to_normal_pointer   ; Normal pointer is in bcde
    pop hl                                          ; hl -> fcb
    push hl
    call set_file_pointer_in_fcb                    ; FCB is now up-to-date

    pop de                                          ; de -> FCB
    push de
    ; Need to close any existing open file and open the new one.
    ld a, 1                                         ; Open new file but don't update file pointer
    call bdos_open_file_internal
    pop de
    ; Now jump to the right place in the file
    call get_file_pointer_from_fcb                  ; bcde = file pointer
    call multiply_bcde_by_128                       ; bcde = byte location in file
    call CORE_move_to_file_pointer                  ; move to that location
    ld de, (dma_address)
    call CORE_read_from_file
    jr nz, BDOS_Read_Random2                        ; If fail to read, return error code
    call CORE_close_file                             
    call clear_current_fcb
    call CORE_disk_off
    jp return_0_in_a                                ; success
BDOS_Read_Random2:
    call CORE_close_file                             
    call clear_current_fcb
    call CORE_disk_off
    ld a, 4                                         ; "Seek to unwritten extent" error if we try to read
    ld b, 0                                         ; past the end of the file.
    ret

BDOS_Write_Random:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Write_Rand',13,10,0
    ENDIF
BDOS_Write_Random1:    
    push de                                         ; store FCB for now
    call disk_activity_start
    ;call show_fcb
    call get_random_pointer_from_fcb                ; random is in hl
    call convert_random_pointer_to_normal_pointer   ; Normal pointer is in bcde
    pop hl                                          ; hl -> fcb
    push hl
    call set_file_pointer_in_fcb                    ; FCB is now up-to-date

    pop de                                          ; de -> FCB
    push de
    ; Need to close any existing open file and open the new one.
    ld a, 1                                     ; Open new file but don't update file pointer
    call bdos_open_file_internal
    pop de
    ; Now jump to the right place in the file
    call get_file_pointer_from_fcb              ; bcde = file pointer
    call multiply_bcde_by_128                   ; bcde = byte location in file
    call CORE_move_to_file_pointer                   ; move to that location
    cp USB_INT_SUCCESS
    jr nz, BDOS_Write_Random_fail

    ld de, (dma_address)
    call CORE_write_to_file
    call CORE_close_file                             ; Need to close the file to flush the data out to disk
    call clear_current_fcb

    call CORE_disk_off
    jp return_0_in_a                                ; success

BDOS_Write_Random_fail:
    call CORE_close_file                             ; Need to close the file to flush the data out to disk
    call clear_current_fcb
    call CORE_disk_off
    ld a, 1                                         ; Return error code TODO: 255???
    ld b, 0
	ret

convert_random_pointer_to_normal_pointer:
    ; Pass in random pointer in hl
    ; Returns normal pointer in bcde

    ex de, hl
    ld bc, 0
    ret

BDOS_Compute_File_Size:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Compute_File_Sz',13,10,0
    ENDIF

    ; DE -> FCB
    ; Sets the random-record count bytes part of the FCB to the number of 128-byte records in the file. 
    ; Return A=0 FOR SUCCESS, or 255 if error.

    push de                                         ; Store source FCB pointer for now
    call CORE_close_file                                 ; just in case there is an open one.

    IF DEBUG_BDOS
    call CORE_message
    db 'Compute File Size Source file:',13,10,0
    pop de
    push de
    call show_fcb
    ENDIF

    call copy_fcb_to_filename_buffer

    call open_cpm_disk_directory

    ld hl, filename_buffer+2                        ; Specify filename
    call CORE_open_file
    jr nz, BDOS_Compute_File_Size_not_exist

    ; Read in the P_FAT_DIR_INFO into disk_buffer
    call CORE_dir_info_read    
    jr nz, BDOS_Compute_File_Size_not_exist

    ; Extract the file size into bchl
    ld hl, disk_buffer+$1C
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    ex de, hl                           ; 32-bit filesize now in bchl

    ; Divide by 128
    sla l                               ; Shift all left by 1 bit
    rl h
    rl c
    rl b

    ld l, h
    ld h, c
    ld c, b
    ld b, 0                             ; We've shifted right 8 bits, so effectively divided by 128!

    ; Store in FCB
    pop de                                          ; Get the FCB back
    call CORE_set_random_pointer_in_fcb             ; store hl in FCB random pointer (bc is thrown away!)
    ;call show_fcb

    ; Close the file.
    call CORE_close_file

    jp return_1_in_a

BDOS_Compute_File_Size_not_exist:
    pop de
    jp return_255_in_a

BDOS_Set_Random_Record:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Set_Rand_Rec',13,10,0
    ENDIF

    ; Set the random record count bytes of the FCB to the number of the last record read/written by the sequential I/O calls.
    ; FCB is in DE
    push de
    call get_file_pointer_from_fcb      ; gets sequential pointer into bcde
    ex de, hl                           ; Lowest 16 bits of pointer go into hl
    pop de
    call CORE_set_random_pointer_in_fcb      ; Store hl into random pointer
    jp return_1_in_a

BDOS_Reset_Drive:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Rst_Drv',13,10,0
    ENDIF

    call clear_current_fcb                          ; Clear out current FCB
    jp return_0_in_a

BDOS_38:
    ;call show_bdos_message
	;call CORE_message
	;db '38',13,10,0
    jp return_1_in_a

BDOS_39:
    ;call show_bdos_message
	;call CORE_message
	;db '39',13,10,0
    jp return_1_in_a

BDOS_Write_Random_Zero_Fill:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Write_Rand_0',13,10,0
    ENDIF

    jp BDOS_Write_Random1

BDOS_41:
BDOS_42:
BDOS_43:
BDOS_44:
    ret

BDOS_ERROR_MODE:
    IF DEBUG_BDOS
    call show_bdos_message
	call CORE_message
	db 'Err_Mod',13,10,0
    ENDIF
    ret

BDOS_46:
BDOS_47:
BDOS_48:
    ret

;-------------------------------------------------
;
; This is my understanding of the bytes in a FCB...
; DRIVE     1   0 = default, 1..16 = A..P                                                           0
; FILENAME  8   Filename in ASCII uppercase. Bit 7s are for attributes.                             1-8
; TYPE      3   Extension is ASCII uppercase. Bit 7s are for attributes.                            9-11
; EX        1   Extent Low Byte. An extent is 16384 bytes.                                          12    
; S1        1                                                                                       13
; S2        1   Extent High Byte.                                                                   14
; RC        1   Record count for this extent (0-127)                                                15
; AL        16                                                                                      16-31
; CR        1   Current Record. A record is 128 bytes. But this CR goes 0..127, so max is 16384     32
; RRR       3                                                                                       33-35

; So, to work out the current position in the file you need:
; (S2 * 256 + EX) * 16384  +  CR * 128 = file pointer in bytes
; or (S2 * 256 + EX) * 128  +  CR = file pointer in 128-byte records.
; The result is a 32 bit number.

; This is what we do:
; We have a Current_FCB which represents the current file that the CH376 module has open.
; * If you open a file, that file's FCB gets copied into the Current FCB.
; * If you do a read or write operation on a file, we check if your FCB matches the Current FCB.
;   If it does then we are still talking about the currently open file, so just proceed.
;   If not we need to shut the open file, open this new file, and copy the FCB into the CURRENT FCB.
;   At the end of the operation we increase the file pointer by 128 and update the FCB and the Curr FCB.
; * If you close a file or change directory, we clear the CURRENT FCB.
;
; The "match" process relies on matching the first 12 chars of the FCB.

; routines we need:
; * Clear CURR_FCB
; * Copy FCB to CURR_FCB
; * Compare FCB with CURR_FCB (compare name and file position)
; * Get File Pointer from FCB (it's a 32-bit number)
; * Increase File Pointer
; * Set File Pointer in FCB

initialise_fcb:
    ; Pass in DE -> FCB
    ; Pass in HL -> null-terminated filename
    ; Copy the name into the FCB and set all the other counters to 0.
    ; Return zero-flag-set for success, zero-flag-reset for error. (Invalid filename for example)
    ; Also, preserves DE.
    push de
    ld a, 0
    ld (de), a                          ; Set drive = default
    inc de
    ld b, 8
initialise_fcb1:
    ld a, (hl)                          ; Copy filename
    inc hl
    cp '.'
    jr z, initialise_fcb2
    call is_filename_char_valid            
    jr nz, initialise_fcb_error
    call convert_a_to_uppercase
    ld (de), a
    inc de
    djnz initialise_fcb1
initialise_fcb2                         ; Did we stop before 8 bytes reached?
    ld a, 0
    cp b
    jr z, initialise_fcb3
    ld a, ' '
initialise_fcb4:
    ld (de), a                          ; Pad with spaces up to 8 bytes
    inc de
    djnz initialise_fcb4
initialise_fcb3:
    ld b, 3                             ; Now file extension
initialise_fcb5:
    ld a, (hl)                          ; Copy filename
    inc hl
    cp 0
    jr z, initialise_fcb6               
    call is_filename_char_valid            
    jr nz, initialise_fcb_error
    call convert_a_to_uppercase
    ld (de), a
    inc de
    djnz initialise_fcb5
initialise_fcb6:                        ; Did we stop before 3 bytes reached?
    ld a, 0
    cp b
    jr z, initialise_fcb8
    ld a, ' '
initialise_fcb7:
    ld (de), a                          ; Pad with spaces up to 3 bytes
    inc de
    djnz initialise_fcb7
initialise_fcb8:
    ld b, 24                            ; Put zeros in all the rest of the FCB
    ld a, 0
initialise_fcb9:
    ld (de), a
    inc de
    djnz initialise_fcb9
    pop de
    cp a                                ; set zero flag for success
    ret
initialise_fcb_error:
    pop de
    or 1                                ; clear zero flag for error
    ret    

is_filename_char_valid:
    ; pass in char in a
    ; Return zero set if char is *, ?, 0-9 or a-z or A-Z or _
    cp '*'
    ret z
    cp '0'
    jr c, is_filename_char_valid_no
    cp 127
    jr nc, is_filename_char_valid_no
    cp a                                ; set zero flag for success
    ret
is_filename_char_valid_no:
    or 1                                ; clear zero flag for error
    ret    

convert_a_to_uppercase:
    cp 'a'
    ret c
    cp 'z'+1
    ret nc
    sub 32
    ret

set_file_pointer_in_fcb:
    ; Pass HL -> FCB (Note that this is an unusual way to pass it in)
    ; Pass file pointer (in 128-byte records) in bcde.
    ; Preserves hl

    ; Split bcde into S2, EX & CR.
    ; To do this:
    ; CR = e & %01111111                (i.e. a number 0..127)
    ; Divide bcde by 128                (Shift right 7 bits, or shift left 1 bit then right 8)
    ; EX = e, S2 = d
    ; TODO: Test if this is correct. Note that the logic in set_file_size_in_fcb is different!?!?!?
    ; The difference would only be apparent for files > 496K in size.

    push hl
    ld a, e
    and %01111111
    push af                             ; Store CR for now

    sla e                               ; Shift all left by 1 bit
    rl d
    rl c
    rl b

    ld e, d
    ld d, c
    ld c, b
    ld b, 0                             ; We've shifted right 8 bits, so effectively right 7

    pop af                              ; Now a=CR, e = EX, d = S2

    ld bc, 12
    add hl, bc                          ; hl -> FCB.EX
    ld (hl), e

    inc hl
    inc hl                              ; hl -> FCB.S2
    ld (hl), d
    
    ld bc, 18
    add hl, bc                          ; hl -> FCB.CR
    ld (hl), a

    pop hl
    ret

get_random_pointer_from_fcb:
    ; pass in de -> fcb
    ; Random pointer is in fcb + 33 & 34.
    ; return it in hl
    ; preserve de
    push de
    ex de, hl
    ld bc, 33
    add hl, bc
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
    pop de
    ret


get_file_pointer_from_fcb:
    ; Pass in DE -> FCB
    ; file pointer in 128-byte records =  (S2 * 256 + EX) * 128  +  CR
    ; 32-bit result is returned in bcde
    ex de, hl
    ld bc, 12
    add hl, bc                          ; hl -> FCB.EX
    ld e, (hl)                          ; e = EX
    inc hl
    inc hl
    ld d, (hl)                          ; d = S2
    ld bc, 18
    add hl, bc                          ; hl -> FCB.CR
    ld c, (hl)                          ; c = CR
    ld b, 0
    push bc                             ; Store 16-bit version of CR for now
    ld bc, 0                            ; 32-bit value of DE is now in BCDE
    call multiply_bcde_by_128
    pop hl                              ; Retrieve 16-bit version of CR
    add hl, de
    ex de, hl                           ; de holds low 16 bits of result
    ld h, b
    ld l, c
    ld bc, 0
    adc hl, bc
    ld b, h
    ld c, l                             ; bcde is the 32-bit result
    ret

multiply_bcde_by_128:
    ; Pass in 32-bit number in BCDE
    ; Result is returned in BCDE
    ; Multiply by 128 is same as shift left 8 bits then shift right 1 bit
    ld b, c
    ld c, d
    ld d, e
    ld e, 0                             ; That's shift-left-8-bits done.
    srl b
    rr c
    rr d
    rr e                                ; That's shift-right-1-bit done.
    ret

increase_bcde:
    ; Pass in 32-bit number in BCDE
    ; Increase it by 1.
    ; Result is returned in BCDE
    ld a, 1
    add a, e
    ld e, a
    ld a, 0
    adc a, d
    ld d, a
    ld a, 0
    adc a, c
    ld c, a
    ld a, 0
    adc a, b
    ld b, a
    ret

clear_current_fcb:
    ; Clears the entire current FCB
    ld de, current_fcb+1
    ld hl, current_fcb
    ld a, 0
    ld (hl), a
    ld bc, 11
    ldir
    ret

copy_fcb_to_current_fcb:
    ; Pass in DE -> FCB
    ; This copies the whole of that FCB into the current one and preserves DE.
    push de
    ld hl, current_fcb
    ex de,hl
    ld bc, 36
    ldir
    pop de
    ret

compare_current_fcb_name:
    ; Compares the directory, filename and extension in one FCB with the current one.
    ; pass in de -> fcb
    push de
    ld hl, current_fcb
    ld b, 12
compare_current_fcb_name1:
    ld a, (de)
    cp (hl)
    jr nz, compare_current_fcb_fail
    inc de
    inc hl
    djnz compare_current_fcb_name1
    pop de
    cp a                                ; set zero flag for success
    ret
compare_current_fcb_fail:
    pop de
    or 1                                ; clear zero flag for error
    ret

compare_current_fcb_pointer:
    ; pass in de -> fcb
    ; Compares cr, ex and s2
    push de
    ld hl, current_fcb
    ld bc, 12
    add hl, bc
    ex de, hl                           ; de -> currenct_fcb.ex
    add hl, bc                          ; hl -> fcb.ex
    ld a, (de)
    cp (hl)                             ; Compare EXs
    jr nz, compare_current_fcb_fail
    inc hl
    inc hl
    inc de
    inc de
    ld a, (de)
    cp (hl)                             ; Compare S2s
    jr nz, compare_current_fcb_fail
    ld bc, 18
    add hl, bc
    ex de, hl
    add hl, bc
    ld a, (de)
    cp (hl)                             ; Compare CRs
    jr nz, compare_current_fcb_fail
    pop de
    cp a                                ; set zero flag for success
    ret

compare_current_fcb:
    ; Pass in de -> FCB
    ; This gets compared to the Current_FCB.
    ; Return z if the same.
    ; Preserves de.
    call compare_current_fcb_name
    ret nz
    call compare_current_fcb_pointer
    ret

show_fcb:
    ; Pass in de -> fcb
    ; Shows the FCB on screen.
    ; Preserves DE
    push de
    call CORE_message
    db 'FCB: ',0

    ; Show Drive Letter
    ld a, (de)
    inc de
    cp 0
    jr z, show_fcb1
    add a, 'A'-1
    call CORE_print_a
    ld a, ':'
    call CORE_print_a
    call CORE_space
    jr show_fcb2

show_fcb1:
    call CORE_message
    db 'dflt: ',0
show_fcb2:
    ; Show filename
    ld b, 8
show_fcb3:
    ld a, (de)
    inc de
    call CORE_print_a
    djnz show_fcb3
show_fcb4:
    ; Show ext
    ld a, '.'
    call CORE_print_a
    ld b, 3
show_fcb5:
    ld a, (de)
    and %01111111
    inc de
    call CORE_print_a
    djnz show_fcb5
show_fcb_end:
    pop de
    push de

    call get_file_pointer_from_fcb              ; info comes back in bcde
    call CORE_message
    db ', ptr: ',0
    call show_bcde_as_hex
    call CORE_message
    db ', rand: ',0
    pop de
    push de
    call get_random_pointer_from_fcb            ; Gets the random record pointer in hl
    call CORE_show_hl_as_hex
    call CORE_newline
    pop de
    ret

show_bcde_as_hex:
    ; Show the number in bcde as hex
    ; Preserves bc & de
    ld a, b
    call CORE_show_a_as_hex
    ld a, c
    call CORE_show_a_as_hex
    ld a, d
    call CORE_show_a_as_hex
    ld a, e
    call CORE_show_a_as_hex
    ret

copy_fcb_to_filename_buffer:
    ; Pass in de -> fcb
    ; Transfer all the filename from fcb to the filename_buffer.
    ; Skip NULLs spaces and add in the ".", and terminate with NULL.
    ; Preserves de.
    push de
    ex de, hl                   ; hl = fcb
    ld de, filename_buffer      ; de = filename_buffer
    ld a, (hl)                  ; First byte in FCB is 0 or 1-16. We want 0=>A, 15=>P
    cp 0
    jr nz, copy_fcb_to_filename_buffer1
    ld a, (current_disk)
    inc a                       ; Adjust 0-15 to 1-16
copy_fcb_to_filename_buffer1:
    add a, 'A'-1
    ld (de), a
    inc de
    ld a, '/'
    ld (de), a
    inc de
    inc hl
    push hl
    ld b, 8
copy_fcb1:
    ld a, (hl)
    inc hl
    cp 0
    jr z, copy_fcb2
    cp ' '
    jr z, copy_fcb2
    ld (de), a
    inc de
    djnz copy_fcb1
copy_fcb2:
    ld a, '.'                   ; Put in the dot
    ld (de), a
    inc de

    pop hl
    ld bc, 8
    add hl, bc                   ; Move along to extension
    ld b, 3
copy_fcb3:
    ld a, (hl)
    inc hl
    cp 0
    jr z, copy_fcb4
    cp ' '
    jr z, copy_fcb4
    ld (de), a
    inc de
    djnz copy_fcb3
copy_fcb4:
    ld a, 0
    ld (de),a
    pop de
    ret

copy_fcb_to_filename_buffer_preserving_spaces:
    ; Pass in de -> fcb
    ; Transfer all the filename from fcb to the filename_buffer.
    ; Skip NULLs spaces and add in the ".", and terminate with NULL.
    ; Preserves de.
    push de
    ex de, hl                   ; hl = fcb
    ld de, filename_buffer      ; de = filename_buffer
    ld a, (hl)                  ; First byte in FCB is 0 or 1-16. We want 0=>A, 15=>P
    cp 0
    jr nz, copy_fcb_to_filename_ps_buffer1
    ld a, (current_disk)
    inc a                       ; Adjust 0-15 to 1-16
copy_fcb_to_filename_ps_buffer1:
    add a, 'A'-1
    ld (de), a
    inc de
    ld a, '/'
    ld (de), a
    inc de
    inc hl
    push hl
    ld b, 8
copy_fcb1_ps:
    ld a, (hl)
    inc hl
    cp 0
    jr z, copy_fcb2_ps
    ld (de), a
    inc de
    djnz copy_fcb1_ps
copy_fcb2_ps:
    ld a, '.'                   ; Put in the dot
    ld (de), a
    inc de

    pop hl
    ld bc, 8
    add hl, bc                   ; Move along to extension
    ld b, 3
copy_fcb3_ps:
    ld a, (hl)
    inc hl
    cp 0
    jr z, copy_fcb4_ps
    ld (de), a
    inc de
    djnz copy_fcb3_ps
copy_fcb4_ps:
    ld a, 0
    ld (de),a
    pop de
    ret

disk_activity_start:
    call CORE_disk_off
    ld a, (disk_flash)
    cpl
    ld (disk_flash), a
    cp 0
    ret z
    call CORE_disk_on
    ret

BDOS_jump_table:
dw BDOS_System_Reset                ;equ 0        00
dw BDOS_Console_Input               ;equ 1        01
dw BDOS_Console_Output              ;equ 2        02
dw BDOS_Reader_Input                ;equ 3        03
dw BDOS_Punch_Output                ;equ 4        04
dw BDOS_List_Output                 ;equ 5        05
dw BDOS_Direct_Console_IO           ;equ 6        06
dw BDOS_Get_IO_Byte                 ;equ 7        07
dw BDOS_Set_IO_Byte                 ;equ 8        08
dw BDOS_Print_String                ;equ 9        09
dw BDOS_Read_Console_Buffer         ;equ 10       0A
dw BDOS_Get_Console_Status          ;equ 11       0B
dw BDOS_Return_Version_Number       ;equ 12       0C
dw BDOS_Reset_Disk_System           ;equ 13       0D
dw BDOS_Select_Disk                 ;equ 14       0E
dw BDOS_Open_File                   ;equ 15       0F
dw BDOS_Close_File                  ;equ 16       10
dw BDOS_Search_for_First            ;equ 17       11
dw BDOS_Search_for_Next             ;equ 18       12
dw BDOS_Delete_File                 ;equ 19       13
dw BDOS_Read_Sequential             ;equ 20       14
dw BDOS_Write_Sequential            ;equ 21       15
dw BDOS_Make_File                   ;equ 22       16
dw BDOS_Rename_File                 ;equ 23       17
dw BDOS_Return_Login_Vector         ;equ 24       18
dw BDOS_Return_Current_Disk         ;equ 25       19
dw BDOS_Set_DMA_Address             ;equ 26       1A
dw BDOS_Get_Addr_Alloc              ;equ 27       1B
dw BDOS_Write_Protect_Disk          ;equ 28       1C
dw BDOS_Get_RO_Vector               ;equ 29       1D
dw BDOS_Set_File_Attributes         ;equ 30       1E
dw BDOS_Get_Addr_Disk_Parms         ;equ 31       1F
dw BDOS_Set_Get_User_Code           ;equ 32       20
dw BDOS_Read_Random                 ;equ 33       21
dw BDOS_Write_Random                ;equ 34       22
dw BDOS_Compute_File_Size           ;equ 35       23
dw BDOS_Set_Random_Record           ;equ 36       24
dw BDOS_Reset_Drive                 ;equ 37       25
dw BDOS_38
dw BDOS_39
dw BDOS_Write_Random_Zero_Fill      ;equ 40       28
dw BDOS_41
dw BDOS_42
dw BDOS_43
dw BDOS_44
dw BDOS_ERROR_MODE                  ; eq 45       2D
dw BDOS_46
dw BDOS_47
dw BDOS_48

filesize_buffer:
    ds 6

filesize_buffer_copy:
    ds 6

filesize_units:
    ds 1

current_fcb:
    ; We store a copy of the FCB of the currently open file here
    ds 36

;current_disk:
;    ds 1

disk_flash:
    db 0

;
dpblk:	
; Fake disk parameter block for all disks
	; defw	80		;sectors per track
	; defb	5		;block shift factor	(5 & 31 = 4K Block Size)
	; defb	31		;block mask
	; defb	3		;extent mask
	; defw	196		;disk size 197 * 4k = 788k
	; defw	127		;directory max
	; defb	$80		;alloc 0	((DRM + 1) * 32) / 4096 = 1, so 80H
	; defb	0		;alloc 1
	; defw	0		;check size ( 0 = fixed disk )
	; defw	0		;track offset ( 0 = no reserved system tracks )

; These ones were copied from runCPM!
	defw	64		;sectors per track
	defb	5		;block shift factor	(5 & 31 = 4K Block Size)
	defb	$1F		;block mask
	defb	1		;extent mask
	defb	$FF		;disk size
	defb	$07		;disk size
	defb	$FF		;directory max
	defb	$03		;directory max
	defb	$FF		;alloc 0	((DRM + 1) * 32) / 4096 = 1, so 80H
	defb	0		;alloc 1
	defw	0		;check size ( 0 = fixed disk )
	defw	2		;track offset ( 0 = no reserved system tracks )

DISKALLOC:
    db 0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0

; typedef  struct _FAT_DIR_INFO {
; 	UINT8 DIR_Name[ 11 ];					/* 00H, file name, a total of 11 bytes, fill in blanks for deficiencies */
; 	UINT8 DIR_Attr;						    /* 0BH, file attribute, refer to the following description */
; 	UINT8 DIR_NTRes;						/* 0CH */
; 	UINT8 DIR_CrtTimeTenth;				    /* 0DH, the time of file creation, counted in units of 0.1 seconds */
; 	UINT16 DIR_CrtTime;					    /* 0EH, file creation time */
; 	UINT16 DIR_CrtDate;					    /* 10H, file creation date */
; 	UINT16 DIR_LstAccDate;					/* 12H, the date of the last access operation */
; 	UINT16 DIR_FstClusHI;					/* 14H */
; 	UINT16 DIR_WrtTime;					    /* 16H, file modification time */
; 	UINT16 DIR_WrtDate;					    /* 18H, file modification date  */
; 	UINT16 DIR_FstClusLO;					/* 1AH */
; 	UINT32 DIR_FileSize;					/* 1CH, file length */
; } 

dma_address:
    ds 2

; TODO: This is in BDOS.asm and MemoeryStick.asm.
; It should only be here!
CPM_FOLDER_NAME:
    db '/CPM',0
CPM_DISKS_NAME:
    db 'DISKS',0

current_disk:
    db 0
current_user:
    db 0

temp_fcb:
    ds 36

delete_flag:
    db 0

; TODO these should only live in the CORE.
YES_OPEN_DIR equ $41
USB_INT_SUCCESS equ $14

