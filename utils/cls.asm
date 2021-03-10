; cls.asm
;   Clear the screen, by outputting the appropriate ANSI escape sequence

    ORG 100H

BDOS:       EQU 5
PRINTCHR:   EQU 9

START:
    LD DE,CLEAR
    LD C,PRINTCHR
    CALL BDOS
    RET

CLEAR:  DB 27, '[2J$'
     END
