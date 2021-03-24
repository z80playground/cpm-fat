;; cls.asm - Steve Kemp <steve@steve.fi> 2021
;;
;; Clear the screen, via ANSI escape sequence.
;;
BDOS_ENTRY_POINT:    EQU 5

BDOS_OUTPUT_STRING:            EQU 9
BDOS_SELECT_DISK:              EQU 14
BDOS_FIND_FIRST:               EQU 17
BDOS_FIND_NEXT:                EQU 18

        ;;
        ;; CP/M programs start at 0x100.
        ;;
        ORG 100H

        ld de, CLEAR_SCREEN_ANSI
        ld c, BDOS_OUTPUT_STRING
        call BDOS_ENTRY_POINT
        ret



;;; ***
;;; The message displayed if no command-line argument was present.
;;;
CLEAR_SCREEN_ANSI:
        db 27, "[2J$"

        END
