; memorystick.asm

;-----------------------------------------------------------------
; For DIRectory listing, the filename is passed in the filename_buffer.
; DE -> DMA AREA
; a = Current User
; It will be something like A/ffffffff.xxx
; A result gets put into the area pointed to by DE, normally the DMA area, in 8.3 format
dir:
    push de
    push af
    call disk_on
    call connect_to_usb_drive
    jr z, can_do_dir

    pop af
    pop de
    call message
    db 'ERROR: Cannot read USB Disk.',13,10,0
    call disk_off
    ret

can_do_dir:
    ; at this point DE is on stack, containing address of dma-area
    call connect_to_disk
    call mount_disk

    ;call message
    ;db 'USB DIR for ', 0
    ;call show_filename_buffer

    ld hl, CPM_FOLDER_NAME                    ; Start at /CPM
    call open_file
    ld hl, CPM_DISKS_NAME                    ; Then DISKS
    call open_file

    ld hl, filename_buffer
    ld a, (hl)
    ld hl, DRIVE_NAME                       ; Move to "A" .. "P" for required disk
    ld (hl), a
    inc hl
    ld (hl), 0
    dec hl
    call open_file

    ; Now user number (if greater than 0)
    pop af
    cp 0
    jr z, ignore_user

    call convert_user_number_to_folder_name
    ld hl, DRIVE_NAME                   ; Move to "1" .. "F" for required user
    ld (hl), a
    inc hl
    ld (hl), 0
    dec hl
    call open_file

ignore_user:
    ld hl, STAR_DOT_STAR                    ; Specify search pattern "*"
    call open_file

    ; Read a file if there is something to read
dir_loop:
    ; at this point DE is on stack, containing address of dma-area
    cp USB_INT_DISK_READ
    jr z, dir_loop_good

    cp ERR_MISS_FILE    ; This is what you normally get at the end of a dir listing
    jr z, dir_no_file

    cp ERR_BPB_ERROR    ; This means a disk format error
    jr nz, dir_no_file

    call message
    db 'USB Drive ERROR: FAT only!',13,10,0
dir_no_file:
    pop de
    call disk_off
    ld a, 255
    ret

dir_loop_good:
    ; at this point DE is on stack, containing address of dma-area
    ld a, RD_USB_DATA0
    call send_command_byte
    call read_data_byte                 ; Find out how many bytes there are to read

    call read_data_bytes_into_buffer    ; read them into disk_buffer
    cp 32                               ; Did we read at least 32 bytes?
    jr nc, good_length
    pop de
    jp dir_next

good_length:
    ; at this point DE is on stack, containing address of dma-area
    ; Get the attributes for this entry. $02 = system, $04 = hidden, $10 = directory
    call disk_off
    ld a, (disk_buffer+11)
    and $16                         ; Check for hidden or system files, or directories
    jp z, it_is_not_system          
    pop de                          ; get de back off stack
    jp dir_next                     ; and skip accordingly.

it_is_not_system:
    ; Does it match the search pattern?
    ld b, 11
    ld hl, disk_buffer
    ld de, filename_buffer+2
matching_loop:
    ; If the filename_buffer has a '.' then skip over it 
    ; and move disk_buffer to start of extension
    ld a, (de)
    cp '.'
    jr nz, matching_loop1

    inc de
    ld hl, disk_buffer+8
    ld b, 3

matching_loop1    
    ld a, (de)
    cp '?'
    jr z, matching_loop_good
    cp (hl)
    jr z, matching_loop_good
    pop de                      ; retrieve de
    jr dir_next

matching_loop_good:
    inc de
    inc hl
    djnz matching_loop

    ; Copy 11 byte filename + extension
    ld bc, 11
    ld hl, disk_buffer
    pop de                  ; retrive de, the location to copy to
    push de                 ; push de again
    ld a, 0
    ld (de), a
    inc de
    ldir

    ; Fill in a few more details. File size into normal place, plus random record info.
    ; The filesize is a 32 bit number in FAT_DIR_INFO at loc $1C, 1D, 1E and 1F.
    ; We want it in 128 byte sectors, so need to divide by 128.
    ld hl, disk_buffer+$1C 
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)                          ; BCDE has file size
    ex de, hl                           ; 32-bit filesize now in BCHL

    ; Divide by 128
    sla l                               ; Shift all left by 1 bit
    rl h
    rl c
    rl b

    ld h, l
    ld h, c
    ld c, b
    ld b, 0                             ; We've shifted right 8 bits, so effectively divided by 128!

    pop de
    push de
    call set_random_pointer_in_fcb      ; store hl in FCB random pointer (bc is thrown away!)

    ;ld bc, 0
    ;ld de, 1
    ;call set_file_pointer_in_fcb

    ; Show what we are returning:
    ;call message 
    ;db 'Ret ',0
    ;ld de, (dma_address)
    ;ld b, 11
good_length1:
    ld a, 0                                 ; 0 = success
    pop de                                  ; retrieve de
    ret

