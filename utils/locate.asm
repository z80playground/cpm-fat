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
;;   P: Turbo (P)ascal
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
        cp 0x20          ; 0x20 = 32 == SPACE
        jp z, no_arg     ; Got a space, so we'll show usage-info and quit.

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

        ;; B is called with the drive-number, drop it into the FCB
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
        ;; Show the thing we did find.
        call show_result

        ;; After the find-first function we need to keep calling
        ;; find-next, until that returns a failure.
        ld c,18                 ; call find-next
        ld de,FCB
        call BDOS

        cp 255                  ; Nothing found?  Then return
        ret z

        jp find_more            ; then loop around until we run out of matches



;;; ***
;;;
;;; This is called after find-first/find-next returns a positive result
;;; and is supposed to show the name of the file that was found.
;;;
;;; We show the drive-letter and the resulting match.
;;;
show_result:

        push af                 ; preserve return code from find first/next
        ld a,(FCB)              ; output drive
        add a, 65
        call print_character

        ld a, ':'               ; output ":"
        call print_character

        pop af                       ; restore return code from find first/next
        call print_matching_filename ; print the entry

        ;; print newline
        ld de, newline
        ld c, 09
        call BDOS
        ret

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
print_matching_filename
        ld b, 11                ; filename is 11 characters
        LD hl, 0x0080 + 1       ; default DMA area.

        ;; return code from find first/next should be multiplied by 32
        AND 3               ; Mask the bits since ret is 0/1/2/3
        ADD A,A             ;MULTIPLY...
        ADD A,A             ;..BY 32 BECAUSE
        ADD A,A             ;..EACH DIRECTORY
        ADD A,A             ;..ENTRY IS 32
        ADD A,A             ;..BYTES LONG

        ;; hl = hl + a
        add   a, l    ; A = A+L
        ld    l, a    ; L = A+L
        adc   a, h    ; A = A+L+H+carry
        sub   l       ; A = H+carry
        ld    h, a    ; H = H+carry

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
call_bdos_and_return:
        call BDOS
        ret

;;; ***
;;; Show our usage-message, and terminate.
;;;
no_arg:
        ld de, usage_message
        ld c, 09
        jp call_bdos_and_return




;;; ***
;;; The message displayed if no command-line argument was present.
;;;
usage_message:
        db "Usage: LOCATE pattern"

        ;; note fall-through here :)
newline:
        db 0xa, 0xd, "$"

        END
