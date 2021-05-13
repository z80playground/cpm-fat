; CHK16550
; Check what type of 16C550 you have.

    ORG 100H

BDOS:       EQU 5
PRINTCHR:   EQU 9
uart_MCR:   EQU 12

START:
    LD A, %00101010
    OUT (uart_MCR),A
    IN A,(uart_MCR)
    LD DE,GOOD
    CP %00101010
    JR Z,ST1
    LD DE,BAD
    CP %00001010
    JR Z,ST1
    LD DE,WHAT
ST1:
    LD C,PRINTCHR
    CALL BDOS
    RET

GOOD:
        DB 'Serial chip supports FlowControl.$'
BAD:
        DB 'Serial chip does not support FlowControl.$'
WHAT:
        DB 'No idea what serial chip this is.$'

                     END
