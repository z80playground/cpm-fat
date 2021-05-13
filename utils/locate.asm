;; locate.asm - Steve Kemp <steve@steve.fi> 2021
;;
;; Show the drives upon which all files matching the given pattern exist.
;;
;; When you're working with the Z80 playground you'll have drives
;; A: to P:, and it can be hard to remember where files are located.
;;
;; I've attempted to solve the problem by grouping things in logical
;; groups:
;;
;;   A: Common / Globally useful
;;   B: BASIC programs.
;;   C: C (C)ompiler
;;   ..
;;   ..
;;
;; But there are still times when you might forget, so with this you
;; can run something like:
;;
;;   A:LOCATE ZORK*.* [USER]
;;
;; And this program will show you the matches, regardless of where
;; the files are.
;;
;; If the second argument exists then instead of searching drives
;; the script will search user-areas.
;;

FCB1:    EQU 0x5C
FCB2:    EQU 0x6C
DMA:     EQU 0x80

BDOS_ENTRY_POINT:    EQU 5

BDOS_OUTPUT_SINGLE_CHARACTER:  EQU 2
BDOS_OUTPUT_STRING:            EQU 9
BDOS_SELECT_DISK:              EQU 14
BDOS_FIND_FIRST:               EQU 17
BDOS_FIND_NEXT:                EQU 18
BDOS_GET_SET_USER_NUMBER:      EQU 32

        ;;
        ;; CP/M programs start at 0x100.
        ;;
        ORG 100H

        ;;
        ;; Before the program is the zero-page, or PSP:
        ;;
        ;;     https://en.wikipedia.org/wiki/Zero_page_(CP/M)
        ;;
        ;; At offset 0x5C is the FCB for the first argument
        ;;
        ;;     https://en.wikipedia.org/wiki/File_Control_Block
        ;;


        ;; The FCB will be populated with the pattern/first argument,
        ;; if the first character of that region is a space-character
        ;; then we've got nothing to search for.
        ld a, (FCB1 + 1)
        cp 0x20          ; 0x20 = 32 == SPACE
        jp z, no_arg     ; Got a space, so we'll show usage-info and quit.

        ;; Are we looking for user-areas?
        ld a, (FCB2 + 1)
        cp 0x20
        jp z, find_drives

        ;; Set the flag which shows user-numbers in the output
        ld hl, SHOW_USER_MARKER
        ld (hl), a

        ;; OK we're looking for files on the current drive, but with
        ;; all user-numbers.
        xor a                   ; user 0 first
find_user_files:
        ;; set user-number
        push af
        ld c, BDOS_GET_SET_USER_NUMBER
        ld e, a
        call BDOS_ENTRY_POINT

        ;; Find files on the appropriate drive
        ld a, (FCB1)
        ld b, a

        ;; find the files, and display them.
        call find_files_on_drive

        ;; repeat for all user-numbers
        pop af
        inc a
        cp 16                   ; 15 user areas, if we hit 16 we've gone too far
        jp nz, find_user_files
        ret


find_drives:
        ;; This is where we run our main loop, looping over the
        ;; drives from P->A.
        ;;
        ;; Drive number will be stored in B
        ld b, 16
find_loop:
        push bc
        call find_files_on_drive
        pop bc
        djnz find_loop

        ;; All done, exit now.
        ret



;;; ***
;;;
;;; Find all files on the given drive that match the pattern
;;; in our FCB - the drive index is specified in the B-register.
;;;
find_files_on_drive:

        ;; B is called with the drive-number, drop it into the FCB
        ld hl, FCB1
        ld (hl),b

        ;; Call the find-first BIOS function
        ld c, BDOS_FIND_FIRST
        ld de, FCB1
        call BDOS_ENTRY_POINT

find_more:
        ;; If nothing was found then return.
        cp 255
        ret z

        ;; Show the thing we did find.
        call show_result

        ;; After the find-first function we need to keep calling
        ;; find-next, until that returns a failure.
        ld c, BDOS_FIND_NEXT
        ld de, FCB1
        call BDOS_ENTRY_POINT

        jp find_more    ; Test return code and loop again