dir_next:
    push de
    ld a, FILE_ENUM_GO                      ; Go to next entry in the directory
    call send_command_byte

    call read_status_byte
    jp dir_loop

;-----------------------------------------
; Load bin File
; The filename needs to be in the filename buffer.
; The file must be in the /CPM folder.
; DE points to the location to load it into.
; The file is loaded into the workspace.
; There is no check whether the file is too big!!!!
; Returns zero flag set if success, zero flag cleared on file-not-found.

load_bin_file:
    push de                             ; Store target location for later
    call disk_on
    call connect_to_disk
    call mount_disk

    ld hl, CPM_FOLDER_NAME              ; Start at /CPM
    call open_file

    ld hl, filename_buffer              ; Specify filename
    call open_file

    jr z, load_file_found
    call disk_off
    call message
    db 'File not found ',0
    ld hl, filename_buffer
load_file1:
    ld a, (hl)
    cp 0
    jr z, load_file2
    call print_a
    inc hl
    jr load_file1
load_file2:
    call newline
    pop de                              ; Keep stack clear!
    or 1                                ; Clear zero flag for failure
    ret
load_file_found:
    call disk_off
    ld a, BYTE_READ
    call send_command_byte
    ld a, 255                           ; Request all of the file
    call send_data_byte
    ld a, 255                           ; Yes, all!
    call send_data_byte

    ld a, GET_STATUS
    call send_command_byte
    call read_data_byte
    pop hl                              ; Get back the target address
load_loop1:
    cp USB_INT_DISK_READ
    jr nz, load_finished

    push hl
    call disk_on
    ld a, RD_USB_DATA0
    call send_command_byte
    call read_data_byte
    pop hl
    call read_data_bytes_into_hl        ; Read this block of data
    push hl
    call disk_off
    ld a, BYTE_RD_GO
    call send_command_byte
    ld a, GET_STATUS
    call send_command_byte
    call read_data_byte
    pop hl
    jp load_loop1
load_finished:
    push hl
    call close_file
    pop hl
    cp a                                ; set zero flag for success
    ret

; ---------------------------------
; Directory info read.
; Reads a directory entry (of the currently open file) into disk_buffer
; Returns ZERO FLAG = set if ok
dir_info_read:
    ld a, DIR_INFO_READ
    call send_command_byte
    ld a, $FF                           ; Current open file
    call send_data_byte

    call read_status_byte
    cp USB_INT_SUCCESS
    ret nz

    ld a, RD_USB_DATA0
    call send_command_byte
    call read_data_byte                 ; Find out how many bytes there are to read

    call read_data_bytes_into_buffer
    cp $20                              ; Must have read 32 bytes
    ret nz                              ; or else it is an error
    ;call message
    ;db 'Read this many bytes: ',0
    ;call show_a_as_hex
    ;call newline

;     ld b, $20
;     ld hl, disk_buffer
; dir_info_read1:
;     ld a, (hl)
;     push hl
;     push bc
;     call print_a
;     ld a, ','
;     call print_a
;     pop bc
;     pop hl
;     inc hl
;     djnz dir_info_read1
;     call newline

    cp a                                ; set zero flag for success
    ret

; DIR_INFO_WRITE
; writes a dir_info block from disk_buffer to the USB drive
; for the currently open file
dir_info_write:
    ld a, DIR_INFO_READ
    call send_command_byte
    ld a, $FF                           ; Current open file
    call send_data_byte

    call read_status_byte
    ;call report_on_status
    cp USB_INT_SUCCESS
    ret nz

    ld a, WR_OFS_DATA
    call send_command_byte
    ld a, 0
    call send_data_byte
    ld a, $20
    call send_data_byte
    ld b, $20
    ld hl, disk_buffer
dir_info_write1:
    ld a, (hl)
    push hl
    push bc
    call send_data_byte
    pop bc
    pop hl
    inc hl
    djnz dir_info_write1

    ld a, DIR_INFO_SAVE
    call send_command_byte
    call read_data_byte
    ;call report_on_status
    ret

;----------------------------------
; WRITE TO FILE

write_to_file:
    ; writes 128 bytes from current location pointed to by DE, to the open file
    push de
    ld a, BYTE_WRITE
    call send_command_byte

    ; Send number of bytes we are about to write, as 16 bit number, low first
    ld a, 128
    call send_data_byte
    ld a, 0
    call send_data_byte

    pop hl                              ; hl -> the data

write_loop
    call read_status_byte
    cp USB_INT_DISK_WRITE
    jr nz, write_finished

    push hl
    ; Ask if we can send some bytes
    ld a, WR_REQ_DATA
    call send_command_byte
    call read_data_byte
    pop hl
    cp 0
    jr z, write_finished

    ;push hl
    ;push af
    ;call message
    ;db 'Bytes to send: ',0
    ;pop af
    ;push af
    ;call show_a_as_hex
    ;call newline
    ;pop af
    ;pop hl

    ld b, a
