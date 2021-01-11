; CORE.ASM
; These are Z80-Playground-specific routines that are available for CP/M or other
; programs to use. They include routines for sending chars to the screen, reading
; from the keyboard, and dealing with the USB Drive.
; There is also a small monitor, so if you want to configure the INT
; button to take you to the monitor, you can.

; CORE takes the top 3K of memory, $F400 - $FFFF
; It assembles to 2.53K

include "locations.asm"

    org CORE_START

; CORE internal jump table
; For future-proofing, all calls are via this jump table.
; From external code just jump to "CORE_configure_uart" or similar, which then jumps to "configure_uart".
; That way you can change the value of CORE_ORG, re-assemble this file, then in other files
; just include the external jump table.
; That way it doesn't matter if these routines change location or size, you can always access them from the jump table.
CORE_start_monitor:
    ; Start the debugging monitor
    jp unimplemented_start_monitor
CORE_configure_uart:
    ; Configures the 16550 UART after a reset, setting the baud rate etc.    
    jp configure_uart
CORE_print_a:
    ; Prints whatever is in A to the screen, as a character.
    jp print_a
CORE_char_in:
    ; Reads a character from the keyboard into A
    jp char_in
CORE_char_available:
    ; Checks whether a character is available from the keyboard, without actually reading it
    jp char_available
CORE_short_pause:
    jp short_pause
CORE_medium_pause:
    jp medium_pause
CORE_long_pause:
    jp long_pause

CORE_disk_toggle:
    jp disk_toggle
CORE_disk_on:
    jp disk_on
CORE_disk_off:
    jp disk_off

CORE_user_toggle:
    jp user_toggle
CORE_user_on:
    jp user_on
CORE_user_off:
    jp user_off

CORE_rom_toggle:
    jp rom_toggle
CORE_rom_on:
    jp rom_on
CORE_rom_off:
    jp rom_off

CORE_newline:
    ; Prints a CR/NL combo
    jp newline
CORE_space:
    ; prints a space
    jp space

CORE_message:
    jp message
CORE_show_hl_as_hex:
    jp show_hl_as_hex
CORE_show_all:
    jp show_all

CORE_dir:
    jp dir
CORE_dir_next:
    jp dir_next
CORE_load_bin_file:
    jp load_bin_file
CORE_dir_info_read:
    jp dir_info_read
CORE_dir_info_write:
    jp dir_info_write
CORE_write_to_file:
    jp write_to_file
CORE_erase_file:
    jp erase_file
CORE_check_cpmdisks_structure:
    jp check_cpmdisks_structure
CORE_move_to_file_pointer:
    jp move_to_file_pointer
CORE_set_random_pointer_in_fcb:
    jp set_random_pointer_in_fcb
CORE_copy_filename_to_buffer:
    jp copy_filename_to_buffer
CORE_open_file:
    jp open_file
CORE_create_directory
    jp create_directory
CORE_close_file:
    jp close_file
CORE_read_from_file:
    jp read_from_file
CORE_connect_to_disk:
    jp connect_to_disk
CORE_mount_disk:
    jp mount_disk
CORE_create_file:
    jp create_file
CORE_show_a_as_hex:
    jp show_a_as_hex
CORE_convert_user_number_to_folder_name:
    jp convert_user_number_to_folder_name


include "uart.asm"
include "message.asm"
include "memorystick.asm"

filename_buffer equ 65535-20
DRIVE_NAME equ filename_buffer-2
disk_buffer equ DRIVE_NAME-36