;;; ***
;;;
;;; This is called after find-first/find-next returns a positive result
;;; and is supposed to show the name of the file that was found.
;;;
;;; We show the drive-letter and the resulting match.
;;;
show_result:

        push af                 ; preserve return code from find first/next

        ld a,(FCB1)             ; Output the drive-letter and separator
        add a, 65 - 1
        call print_character

        ld hl, SHOW_USER_MARKER
        ld a, (hl)
        cp 0
        jp z, skip_user_number
        ld c, 32                ; find user-number
        ld e, 255
        call BDOS_ENTRY_POINT
        call OutHex8            ; output the number
skip_user_number:
        ld a, ':'
        call print_character

        pop af                       ; restore return code from find first/next
        call print_matching_filename ; print the entry

        ld de, newline          ; Add a trailing newline
        ld c, BDOS_OUTPUT_STRING
        jp call_bdos_and_return


;;; ***
;;;
;;; When we call find-first/find-next we get a result which we now show.
;;;
;;; The return code of the find-first/next will be preserved when we're
;;; called here, and it should be multiplied by 32, as per:
;;;
;;;    http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch5.htm
;;;
;;; See documentation for "Function 17: Search for First "
;;;
;;; NOTE: We assume the default DMA address of 0x0080
;;;
print_matching_filename:

        ;; Return code from find-first, or find-next, will be 0, 1, 2, or
        ;; 3 - and should be multiplied by 32 then added to the DMA area
        ;;
        ;; What we could do is:
        ;;
        ;;   hl = DMA
        ;;   a  = a *  32
        ;;   hl = hl + a
        ;;
        ;; However we know the maximum we can have in A is
        ;; 3 x 32 = 96, and we know the default DMA area is 0x80 (128).
        ;;
        ;; So instead what we'll do is:
        ;;
        ;; a = a * 32
        ;; a = a + 128 (DMA offset)
        ;; h = 0
        ;; l = a
        ;;
        ;; Leaving the correct value in HL, and saving several bytes.
        ;;
        and 3               ; Mask the bits since ret is 0/1/2/3
        add A,A             ; MULTIPLY...
        add A,A             ; ..BY 32 BECAUSE
        add A,A             ; ..EACH DIRECTORY
        add A,A             ; ..ENTRY IS 32
        add A,A             ; ..BYTES LONG

        add A, DMA + 1          ; Make offset from DMA
        xor h                   ; high byte is zero
        ld  l, a                ; low bye is offset

        ld b,11                 ; filename is 11 bytes
print_matching_filename_loop:
        ld a,(hl)
        push hl
        push bc
        call print_character
        pop bc
        pop hl
        inc hl
        djnz print_matching_filename_loop
        ret


;;; ***
;;; Helper routine to print a single character, stored in the A-register
;;;
print_character:
        ld c, BDOS_OUTPUT_SINGLE_CHARACTER
        ld e, a
call_bdos_and_return:
        call BDOS_ENTRY_POINT
        ret


;;; ***
;;; Show our usage-message, and terminate.
;;;
no_arg:
        ld de, usage_message
        ld c, BDOS_OUTPUT_STRING
        jp call_bdos_and_return


;;; ***
;;; Output the hex value of the 8-bit number stored in A
;;;
OutHex8:
   rra
   rra
   rra
   rra
   call  Conv
   ld  a,c
Conv:
   and  $0F
   add  a,$90
   daa
   adc  a,$40
   daa
   ; Show the value.
   ld c, BDOS_OUTPUT_SINGLE_CHARACTER
   ld e, a
   jp BDOS_ENTRY_POINT

;;; ***
;;; The message displayed if no command-line argument was present.
;;;
usage_message:
        db "Usage: LOCATE pattern"

        ;; note fall-through here :)
newline:
        db 0xa, 0xd, "$"

;;; ***
;;; If this is non-zero we skip showing the user-number
;;;
SHOW_USER_MARKER:
     db 0

        END
