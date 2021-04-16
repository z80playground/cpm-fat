;;; Return to the Z80 Playground Monitor from CP/M.
;;;
;;; Since the monitor is in the EEPROM and should occupy the lower half of
;;; the address-space we need to move our code from 0x0100, where CP/M will
;;; load it, to a higher location before we can page in the EEPROM.
;;;
;;; Once the EEPROM is paged in we can jump to 0x0000 to essentially reboot
;;; and load the monitor.
;;;
;;; https://8bitstack.co.uk/forums/topic/how-to-go-back-to-monitor-from-cp-m
;;;


        ;; Area we copy our routine to.
HIGH_LOCATION:  EQU 0x8000



        ;; We load at 0x100H
        ORG 0x100

        ;; Copy the routine to do the magic to high-memory.
        ld hl, routine_start
        ld de, HIGH_LOCATION
        ld bc, routine_end - routine_start
        ldir

        ;; Jump to the copied program
        jp HIGH_LOCATION


routine_start:
        in a,(0x0c)
        and %011110111
        out (0x0c),a            ; Page in the EEPROM
        jp 0x0000               ; Jump to 0x0000 (i.e. reboot).
routine_end:

        END
