; core_jump.asm
;
; This is the jump table for the CORE routines.
; Instead of including core.asm, you can just include this, assuming that core.bin is already loaded.
;
include "port_numbers.asm"


CORE_start_monitor equ CORE_START+0
CORE_configure_uart  equ CORE_START+3
CORE_print_a equ CORE_START+6
CORE_char_in equ CORE_START+9
CORE_char_available equ CORE_START+12
CORE_short_pause equ CORE_START+15
CORE_medium_pause equ CORE_START+18
CORE_long_pause equ CORE_START+21
CORE_disk_toggle equ CORE_START+24
CORE_disk_on equ CORE_START+27
CORE_disk_off equ CORE_START+30
CORE_user_toggle equ CORE_START+33
CORE_user_on equ CORE_START+36
CORE_user_off equ CORE_START+39
CORE_rom_toggle equ CORE_START+42
CORE_rom_on equ CORE_START+45
CORE_rom_off equ CORE_START+48
CORE_newline equ CORE_START+51
CORE_space equ CORE_START+54
CORE_message equ CORE_START+57
CORE_show_hl_as_hex equ CORE_START+60
CORE_show_all equ CORE_START+63
CORE_dir equ CORE_START+66
CORE_dir_next equ CORE_START+69
CORE_load_bin_file equ CORE_START+72
CORE_dir_info_read equ CORE_START+75
CORE_dir_info_write equ CORE_START+78
CORE_write_to_file equ CORE_START+81
CORE_erase_file equ CORE_START+84
CORE_check_cpmdisks_structure equ CORE_START+87
CORE_move_to_file_pointer equ CORE_START+90
CORE_set_random_pointer_in_fcb equ CORE_START+93
CORE_copy_filename_to_buffer equ CORE_START+96
CORE_open_file equ CORE_START+99
CORE_create_directory equ CORE_START+102
CORE_close_file equ CORE_START+105
CORE_read_from_file equ CORE_START+108
CORE_connect_to_disk equ CORE_START+111
CORE_mount_disk equ CORE_START+114
CORE_create_file equ CORE_START+117
CORE_show_a_as_hex equ CORE_START+120
CORE_convert_user_number_to_folder_name equ CORE_START+123


filename_buffer equ 65535-20
DRIVE_NAME equ filename_buffer-2
disk_buffer equ DRIVE_NAME-36

core_location equ disk_buffer-2         ; Stores the core_start location
bios_location equ core_location-2       ; Stores the bios_start location
bdos_location equ bios_location-2       ; Stores the bdos_start location
ccp_location equ bdos_location-2        ; Stores the ccp_start location
ccp_name equ ccp_location-13            ; stores the name of the ccp file, e.g. MYCCP.BIN with a zero terminator