block_loop:
    ld a, (hl)
    push hl
    push bc
    call send_data_byte
    pop bc
    pop hl
    inc hl
    djnz block_loop

    push hl
    ld a, BYTE_WR_GO
    call send_command_byte
    pop hl
    jp write_loop

write_finished:
    ret

    
;-------------------------------------------
; ERASE FILE

erase_file:
    ld a, SET_FILE_NAME
    call send_command_byte
    ld hl, filename_buffer
    call send_data_string
    ld a, FILE_ERASE
    call send_command_byte
    call read_status_byte
    ret

show_filename_buffer:
    ld hl, filename_buffer
    ld b, 20
show_filename_buffer1:
    ld a, (hl)
    cp 32
    jr c, control_char
show_filename_buffer2    
    call print_a
    inc hl
    djnz show_filename_buffer1
    call newline
    ret

control_char:
    add a, 64
    ld c, a
    ld a, '^'
    call print_a
    ld a, c
    jr show_filename_buffer2

check_cpmdisks_structure:
    ; Check that we have a disk structure like this:
    ; /CPMDISKS
    ;          /A
    ;          /B
    ;          /C
    ;          :
    ;          /P

    ; Loop over A..P
    ld b, 16
check_cpmdisk_loop:
    push bc
    ; Go to /CPM
    call message
    db 'Checking /CPM',13,10,0

    ld hl, CPM_FOLDER_NAME
    call copy_filename_to_buffer
    ld hl, filename_buffer
    call open_file
    cp YES_OPEN_DIR                     ; This is NOT an error, it is a badly named success code!!!!!!
    jr nz, check_cpmdisks_structure2

    call message
    db 'Checking /CPM/DISKS',13,10,0
    ld hl, CPM_DISKS_NAME
    call copy_filename_to_buffer
    ld hl, filename_buffer
    call open_file
    cp YES_OPEN_DIR                     ; This is NOT an error, it is a badly named success code!!!!!!
    jr nz, check_cpmdisks_structure2

    pop bc
    push bc
    ld a, b
    add a, 'A'-1
    ld (filename_buffer), a
    ld a, 0
    ld (filename_buffer+1),a
    ld hl, filename_buffer
    call open_file
    cp YES_OPEN_DIR                     ; This is NOT an error, it is a badly named success code!!!!!!
    jr nz, check_cpmdisks_structure3

    pop bc                              ; Let's say if we find disk "P" then they are all there!!!
    ;djnz check_cpmdisk_loop

    ret

check_cpmdisks_structure2:
    pop bc
    ; Try to create the missing folder
    ;ld hl, CPMDISKS_NAME
    ;call copy_filename_to_buffer
    call create_directory
    jr nz, check_cpmdisks_structure_fail

    ; Start all over again
    jp check_cpmdisks_structure

check_cpmdisks_structure3:
    call create_directory
    jr nz, check_cpmdisks_subdir_fail
    pop bc                                          ; All good, so do the next subdir
    jp check_cpmdisk_loop

check_cpmdisks_subdir_fail:
    pop bc
    ; Continue through to the next bit...
check_cpmdisks_structure_fail:
    call message
    db 'ERROR creating CP/M disks!',13,10,0
    ret

move_to_file_pointer:
    ; Set the BYTE_LOCATE file position in the currently open file.
    ; Value is passed in bcde.
    push bc
    push de
    ld a, BYTE_LOCATE
    call send_command_byte
    pop de
    push de
    ld a, e
    call send_data_byte
    pop de
    ld a, d
    call send_data_byte
    pop bc
    push bc
    ld a, c
    call send_data_byte
    pop bc
    ld a, b
    call send_data_byte
    call read_status_byte
    cp USB_INT_SUCCESS
    jr nz, byte_locate_fail                 ; We expect USB_INT_SUCCESS here

    ld a, USB_INT_SUCCESS                   ; Return success
    ret
move_to_file_pointer_fail:
    ld a, USB_INT_DISK_ERR                  ; Return fail
    ret

byte_locate_fail:
    ret

set_random_pointer_in_fcb:
    ; pass in de -> fcb
    ; Pass hl = random pointer value
    ; Random pointer goes to fcb + 33 & 34. fcb + 35 gets 0.
    ; preserve de
    push de
    ex de, hl
    ld bc, 33
    add hl, bc
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ld (hl), 0
    ex de, hl
    pop de
    ret

convert_user_number_to_folder_name:
    ; Pass in 1 to 15 in A.
    ; This returns "1" to "F"
    and %00001111
    add a, '0'                             ; Convert 1-9 => "1".."9"
    cp ':'
    ret c
    add a, 7
    ret

include "memorystick_low_level.asm"

ROOT_NAME:
    db '/',0

STAR_DOT_STAR:
    db '*',0

CPM_FOLDER_NAME:
    db '/CPM',0
CPM_DISKS_NAME:
    db 'DISKS',0



