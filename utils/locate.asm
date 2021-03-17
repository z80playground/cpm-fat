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
;;   C:
;;   D:
;;   E:
;;   F:
;;   G: (G)ames
;;   H
;;   I
;;   J
;;   K
;;   L
;;   M
;;   N
;;   O
;;   P: (P)rogramming related (turbo pascal, forth, etc)
;;
;; But there are still times when you might forget, so you can run
;;
;;   A:LOCATE ZORK*.*
;;
;; And this program will show you the matches, regardless of where
;; the files are.
;;

BDOS:    EQU 5
FCB:     EQU 0x005C

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
        ld a, (FCB + 1)
        cp 0x20                 ; 0x20 = 32 = SPACE Character
        jp nz, real_start       ; Not a space? Go to the start of the program

        ;; Show the error-message, and terminate.
        ld de, usage_message
        ld c, 09
        call BDOS
        ret


        ;; This is where we run our main loop, looping over the
        ;; drives from P->A.
        ;;
        ;; Drive number will be stored in B
real_start:
        ld b, 15
find_loop:
        push bc
        call find_files_on_drive
        pop bc
        djnz find_loop

        ;; At this point we've got our drive-letter in B, and it
        ;; is zero - which terminated the loop.  But we should also
        ;; look on that zero-drive
        call find_files_on_drive

        ;; All done, exit now.
        ret



;;; ***
;;;
;;; Find all files on the given drive that match the pattern
;;; in our FCB - the drive index is specified in the B-register.
;;;
find_files_on_drive:

        ;;
        ;; B is called with the drive-number, drop it into the FCB
        ;;
        ld hl, FCB
        ld (hl),b

        ;; Select the disk, explicitly - not sure if this is required.
        ld c, 14
        ld e, b
        call BDOS

        ;; Call the find-first BIOS function
        ld c, 0x11
        ld de, FCB
        call BDOS

        ;; If nothing was found then return.
        cp 255
        ret z

find_more:
        ;; Show the thing we found.
        call show_result

        ;; After the find-first function we need to keep calling
        ;; find-next, until that returns a failure.

        ld c,18                 ; call find-next
        ld de,FCB
        call BDOS

        cp 255                  ; Nothing more found?  Then return.
        ret z

        jp find_more            ; Otherwise loop around again.



;;; ***
;;;
;;; This is called after find-first/find-next returns a positive result
;;; and is supposed to show the name of the file that was found.
;;;
;;; We show the drive-letter and the resulting match.
;;;
show_result:
        ;; output drive-letter
        ld a,(FCB)
        add a, 65
        call print_character

        ;; output ":"
        ld a, ':'
        call print_character

        ;; print the entry
        call print_matching_filename

        ;; print newline
        ld de, newline
        ld c, 09
        call BDOS
        ret

;;; ***
;;;
;;; When we call find-first/find-next we get a result,
;;; We assume the default DMA address of 0x0080
;;;
;;;          TODO / Fixme / Hacky
;;;
;;; I think the return code of the find-first/find-next should
;;; be multiplied by 32, as per:
;;;
;;;    http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch5.htm
;;;
;;; See documentation for "Function 17: Search for First "
;;;
print_matching_filename
        ld b, 11                ; number of characters?
        LD hl, 0x0080 + 1       ; offset

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
        ld c, 0x02
        ld e, a
        call BDOS
        ret


;;; ***
;;; The message displayed if no command-line argument was present.
;;;
usage_message:
        db "Usage: LOCATE pattern" ; fall-through :)
newline:
        db 0xa, 0xd, "$"

        END
