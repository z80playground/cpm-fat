; *************************************************************
;
;                 TINY BASIC FOR INTEL 8080
;                       VERSION 2.1
;                     BY LI-CHEN WANG
;                 MODIFIED AND TRANSLATED
;                   TO INTEL MNEMONICS
;                    BY ROGER RAUSKOLB
;                     10 OCTOBER,1976
;                        @COPYLEFT
;                   ALL WRONGS RESERVED
;
; *************************************************************

; Converted to Z80 mneumonics
; and styled for PASMO assembler
; ready to run on my "Z80 Playground" SBC
; by John Squires, October 2020

; TODO:
; * Tell the user that ctrl-c is break, etc.
; * Make a nicer intro screen.

; *** ZERO PAGE SUBROUTINES ***
; The original code used the zero page calls, "rst 08h"
; thru "rst 38h" for some functions, in order to keep the
; code size even smaller. However, the use of the "RST" commands
; means that this program always has to run from location 0
; and can never be assembled to a different location.
; I decided to remove all the RST stuff, so that this code
; could eventually be run under CP/M or loaded at a different
; location in memory.

; How to assemble:
; Use PASMO
; This version is intended for inclusion in the Z80 Playground EEPROM as a demo
; of what wonders can be performed!
; So it will begin at whatever address the EEPROM boot loader sets it to.
; It will be living in the bottom 32K of EEROM, and have
; access to the top 32K of RAM.

CR      equ  0DH
LF      equ  0AH

; Define a macro called DWA to store addresses in a special format.
; Hi-byte is stored first (big-endian) with bit 7 set.
; Lo-byte is stored second, with no special modification.
DWA     MACRO     v
        DB v>>8+128
        DB v & 0FFH
        ENDM

TBSTART:  
        LD  SP,TBSTACK                     ; *** COLD START ***
        LD   A,0FFH
        JP  INIT

TSTC:   EX (SP),HL                       ; *** TSTC (was "rst 08h") ***
        CALL IGNBLK                      ; IGNORE BLANKS AND
        CP  (HL)                         ; TEST CHARACTER
TC1:    INC  HL                          ; COMPARE THE BYTE THAT
        JP Z,TC2                         ; FOLLOWS THE CALL to this function
        PUSH BC                          ; WITH THE TEXT (DE->)
        LD   C,(HL)                      ; IF NOT =, ADD THE 2ND
        LD   B,0                         ; BYTE THAT FOLLOWS THE
        ADD HL,BC                        ; RST TO THE OLD PC
        POP  BC                          ; I.E., DO A RELATIVE
        DEC  DE                          ; JUMP IF NOT =
TC2:    INC  DE                          ; IF =, SKIP THOSE BYTES
        INC  HL                          ; AND CONTINUE
        EX (SP),HL
        RET

CRLF:   LD   A,CR                        ; *** CRLF ***

OUTC:   PUSH AF                          ; *** OUTC (was "rst 10h") ***
        LD  A,(OCSW)                     ; PRINT CHARACTER ONLY
        OR  A                            ; IF OCSW SWITCH IS ON
OC2:    JP NZ,OC3                        ; IT IS ON
        POP  AF                          ; IT IS OFF
        RET                              ; RESTORE AF AND RETURN
OC3:
        in a,(uart_LSR)                  ; check UART is ready to send.
        bit 5,a                          ; zero flag set to true if bit 5 is 0
        jp z,OC3                         ; zero = not ready for next char yet.
        POP  AF                          ; UART IS READY, GET OLD "A" BACK
        OUT  (uart_tx_rx),A              ; AND SEND IT OUT
        CP  CR                           ; WAS IT CR?
        RET NZ                           ; NO, FINISHED
OC4:
        in a,(uart_LSR)                  ; check UART is ready to send.
        bit 5,a                          ; zero flag set to true if bit 5 is 0
        jp z,OC4                         ; zero = not ready for next char yet.
        LD   A,LF                        ; YES, WE SEND LF TOO
        out (uart_tx_rx),a
        LD   A,CR                        ; GET CR BACK IN A
        RET

EXPR:   CALL EXPR2                       ; *** EXPR (was "rst 18h") ***
        PUSH HL                          ; EVALUATE AN EXPRESSION
        JP  EXPR1                        ; REST OF IT AT EXPR1

COMP:   LD   A,H                         ; *** COMP (was "rst 20h") ***
        CP  D                            ; COMPARE HL WITH DE
        RET NZ                           ; RETURN CORRECT C AND
        LD   A,L                         ; Z FLAGS
        CP  E                            ; BUT OLD A IS LOST
        RET

IGNBLK: 
        LD A,(DE)                        ; *** IGNBLK (was "rst 28h") ***
        CP  20H                          ; IGNORE BLANKS
        RET NZ                           ; IN TEXT (WHERE DE->)
        INC  DE                          ; AND RETURN THE FIRST
        JP  IGNBLK                      ; NON-BLANK CHAR. IN A

FINISH:
        POP  AF                          ; *** FINISH (was "rst 30h") ***
        CALL FIN                         ; CHECK END OF COMMAND
        JP  QWHAT                        ; PRINT "WHAT?" IF WRONG

TSTV:
        CALL IGNBLK                      ; *** TSTV (was "rst 38h") ***
        SUB  '@'                         ; TEST VARIABLES.
        RET C                            ; < @ means NOT A VARIABLE
        JP NZ,TV1                        ; NOT "@" ARRAY
        INC  DE                          ; IT IS THE "@" ARRAY
        CALL PARN                        ; @ SHOULD BE FOLLOWED
        ADD HL,HL                        ; BY (EXPR) AS ITS INDEX
        JP C,QHOW                        ; IS INDEX TOO BIG?
        PUSH DE                          ; WILL IT OVERWRITE
        EX DE,HL                         ; TEXT?
        CALL SIZE                        ; FIND SIZE OF FREE
        CALL COMP                          ; AND CHECK THAT
        JP C,ASORRY                      ; IF SO, SAY "SORRY"
        LD  HL,VARBGN                    ; IF NOT GET ADDRESS
        CALL SUBDE                       ; OF @(EXPR) AND PUT IT
        POP  DE                          ; IN HL
        RET                              ; C FLAG IS CLEARED
TV1:
        ; by this point A holds the index
        ; of the variable
        ; 0 = the array "@"
        ; 1  - 26 = A - Z
        ; 33 - 58 = a - z
        ; lowercase needs adjusting to be uppercase
        cp 33
        jr c,upper_var
        cp 59
        jr nc,upper_var
        sub 32                           ; lowercase it
upper_var:
        CP  1BH                          ; NOT @, IS IT A TO Z?
        CCF                              ; IF NOT RETURN C FLAG
        RET C
        INC  DE                          ; IF A THROUGH Z
        LD  HL,VARBGN                    ; COMPUTE ADDRESS OF
        RLCA                             ; THAT VARIABLE
        ADD  A,L                         ; AND RETURN IT IN HL
        LD   L,A                         ; WITH C FLAG CLEARED
        LD   A,0
        ADC  A,H
        LD   H,A
        RET

TSTNUM: LD  HL,0                         ; *** TSTNUM ***
        LD   B,H                         ; TEST IF THE TEXT IS
        CALL IGNBLK                          ; A NUMBER
TN1:    CP  30H                          ; IF NOT, RETURN 0 IN
        RET C                            ; B AND HL
        CP  3AH                          ; IF NUMBERS, CONVERT
        RET NC                           ; TO BINARY IN HL AND
        LD   A,0F0H                      ; SET B TO # OF DIGITS
        AND  H                           ; IF H>255, THERE IS NO
        JP NZ,QHOW                       ; ROOM FOR NEXT DIGIT
        INC  B                           ; B COUNTS # OF DIGITS
        PUSH BC
        LD   B,H                         ; HL=10*HL+(NEW DIGIT)
        LD   C,L
        ADD HL,HL                        ; WHERE 10* IS DONE BY
        ADD HL,HL                        ; SHIFT AND ADD
        ADD HL,BC
        ADD HL,HL
        LD A,(DE)                        ; AND (DIGIT) IS FROM
        INC  DE                          ; STRIPPING THE ASCII
        AND  0FH                         ; CODE
        ADD  A,L
        LD   L,A
        LD   A,0
        ADC  A,H
        LD   H,A
        POP  BC
        LD A,(DE)                        ; DO THIS DIGIT AFTER
        JP P,TN1                         ; DIGIT. S SAYS OVERFLOW
QHOW:   PUSH DE                          ; *** ERROR "HOW?" ***
AHOW:   LD  DE,HOW
        JP  ERROR
HOW:    DB   'HOW?'
        DB   CR
OK:     DB   'OK'
        DB   CR
WHAT:   DB   'WHAT?'
        DB   CR
SORRY:  DB   'SORRY'
        DB   CR

        ; *************************************************************

        ; *** MAIN ***

        ; THIS IS THE MAIN LOOP THAT COLLECTS THE TINY BASIC PROGRAM
        ; AND STORES IT IN THE MEMORY.

        ; AT START, IT PRINTS OUT "(CR)OK(CR)", AND INITIALIZES THE
        ; STACK AND SOME OTHER INTERNAL VARIABLES.  THEN IT PROMPTS
        ; ">" AND READS A LINE.  IF THE LINE STARTS WITH A NON-ZERO
        ; NUMBER, THIS NUMBER IS THE LINE NUMBER.  THE LINE NUMBER
        ; (IN 16 BIT BINARY) AND THE REST OF THE LINE (INCLUDING CR)
        ; IS STORED IN THE MEMORY.  IF A LINE WITH THE SAME LINE
        ; NUMBER IS ALREADY THERE, IT IS REPLACED BY THE NEW ONE.  IF
        ; THE REST OF THE LINE CONSISTS OF A CR ONLY, IT IS NOT STORED
        ; AND ANY EXISTING LINE WITH THE SAME LINE NUMBER IS DELETED.

        ; AFTER A LINE IS INSERTED, REPLACED, OR DELETED, THE PROGRAM
        ; LOOPS BACK AND ASKS FOR ANOTHER LINE.  THIS LOOP WILL BE
        ; TERMINATED WHEN IT READS A LINE WITH ZERO OR NO LINE
        ; NUMBER; AND CONTROL IS TRANSFERED TO "DIRECT".

        ; TINY BASIC PROGRAM SAVE AREA STARTS AT THE MEMORY LOCATION
        ; LABELED "TXTBGN" AND ENDS AT "TXTEND".  WE ALWAYS FILL THIS
        ; AREA STARTING AT "TXTBGN", THE UNFILLED PORTION IS POINTED
        ; BY THE CONTENT OF A MEMORY LOCATION LABELED "TXTUNF".

        ; THE MEMORY LOCATION "CURRNT" POINTS TO THE LINE NUMBER
        ; THAT IS CURRENTLY BEING INTERPRETED.  WHILE WE ARE IN
        ; THIS LOOP OR WHILE WE ARE INTERPRETING A DIRECT COMMAND
        ; (SEE NEXT SECTION). "CURRNT" SHOULD POINT TO A 0.

RSTART: LD  SP,TBSTACK
ST1:    CALL CRLF                        ; AND JUMP TO HERE
        LD  DE,OK                        ; DE->STRING
        SUB  A                           ; A=0
        CALL PRTSTG                      ; PRINT STRING UNTIL CR
        LD  HL,ST2+1                     ; LITERAL 0
        LD (CURRNT),HL                   ; CURRENT->LINE # = 0
ST2:    LD  HL,0
        LD (LOPVAR),HL
        LD (STKGOS),HL
ST3:    LD   A,3EH                       ; PROMPT '>' AND
        CALL GETLN                       ; READ A LINE
        PUSH DE                          ; DE->END OF LINE
        LD  DE,BUFFER                    ; DE->BEGINNING OF LINE
        CALL TSTNUM                      ; TEST IF IT IS A NUMBER
        CALL IGNBLK
        LD   A,H                         ; HL=VALUE OF THE # OR
        OR  L                            ; 0 IF NO # WAS FOUND
        POP  BC                          ; BC->END OF LINE
        JP Z,DIRECT
        DEC  DE                          ; BACKUP DE AND SAVE
        LD   A,H                         ; VALUE OF LINE # THERE
        LD (DE),A
        DEC  DE
        LD   A,L
        LD (DE),A
        PUSH BC                          ; BC,DE->BEGIN, END
        PUSH DE
        LD   A,C
        SUB  E
        PUSH AF                          ; A=# OF BYTES IN LINE
        CALL FNDLN                       ; FIND THIS LINE IN SAVE
        PUSH DE                          ; AREA, DE->SAVE AREA
        JP NZ,ST4                        ; NZ:NOT FOUND, INSERT
        PUSH DE                          ; Z:FOUND, DELETE IT
        CALL FNDNXT                      ; FIND NEXT LINE
                                         ; DE->NEXT LINE
        POP  BC                          ; BC->LINE TO BE DELETED
        LD HL,(TXTUNF)                   ; HL->UNFILLED SAVE AREA
        CALL MVUP                        ; MOVE UP TO DELETE
        LD   H,B                         ; TXTUNF->UNFILLED AREA
        LD   L,C
        LD (TXTUNF),HL                   ; UPDATE
ST4:    POP  BC                          ; GET READY TO INSERT
        LD HL,(TXTUNF)                   ; BUT FIRST CHECK IF
        POP  AF                          ; THE LENGTH OF NEW LINE
        PUSH HL                          ; IS 3 (LINE # AND CR)
        CP  3                            ; THEN DO NOT INSERT
        JP Z,RSTART                      ; MUST CLEAR THE STACK
        ADD  A,L                         ; COMPUTE NEW TXTUNF
        LD   L,A
        LD   A,0
        ADC  A,H
        LD   H,A                         ; HL->NEW UNFILLED AREA
        LD  DE,TXTEND                    ; CHECK TO SEE IF THERE
        CALL COMP                          ; IS ENOUGH SPACE
        JP NC,QSORRY                     ; SORRY, NO ROOM FOR IT
        LD (TXTUNF),HL                   ; OK, UPDATE TXTUNF
        POP  DE                          ; DE->OLD UNFILLED AREA
        CALL MVDOWN
        POP  DE                          ; DE->BEGIN, HL->END
        POP  HL
        CALL MVUP                        ; MOVE NEW LINE TO SAVE
        JP  ST3                          ; AREA

                                         ; *************************************************************

                                         ; WHAT FOLLOWS IS THE CODE TO EXECUTE DIRECT AND STATEMENT
                                         ; COMMANDS.  CONTROL IS TRANSFERED TO THESE POINTS VIA THE
                                         ; COMMAND TABLE LOOKUP CODE OF 'DIRECT' AND 'EXEC' IN LAST
                                         ; SECTION.  AFTER THE COMMAND IS EXECUTED, CONTROL IS
                                         ; TRANSFERED TO OTHERS SECTIONS AS FOLLOWS:

                                         ; FOR 'LIST', 'NEW', AND 'STOP': GO BACK TO 'RSTART'
                                         ; FOR 'RUN': GO EXECUTE THE FIRST STORED LINE IF ANY, ELSE
                                         ; GO BACK TO 'RSTART'.
                                         ; FOR 'GOTO' AND 'GOSUB': GO EXECUTE THE TARGET LINE.
                                         ; FOR 'RETURN' AND 'NEXT': GO BACK TO SAVED RETURN LINE.
                                         ; FOR ALL OTHERS: IF 'CURRENT' -> 0, GO TO 'RSTART', ELSE
                                         ; GO EXECUTE NEXT COMMAND.  (THIS IS DONE IN 'FINISH'.)
                                         ; *************************************************************

                                         ; *** NEW *** STOP *** RUN (& FRIENDS) *** & GOTO ***

                                         ; 'NEW(CR)' SETS 'TXTUNF' TO POINT TO 'TXTBGN'

                                         ; 'STOP(CR)' GOES BACK TO 'RSTART'

                                         ; 'RUN(CR)' FINDS THE FIRST STORED LINE, STORE ITS ADDRESS (IN
                                         ; 'CURRENT'), AND START EXECUTE IT.  NOTE THAT ONLY THOSE
                                         ; COMMANDS IN TAB2 ARE LEGAL FOR STORED PROGRAM.

                                         ; THERE ARE 3 MORE ENTRIES IN 'RUN':
                                         ; 'RUNNXL' FINDS NEXT LINE, STORES ITS ADDR. AND EXECUTES IT.
                                         ; 'RUNTSL' STORES THE ADDRESS OF THIS LINE AND EXECUTES IT.
                                         ; 'RUNSML' CONTINUES THE EXECUTION ON SAME LINE.

                                         ; 'GOTO EXPR(CR)' EVALUATES THE EXPRESSION, FIND THE TARGET
                                         ; LINE, AND JUMP TO 'RUNTSL' TO DO IT.

NEW:    CALL ENDCHK                      ; *** NEW(CR) ***
        LD  HL,TXTBGN
        LD (TXTUNF),HL

STOP:   CALL ENDCHK                      ; *** STOP(CR) ***
        JP  RSTART

TBDIR:                                    ; *** DIR(CR) *** 
                                        ; This does a directory listing.
        call ENDCHK                     

        ; Clear files counter
        ld a, 0
        ld (tb_dir_count), a

        ; Open /TBASIC folder
        ld hl, TINY_BASIC_FOLDER_NAME
        call open_file

        ; Then open *
        ld hl, STAR_DOT_STAR           
        call open_file

        ; Loop through, printing the file names, one per line
tb_dir_loop:
        cp USB_INT_DISK_READ
        jr z, tbasic_dir_loop_good

        ld a, (tb_dir_count)
        cp 0
        jp nz, RSTART

        call message
        db 'No files found.',13,10,0

        jp RSTART

tbasic_dir_loop_good:
        ld a, RD_USB_DATA0
        call send_command_byte
        call read_data_byte                 ; Find out how many bytes there are to read

        call read_data_bytes_into_buffer    ; read them into disk_buffer
        cp 32                               ; Did we read at least 32 bytes?
        jr nc, tb_dir_good_length
tb_dir_next:
        ld a, FILE_ENUM_GO                  ; Go to next entry in the directory
        call send_command_byte
        call read_status_byte
        jp tb_dir_loop

tb_dir_good_length:
        ld a, (disk_buffer+11)
        and $16                             ; Check for hidden or system files, or directories
        jp nz, tb_dir_next                  ; and skip accordingly.

tb_it_is_not_system:
        ld hl, tb_dir_count
        inc (hl)

        ; Show filename from diskbuffer
        ld b, 8
        ld hl, disk_buffer
tb_dir_show_name_loop:
        ld a, (hl)
        call print_a
        inc hl
        djnz tb_dir_show_name_loop

        ld a, '.'
        call print_a

        ld b, 3
tb_dir_show_extension_loop:
        ld a, (hl)
        call print_a
        inc hl
        djnz tb_dir_show_extension_loop

        call newline

        jp tb_dir_next

SAVE:                                   ; *** SAVE "filename" *** 
                                        ; This Saves the current program to USB Drive with the given name.
        push de
        call get_program_size
        pop de
        ld a, h
        or l
        cp 0
        jr nz, save_continue
        call message
        db 'No program yet to save!',13,10,0
        jp RSTART
save_continue:
        call READ_QUOTED_FILENAME
        call does_file_exist
        call z, tb_erase_file

        call close_file

        ;call message
        ;db 'Creating file...',13,10,0

        ld hl, TINY_BASIC_FOLDER_NAME
        call open_file
        ld de, filename_buffer
        call create_file
        jr z, tb_save_continue
        call message
        db 'Could not create file.',13,10,0
        jp RSTART

get_program_size:
        ; Gets the total size of the program, in bytes, into hl
        ld de,TXTBGN
        ld hl, (TXTUNF)
        or a
        sbc hl, de
        ret

tb_save_continue:
        ld a, BYTE_WRITE
        call send_command_byte

        ; Send number of bytes we are about to write, as 16 bit number, low first
        call get_program_size
        ld a, l
        call send_data_byte
        ld a, h
        call send_data_byte

        ld hl, TXTBGN
        call write_loop

        call close_file

        jp RSTART

LOAD:                                   ; *** LOAD "filename" *** 
                                        ; This Loads a program from USB Drive
        call READ_QUOTED_FILENAME
        call does_file_exist
        jr z, load_can_do
tb_file_not_found
        call message
        db 'File not found.',13,10,0
        jp RSTART

load_can_do:
        ld hl, TINY_BASIC_FOLDER_NAME
        call open_file
        ld hl, filename_buffer
        call open_file

        ld a, BYTE_READ
        call send_command_byte
        ld a, 255                           ; Request all of the file
        call send_data_byte
        ld a, 255                           ; Yes, all!
        call send_data_byte

        ld a, GET_STATUS
        call send_command_byte
        call read_data_byte
        ld hl, TXTBGN                       ; Get back the target address
tb_load_loop1:
        cp USB_INT_DISK_READ
        jr nz, tb_load_finished

        push hl
        call disk_on
        ld a, RD_USB_DATA0
        call send_command_byte
        call read_data_byte
        pop hl
        call read_data_bytes_into_hl
        push hl
        call disk_off
        ld a, BYTE_RD_GO
        call send_command_byte
        ld a, GET_STATUS
        call send_command_byte
        call read_data_byte
        pop hl
        jp tb_load_loop1
tb_load_finished:
        ld (TXTUNF), hl
        call close_file
        jp RSTART

ERASE:                                   ; *** ERASE "filename" *** 
                                        ; This erases a file
        call READ_QUOTED_FILENAME
        call does_file_exist
        jr nz, tb_file_not_found
        call tb_erase_file
        jp RSTART

EXIT:                           ; When tinybasic is launched it is called
                                ; from the monitor.
                                ;
                                ; So we know the ROM is mapped.
                                ;
                                ; We could preserve the stack and merely RET
                                ; but instead we'll just jump to the 0x0000
                                ; address.
        jp 0x0000

tb_erase_file:
        ;call message
        ;db 'Erasing file...',13,10,0
        ld a, SET_FILE_NAME
        call send_command_byte
        ld hl, filename_buffer
        call send_data_string
        ld a, FILE_ERASE
        call send_command_byte
        call read_status_byte
        ret

does_file_exist:
        ; Looks on disk for a file. Returns Z if file exists.
        ld hl, TINY_BASIC_FOLDER_NAME
        call open_file
        ld hl, filename_buffer
        jp open_file

RUN:    CALL ENDCHK                      ; *** RUN(CR) ***
        LD  DE,TXTBGN                    ; FIRST SAVED LINE

RUNNXL: LD  HL,0                         ; *** RUNNXL ***
        CALL FNDLP                       ; FIND WHATEVER LINE #
        JP C,RSTART                      ; C:PASSED TXTUNF, QUIT

RUNTSL: EX DE,HL                         ; *** RUNTSL ***
        LD (CURRNT),HL                   ; SET 'CURRENT'->LINE #
        EX DE,HL
        INC  DE                          ; BUMP PASS LINE #
        INC  DE

RUNSML: CALL CHKIO                       ; *** RUNSML ***
        LD  HL,TAB2-1                    ; FIND COMMAND IN TAB2
        JP  EXEC                         ; AND EXECUTE IT

GOTO:   CALL EXPR                          ; *** GOTO EXPR ***
        PUSH DE                          ; SAVE FOR ERROR ROUTINE
        CALL ENDCHK                      ; MUST FIND A CR
        CALL FNDLN                       ; FIND THE TARGET LINE
        JP NZ,AHOW                       ; NO SUCH LINE #
        POP  AF                          ; CLEAR THE PUSH DE
        JP  RUNTSL                       ; GO DO IT

                                         ; *************************************************************

                                         ; *** LIST *** & PRINT ***

                                         ; LIST HAS TWO FORMS:
                                         ; 'LIST(CR)' LISTS ALL SAVED LINES
                                         ; 'LIST #(CR)' START LIST AT THIS LINE #
                                         ; YOU CAN STOP THE LISTING BY CONTROL C KEY

                                         ; PRINT COMMAND IS 'PRINT ....;' OR 'PRINT ....(CR)'
                                         ; WHERE '....' IS A LIST OF EXPRESIONS, FORMATS, BACK-
                                         ; ARROWS, AND STRINGS.  THESE ITEMS ARE SEPERATED BY COMMAS.

                                         ; A FORMAT IS A POUND SIGN FOLLOWED BY A NUMBER.  IT CONTROLS
                                         ; THE NUMBER OF SPACES THE VALUE OF A EXPRESION IS GOING TO
                                         ; BE PRINTED.  IT STAYS EFFECTIVE FOR THE REST OF THE PRINT
                                         ; COMMAND UNLESS CHANGED BY ANOTHER FORMAT.  IF NO FORMAT IS
                                         ; SPECIFIED, 6 POSITIONS WILL BE USED.

                                         ; A STRING IS QUOTED IN A PAIR OF SINGLE QUOTES OR A PAIR OF
                                         ; DOUBLE QUOTES.

                                         ; A BACK-ARROW MEANS GENERATE A (CR) WITHOUT (LF)

                                         ; A $ means print an ascii character, so 'PRINT $72,$107' will print "Hi"

                                         ; A (CRLF) IS GENERATED AFTER THE ENTIRE LIST HAS BEEN
                                         ; PRINTED OR IF THE LIST IS A NULL LIST.  HOWEVER IF THE LIST
                                         ; ENDED WITH A COMMA, NO (CRLF) IS GENERATED.

LIST:   CALL TSTNUM                      ; TEST IF THERE IS A #
        CALL ENDCHK                      ; IF NO # WE GET A 0
        CALL FNDLN                       ; FIND THIS OR NEXT LINE
LS1:    JP C,RSTART                      ; C:PASSED TXTUNF
        CALL PRTLN                       ; PRINT THE LINE
        CALL CHKIO                       ; STOP IF HIT CONTROL-C
        CALL FNDLP                       ; FIND NEXT LINE
        JP  LS1                          ; AND LOOP BACK

PRINT:  LD   C,6                         ; C = # OF SPACES
        CALL TSTC                          ; Test for ";"
        DB   3BH
        DB   PR2-$-1
        CALL CRLF                        ; GIVE CR-LF AND
        JP  RUNSML                       ; CONTINUE SAME LINE
PR2:    CALL TSTC                          ; Test for (CR)
        DB   CR
        DB   PR0-$-1
        CALL CRLF                        ; ALSO GIVE CR-LF AND
        JP  RUNNXL                       ; GO TO NEXT LINE
PR0:    CALL TSTC                          ; ELSE IS IT FORMAT? e.g. #4 = format 4 digits long
        DB   '#'
        DB   PR1-$-1
        CALL EXPR                          ; YES, EVALUATE EXPR.
        LD   C,L                         ; AND SAVE IT IN C
        JP  PR3                          ; LOOK FOR MORE TO PRINT
PR1:    CALL TSTC                         ; Is it a "$"? e.g. $65 will print 'A'
        DB   '$'
        DB   PRNOTDOLLAR-$-1
        CALL EXPR                         ; Evaluate the expression, which will result in an 16 bit number in hl
        ld a, h                         ; If hl > 255 show error
        or a
        jr nz, PR_ERROR
        ld a, l                         ; Get just bottom 8 bits
        cp 32
        jr c, PR_ERROR
        cp 127
        jr c, PR_ASCII
PR_ERROR:
        ld a, '*'
PR_ASCII:
        CALL OUTC
        jp PR3                          ; Look for more to print

PRNOTDOLLAR:
        CALL QTSTG                       ; OR IS IT A STRING?
        JP  PR8                          ; IF NOT, MUST BE EXPR.
PR3:    CALL TSTC                          ; IF ",", GO FIND NEXT
        DB   ','
        DB   PR6-$-1
        CALL FIN                         ; IN THE LIST.
        JP  PR0                          ; LIST CONTINUES
PR6:    CALL CRLF                        ; LIST ENDS
        CALL FINISH
PR8:    CALL EXPR                          ; EVALUATE THE EXPR
        PUSH BC
        CALL PRTNUM                      ; PRINT THE VALUE
        POP  BC
        JP  PR3                          ; MORE TO PRINT?

                                         ; *************************************************************

                                         ; *** GOSUB *** & RETURN ***

                                         ; 'GOSUB EXPR;' OR 'GOSUB EXPR (CR)' IS LIKE THE 'GOTO'
                                         ; COMMAND, EXCEPT THAT THE CURRENT TEXT POINTER, STACK POINTER
                                         ; ETC. ARE SAVE SO THAT EXECUTION CAN BE CONTINUED AFTER THE
                                         ; SUBROUTINE 'RETURN'.  IN ORDER THAT 'GOSUB' CAN BE NESTED
                                         ; (AND EVEN RECURSIVE), THE SAVE AREA MUST BE STACKED.
                                         ; THE STACK POINTER IS SAVED IN 'STKGOS', THE OLD 'STKGOS' IS
                                         ; SAVED IN THE STACK.  IF WE ARE IN THE MAIN ROUTINE, 'STKGOS'
                                         ; IS ZERO (THIS WAS DONE BY THE "MAIN" SECTION OF THE CODE),
                                         ; BUT WE STILL SAVE IT AS A FLAG FOR NO FURTHER 'RETURN'S.

                                         ; 'RETURN(CR)' UNDOS EVERYTHING THAT 'GOSUB' DID, AND THUS
                                         ; RETURN THE EXECUTION TO THE COMMAND AFTER THE MOST RECENT
                                         ; 'GOSUB'.  IF 'STKGOS' IS ZERO, IT INDICATES THAT WE
                                         ; NEVER HAD A 'GOSUB' AND IS THUS AN ERROR.

GOSUB:  CALL PUSHA                       ; SAVE THE CURRENT "FOR"
        CALL EXPR                          ; PARAMETERS
        PUSH DE                          ; AND TEXT POINTER
        CALL FNDLN                       ; FIND THE TARGET LINE
        JP NZ,AHOW                       ; NOT THERE. SAY "HOW?"
        LD HL,(CURRNT)                   ; FOUND IT, SAVE OLD
        PUSH HL                          ; 'CURRNT' OLD 'STKGOS'
        LD HL,(STKGOS)
        PUSH HL
        LD  HL,0                         ; AND LOAD NEW ONES
        LD (LOPVAR),HL
        ADD HL,SP
        LD (STKGOS),HL
        JP  RUNTSL                       ; THEN RUN THAT LINE
RETURN: CALL ENDCHK                      ; THERE MUST BE A CR
        LD HL,(STKGOS)                   ; OLD STACK POINTER
        LD   A,H                         ; 0 MEANS NOT EXIST
        OR  L
        JP Z,QWHAT                       ; SO, WE SAY: "WHAT?"
        LD SP,HL                         ; ELSE, RESTORE IT
        POP  HL
        LD (STKGOS),HL                   ; AND THE OLD 'STKGOS'
        POP  HL
        LD (CURRNT),HL                   ; AND THE OLD 'CURRNT'
        POP  DE                          ; OLD TEXT POINTER
        CALL POPA                        ; OLD "FOR" PARAMETERS
        CALL FINISH                          ; AND WE ARE BACK HOME

                                         ; *************************************************************

                                         ; *** FOR *** & NEXT ***

                                         ; 'FOR' HAS TWO FORMS:
                                         ; 'FOR VAR=EXP1 TO EXP2 STEP EXP3' AND 'FOR VAR=EXP1 TO EXP2'
                                         ; THE SECOND FORM MEANS THE SAME THING AS THE FIRST FORM WITH
                                         ; EXP3=1.  (I.E., WITH A STEP OF +1.)
                                         ; TBI WILL FIND THE VARIABLE VAR, AND SET ITS VALUE TO THE
                                         ; CURRENT VALUE OF EXP1.  IT ALSO EVALUATES EXP2 AND EXP3
                                         ; AND SAVE ALL THESE TOGETHER WITH THE TEXT POINTER ETC. IN
                                         ; THE 'FOR' SAVE AREA, WHICH CONSISTS OF 'LOPVAR', 'LOPINC',
                                         ; 'LOPLMT', 'LOPLN', AND 'LOPPT'.  IF THERE IS ALREADY SOME-
                                         ; THING IN THE SAVE AREA (THIS IS INDICATED BY A NON-ZERO
                                         ; 'LOPVAR'), THEN THE OLD SAVE AREA IS SAVED IN THE STACK
                                         ; BEFORE THE NEW ONE OVERWRITES IT.
                                         ; TBI WILL THEN DIG IN THE STACK AND FIND OUT IF THIS SAME
                                         ; VARIABLE WAS USED IN ANOTHER CURRENTLY ACTIVE 'FOR' LOOP.
                                         ; IF THAT IS THE CASE, THEN THE OLD 'FOR' LOOP IS DEACTIVATED.
                                         ; (PURGED FROM THE STACK..)

                                         ; 'NEXT VAR' SERVES AS THE LOGICAL (NOT NECESSARILLY PHYSICAL)
                                         ; END OF THE 'FOR' LOOP.  THE CONTROL VARIABLE VAR. IS CHECKED
                                         ; WITH THE 'LOPVAR'.  IF THEY ARE NOT THE SAME, TBI DIGS IN
                                         ; THE STACK TO FIND THE RIGHT ONE AND PURGES ALL THOSE THAT
                                         ; DID NOT MATCH.  EITHER WAY, TBI THEN ADDS THE 'STEP' TO
                                         ; THAT VARIABLE AND CHECK THE RESULT WITH THE LIMIT.  IF IT
                                         ; IS WITHIN THE LIMIT, CONTROL LOOPS BACK TO THE COMMAND
                                         ; FOLLOWING THE 'FOR'.  IF OUTSIDE THE LIMIT, THE SAVE AREA
                                         ; IS PURGED AND EXECUTION CONTINUES.

FOR:    CALL PUSHA                       ; SAVE THE OLD SAVE AREA
        CALL SETVAL                      ; SET THE CONTROL VAR.
        DEC  HL                          ; HL IS ITS ADDRESS
        LD (LOPVAR),HL                   ; SAVE THAT
        LD  HL,TAB5-1                    ; USE 'EXEC' TO LOOK
        JP  EXEC                         ; FOR THE WORD 'TO'
FR1:    CALL EXPR                          ; EVALUATE THE LIMIT
        LD (LOPLMT),HL                   ; SAVE THAT
        LD  HL,TAB6-1                    ; USE 'EXEC' TO LOOK
        JP EXEC                          ; FOR THE WORD 'STEP'
FR2:    CALL EXPR                          ; FOUND IT, GET STEP
        JP  FR4
FR3:    LD  HL,1H                        ; NOT FOUND, SET TO 1
FR4:    LD (LOPINC),HL                   ; SAVE THAT TOO
FR5:    LD HL,(CURRNT)                   ; SAVE CURRENT LINE #
        LD (LOPLN),HL
        EX DE,HL                         ; AND TEXT POINTER
        LD (LOPPT),HL
        LD  BC,0AH                       ; DIG INTO STACK TO
        LD HL,(LOPVAR)                   ; FIND 'LOPVAR'
        EX DE,HL
        LD   H,B
        LD   L,B                         ; HL=0 NOW
        ADD HL,SP                        ; HERE IS THE STACK
        DB   3EH
FR7:    ADD HL,BC                        ; EACH LEVEL IS 10 DEEP
        LD   A,(HL)                      ; GET THAT OLD 'LOPVAR'
        INC  HL
        OR  (HL)
        JP Z,FR8                         ; 0 SAYS NO MORE IN IT
        LD   A,(HL)
        DEC  HL
        CP  D                            ; SAME AS THIS ONE?
        JP NZ,FR7
        LD   A,(HL)                      ; THE OTHER HALF?
        CP  E
        JP NZ,FR7
        EX DE,HL                         ; YES, FOUND ONE
        LD  HL,0H
        ADD HL,SP                        ; TRY TO MOVE SP
        LD   B,H
        LD   C,L
        LD  HL,0AH
        ADD HL,DE
        CALL MVDOWN                      ; AND PURGE 10 WORDS
        LD SP,HL                         ; IN THE STACK
FR8:    LD HL,(LOPPT)                    ; JOB DONE, RESTORE DE
        EX DE,HL
        CALL FINISH                          ; AND CONTINUE

NEXT:   CALL TSTV                          ; GET ADDRESS OF VAR.
        JP C,QWHAT                       ; NO VARIABLE, "WHAT?"
        LD (VARNXT),HL                   ; YES, SAVE IT
NX0:    PUSH DE                          ; SAVE TEXT POINTER
        EX DE,HL
        LD HL,(LOPVAR)                   ; GET VAR. IN 'FOR'
        LD   A,H
        OR  L                            ; 0 SAYS NEVER HAD ONE
        JP Z,AWHAT                       ; SO WE ASK: "WHAT?"
        CALL COMP                          ; ELSE WE CHECK THEM
        JP Z,NX3                         ; OK, THEY AGREE
        POP  DE                          ; NO, LET'S SEE
        CALL POPA                        ; PURGE CURRENT LOOP
        LD HL,(VARNXT)                   ; AND POP ONE LEVEL
        JP  NX0                          ; GO CHECK AGAIN
NX3:    LD   E,(HL)                      ; COME HERE WHEN AGREED
        INC  HL
        LD   D,(HL)                      ; DE=VALUE OF VAR.
        LD HL,(LOPINC)
        PUSH HL
        LD   A,H
        XOR  D
        LD   A,D
        ADD HL,DE                        ; ADD ONE STEP
        JP M,NX4
        XOR  H
        JP M,NX5
NX4:    EX DE,HL
        LD HL,(LOPVAR)                   ; PUT IT BACK
        LD   (HL),E
        INC  HL
        LD   (HL),D
        LD HL,(LOPLMT)                   ; HL->LIMIT
        POP  AF                          ; OLD HL
        OR  A
        JP P,NX1                         ; STEP > 0
        EX DE,HL                         ; STEP < 0
NX1:    CALL CKHLDE                      ; COMPARE WITH LIMIT
        POP  DE                          ; RESTORE TEXT POINTER
        JP C,NX2                         ; OUTSIDE LIMIT
        LD HL,(LOPLN)                    ; WITHIN LIMIT, GO
        LD (CURRNT),HL                   ; BACK TO THE SAVED
        LD HL,(LOPPT)                    ; 'CURRNT' AND TEXT
        EX DE,HL                         ; POINTER
        CALL FINISH
NX5:    POP  HL
        POP  DE
NX2:    CALL POPA                        ; PURGE THIS LOOP
        CALL FINISH

        ; *************************************************************

        ; *** REM *** IF *** INPUT *** & LET (& DEFLT) ***

        ; 'REM' CAN BE FOLLOWED BY ANYTHING AND IS IGNORED BY TBI.
        ; TBI TREATS IT LIKE AN 'IF' WITH A FALSE CONDITION.

        ; 'IF' IS FOLLOWED BY AN EXPR. AS A CONDITION AND ONE OR MORE
        ; COMMANDS (INCLUDING OTHER 'IF'S) SEPERATED BY SEMI-COLONS.
        ; NOTE THAT THE WORD 'THEN' IS NOT USED.  TBI EVALUATES THE
        ; EXPR. IF IT IS NON-ZERO, EXECUTION CONTINUES.  IF THE
        ; EXPR. IS ZERO, THE COMMANDS THAT FOLLOWS ARE IGNORED AND
        ; EXECUTION CONTINUES AT THE NEXT LINE.

        ; 'INPUT' COMMAND IS LIKE THE 'PRINT' COMMAND, AND IS FOLLOWED
        ; BY A LIST OF ITEMS.  IF THE ITEM IS A STRING IN SINGLE OR
        ; DOUBLE QUOTES, OR IS A BACK-ARROW, IT HAS THE SAME EFFECT AS
        ; IN 'PRINT'.  IF AN ITEM IS A VARIABLE, THIS VARIABLE NAME IS
        ; PRINTED OUT FOLLOWED BY A COLON.  THEN TBI WAITS FOR AN
        ; EXPR. TO BE TYPED IN.  THE VARIABLE IS THEN SET TO THE
        ; VALUE OF THIS EXPR.  IF THE VARIABLE IS PROCEDED BY A STRING
        ; (AGAIN IN SINGLE OR DOUBLE QUOTES), THE STRING WILL BE
        ; PRINTED FOLLOWED BY A COLON.  TBI THEN WAITS FOR INPUT EXPR.
        ; AND SET THE VARIABLE TO THE VALUE OF THE EXPR.

        ; IF THE INPUT EXPR. IS INVALID, TBI WILL PRINT "WHAT?",
        ; "HOW?" OR "SORRY" AND REPRINT THE PROMPT AND REDO THE INPUT.
        ; THE EXECUTION WILL NOT TERMINATE UNLESS YOU TYPE CONTROL-C.
        ; THIS IS HANDLED IN 'INPERR'.

        ; 'LET' IS FOLLOWED BY A LIST OF ITEMS SEPERATED BY COMMAS.
        ; EACH ITEM CONSISTS OF A VARIABLE, AN EQUAL SIGN, AND AN EXPR.
        ; TBI EVALUATES THE EXPR. AND SET THE VARIABLE TO THAT VALUE.
        ; TBI WILL ALSO HANDLE 'LET' COMMAND WITHOUT THE WORD 'LET'.
        ; THIS IS DONE BY 'DEFLT'.

REM:    LD  HL,0H                        ; *** REM ***
        DB   3EH                         ; THIS IS LIKE 'IF 0'

IFF:    CALL EXPR                          ; *** IF ***
        LD   A,H                         ; IS THE EXPR.=0?
        OR  L
        JP NZ,RUNSML                     ; NO, CONTINUE
        CALL FNDSKP                      ; YES, SKIP REST OF LINE
        JP NC,RUNTSL                     ; AND RUN THE NEXT LINE
        JP  RSTART                       ; IF NO NEXT, RE-START

INPERR: LD HL,(STKINP)                   ; *** INPERR ***
        LD SP,HL                         ; RESTORE OLD SP
        POP  HL                          ; AND OLD 'CURRNT'
        LD (CURRNT),HL
        POP  DE                          ; AND OLD TEXT POINTER
        POP  DE                          ; REDO INPUT

INPUT:                                   ; *** INPUT ***
IP1:    PUSH DE                          ; SAVE IN CASE OF ERROR
        CALL QTSTG                       ; IS NEXT ITEM A STRING?
        JP  IP2                          ; NO
        CALL TSTV                          ; YES, BUT FOLLOWED BY A
        JP C,IP4                         ; VARIABLE?   NO.
        JP  IP3                          ; YES.  INPUT VARIABLE
IP2:    PUSH DE                          ; SAVE FOR 'PRTSTG'
        CALL TSTV                          ; MUST BE VARIABLE NOW
        JP C,QWHAT                       ; "WHAT?" IT IS NOT?
        LD A,(DE)                        ; GET READY FOR 'PRTSTR'
        LD   C,A
        SUB  A
        LD (DE),A
        POP  DE
        CALL PRTSTG                      ; PRINT STRING AS PROMPT
        LD   A,C                         ; RESTORE TEXT
        DEC  DE
        LD (DE),A
IP3:    PUSH DE                          ; SAVE TEXT POINTER
        EX DE,HL
        LD HL,(CURRNT)                   ; ALSO SAVE 'CURRNT'
        PUSH HL
        LD  HL,IP1                       ; A NEGATIVE NUMBER
        LD (CURRNT),HL                   ; AS A FLAG
        LD  HL,0H                        ; SAVE SP TOO
        ADD HL,SP
        LD (STKINP),HL
        PUSH DE                          ; OLD HL
        LD   A,3AH                       ; PRINT THIS TOO
        CALL GETLN                       ; AND GET A LINE
        LD  DE,BUFFER                    ; POINTS TO BUFFER
        CALL EXPR                          ; EVALUATE INPUT
        NOP                              ; CAN BE 'CALL ENDCHK'
        NOP
        NOP
        POP  DE                          ; OK, GET OLD HL
        EX DE,HL
        LD   (HL),E                      ; SAVE VALUE IN VAR.
        INC  HL
        LD   (HL),D
        POP  HL                          ; GET OLD 'CURRNT'
        LD (CURRNT),HL
        POP  DE                          ; AND OLD TEXT POINTER
IP4:    POP  AF                          ; PURGE JUNK IN STACK
        CALL TSTC                          ; IS NEXT CH. ','?
        DB   ','
        DB   IP5-$-1
        JP  IP1                          ; YES, MORE ITEMS.
IP5:    CALL FINISH

DEFLT:  LD A,(DE)                        ; ***  DEFLT ***
        CP  CR                           ; EMPTY LINE IS OK
        JP Z,LT1                         ; ELSE IT IS 'LET'

LET:    CALL SETVAL                      ; *** LET ***
        CALL TSTC                          ; SET VALUE TO VAR.
        DB   ','
        DB   LT1-$-1
        JP  LET                          ; ITEM BY ITEM
LT1:    CALL FINISH                          ; UNTIL FINISH

                                         ; *************************************************************

                                         ; *** EXPR ***

                                         ; 'EXPR' EVALUATES ARITHMETICAL OR LOGICAL EXPRESSIONS.
                                         ; <EXPR>::<EXPR2>
                                         ; <EXPR2><REL.OP.><EXPR2>
                                         ; WHERE <REL.OP.> IS ONE OF THE OPERATORS IN TAB8 AND THE
                                         ; RESULT OF THESE OPERATIONS IS 1 IF TRUE AND 0 IF FALSE.
                                         ; <EXPR2>::=(+ OR -)<EXPR3>(+ OR -<EXPR3>)(....)
                                         ; WHERE () ARE OPTIONAL AND (....) ARE OPTIONAL REPEATS.
                                         ; <EXPR3>::=<EXPR4>(* OR /><EXPR4>)(....)
                                         ; <EXPR4>::=<VARIABLE>
                                         ; <FUNCTION>
                                         ; (<EXPR>)
                                         ; <EXPR> IS RECURSIVE SO THAT VARIABLE '@' CAN HAVE AN <EXPR>
                                         ; AS INDEX, FUNCTIONS CAN HAVE AN <EXPR> AS ARGUMENTS, AND
                                         ; <EXPR4> CAN BE AN <EXPR> IN PARANTHESE.

EXPR1:  LD  HL,TAB8-1                    ; LOOKUP REL.OP.
        JP  EXEC                         ; GO DO IT
XP11:   CALL XP18                        ; REL.OP.">="
        RET C                            ; NO, RETURN HL=0
        LD   L,A                         ; YES, RETURN HL=1
        RET
XP12:   CALL XP18                        ; REL.OP."#"
        RET Z                            ; FALSE, RETURN HL=0
        LD   L,A                         ; TRUE, RETURN HL=1
        RET
XP13:   CALL XP18                        ; REL.OP.">"
        RET Z                            ; FALSE
        RET C                            ; ALSO FALSE, HL=0
        LD   L,A                         ; TRUE, HL=1
        RET
XP14:   CALL XP18                        ; REL.OP."<="
        LD   L,A                         ; SET HL=1
        RET Z                            ; REL. TRUE, RETURN
        RET C
        LD   L,H                         ; ELSE SET HL=0
        RET
XP15:   CALL XP18                        ; REL.OP."="
        RET NZ                           ; FALSE, RETURN HL=0
        LD   L,A                         ; ELSE SET HL=1
        RET
XP16:   CALL XP18                        ; REL.OP."<"
        RET NC                           ; FALSE, RETURN HL=0
        LD   L,A                         ; ELSE SET HL=1
        RET
XP17:   POP  HL                          ; NOT .REL.OP
        RET                              ; RETURN HL=<EXPR2>
XP18:   LD   A,C                         ; SUBROUTINE FOR ALL
        POP  HL                          ; REL.OP.'S
        POP  BC
        PUSH HL                          ; REVERSE TOP OF STACK
        PUSH BC
        LD   C,A
        CALL EXPR2                       ; GET 2ND <EXPR2>
        EX DE,HL                         ; VALUE IN DE NOW
        EX (SP),HL                       ; 1ST <EXPR2> IN HL
        CALL CKHLDE                      ; COMPARE 1ST WITH 2ND
        POP  DE                          ; RESTORE TEXT POINTER
        LD  HL,0H                        ; SET HL=0, A=1
        LD   A,1
        RET

EXPR2:  CALL TSTC                          ; NEGATIVE SIGN?
        DB   '-'
        DB   XP21-$-1
        LD  HL,0H                        ; YES, FAKE '0-'
        JP  XP26                         ; TREAT LIKE SUBTRACT
XP21:   CALL TSTC                          ; POSITIVE SIGN? IGNORE
        DB   '+'
        DB   XP22-$-1
XP22:   CALL EXPR3                       ; 1ST <EXPR3>
XP23:   CALL TSTC                          ; ADD?
        DB   '+'
        DB   XP25-$-1
        PUSH HL                          ; YES, SAVE VALUE
        CALL EXPR3                       ; GET 2ND <EXPR3>
XP24:   EX DE,HL                         ; 2ND IN DE
        EX (SP),HL                       ; 1ST IN HL
        LD   A,H                         ; COMPARE SIGN
        XOR  D
        LD   A,D
        ADD HL,DE
        POP  DE                          ; RESTORE TEXT POINTER
        JP M,XP23                        ; 1ST AND 2ND SIGN DIFFER
        XOR  H                           ; 1ST AND 2ND SIGN EQUAL
        JP P,XP23                        ; SO IS RESULT
        JP  QHOW                         ; ELSE WE HAVE OVERFLOW
XP25:   CALL TSTC                          ; SUBTRACT?
        DB   '-'
        DB   XP42-$-1
XP26:   PUSH HL                          ; YES, SAVE 1ST <EXPR3>
        CALL EXPR3                       ; GET 2ND <EXPR3>
        CALL CHGSGN                      ; NEGATE
        JP  XP24                         ; AND ADD THEM

EXPR3:  CALL EXPR4                       ; GET 1ST <EXPR4>
XP31:   CALL TSTC                          ; MULTIPLY?
        DB   '*'
        DB   XP34-$-1
        PUSH HL                          ; YES, SAVE 1ST
        CALL EXPR4                       ; AND GET 2ND <EXPR4>
        LD   B,0H                        ; CLEAR B FOR SIGN
        CALL CHKSGN                      ; CHECK SIGN
        EX (SP),HL                       ; 1ST IN HL
        CALL CHKSGN                      ; CHECK SIGN OF 1ST
        EX DE,HL
        EX (SP),HL
        LD   A,H                         ; IS HL > 255 ?
        OR  A
        JP Z,XP32                        ; NO
        LD   A,D                         ; YES, HOW ABOUT DE
        OR  D
        EX DE,HL                         ; PUT SMALLER IN HL
        JP NZ,AHOW                       ; ALSO >, WILL OVERFLOW
XP32:   LD   A,L                         ; THIS IS DUMB
        LD  HL,0H                        ; CLEAR RESULT
        OR  A                            ; ADD AND COUNT
        JP Z,XP35
XP33:   ADD HL,DE
        JP C,AHOW                        ; OVERFLOW
        DEC  A
        JP NZ,XP33
        JP  XP35                         ; FINISHED
XP34:   CALL TSTC                          ; DIVIDE?
        DB   '/'
        DB   XP42-$-1
        PUSH HL                          ; YES, SAVE 1ST <EXPR4>
        CALL EXPR4                       ; AND GET THE SECOND ONE
        LD   B,0H                        ; CLEAR B FOR SIGN
        CALL CHKSGN                      ; CHECK SIGN OF 2ND
        EX (SP),HL                       ; GET 1ST IN HL
        CALL CHKSGN                      ; CHECK SIGN OF 1ST
        EX DE,HL
        EX (SP),HL
        EX DE,HL
        LD   A,D                         ; DIVIDE BY 0?
        OR  E
        JP Z,AHOW                        ; SAY "HOW?"
        PUSH BC                          ; ELSE SAVE SIGN
        CALL DIVIDE                      ; USE SUBROUTINE
        LD   H,B                         ; RESULT IN HL NOW
        LD   L,C
        POP  BC                          ; GET SIGN BACK
XP35:   POP  DE                          ; AND TEXT POINTER
        LD   A,H                         ; HL MUST BE +
        OR  A
        JP M,QHOW                        ; ELSE IT IS OVERFLOW
        LD   A,B
        OR  A
        CALL M,CHGSGN                    ; CHANGE SIGN IF NEEDED
        JP  XP31                         ; LOOK FOR MORE TERMS

EXPR4:  LD  HL,TAB4-1                    ; FIND FUNCTION IN TAB4
        JP  EXEC                         ; AND GO DO IT
XP40:   CALL TSTV                          ; NO, NOT A FUNCTION
        JP C,XP41                        ; NOR A VARIABLE
        LD   A,(HL)                      ; VARIABLE
        INC  HL
        LD   H,(HL)                      ; VALUE IN HL
        LD   L,A
        RET
XP41:   CALL TSTNUM                      ; OR IS IT A NUMBER
        LD   A,B                         ; # OF DIGIT
        OR  A
        RET NZ                           ; OK
PARN:   CALL TSTC
        DB   '('
        DB   XP43-$-1
        CALL EXPR                          ; "(EXPR)"
        CALL TSTC
        DB   ')'
        DB   XP43-$-1
XP42:   RET
XP43:   JP  QWHAT                        ; ELSE SAY: "WHAT?"

RND:    CALL PARN                        ; *** RND(EXPR) ***
        LD   A,H                         ; EXPR MUST BE +
        OR  A
        JP M,QHOW
        OR  L                            ; AND NON-ZERO
        JP Z,QHOW
        PUSH DE                          ; SAVE BOTH
        PUSH HL
        LD HL,(RANPNT)                   ; GET MEMORY AS RANDOM
        LD  DE,LSTROM                    ; NUMBER
        CALL COMP
        JP C,RA1                         ; WRAP AROUND IF LAST
        LD  HL,TBSTART
RA1:    LD   E,(HL)
        INC  HL
        LD   D,(HL)
        LD (RANPNT),HL
        POP  HL
        EX DE,HL
        PUSH BC
        CALL DIVIDE                      ; RND(N)=MOD(M,N)+1
        POP  BC
        POP  DE
        INC  HL
        RET

ABS:    CALL PARN                        ; *** ABS(EXPR) ***
        DEC  DE
        CALL CHKSGN                      ; CHECK SIGN
        INC  DE
        RET

PEEK:   CALL PARN                        ; *** PEEK(EXPR) ***
        ld a, (hl)                      ; We got a location into hl, so read from it
        ld l,a
        ld h,0
        RET

SIZE:   LD HL,(TXTUNF)                   ; *** SIZE ***
        PUSH DE                          ; GET THE NUMBER OF FREE
        EX DE,HL                         ; BYTES BETWEEN 'TXTUNF'
        LD  HL,VARBGN                    ; AND 'VARBGN'
        CALL SUBDE
        POP  DE
        RET

        ; *************************************************************

        ; *** DIVIDE *** SUBDE *** CHKSGN *** CHGSGN *** & CKHLDE ***

        ; 'DIVIDE' DIVIDES HL BY DE, RESULT IN BC, REMAINDER IN HL

        ; 'SUBDE' SUBSTRACTS DE FROM HL

        ; 'CHKSGN' CHECKS SIGN OF HL.  IF +, NO CHANGE.  IF -, CHANGE
        ; SIGN AND FLIP SIGN OF B.

        ; 'CHGSGN' CHECKS SIGN N OF HL AND B UNCONDITIONALLY.

        ; 'CKHLDE' CHECKS SIGN OF HL AND DE.  IF DIFFERENT, HL AND DE
        ; ARE INTERCHANGED.  IF SAME SIGN, NOT INTERCHANGED.  EITHER
        ; CASE, HL DE ARE THEN COMPARED TO SET THE FLAGS.

DIVIDE: PUSH HL                          ; *** DIVIDE ***
        ld   l,h                         ; DIVIDE H BY DE
        LD   H,0
        CALL DV1
        LD   B,C                         ; SAVE RESULT IN B
        LD   A,L                         ; (REMINDER+L)/DE
        POP  HL
        LD   H,A
DV1:    LD   C,0FFH                      ; RESULT IN C
DV2:    INC  C                           ; DUMB ROUTINE
        CALL SUBDE                       ; DIVIDE BY SUBTRACT
        JP NC,DV2                        ; AND COUNT
        ADD HL,DE
        RET

SUBDE:  LD   A,L                         ; *** SUBDE ***
        SUB  E                           ; SUBSTRACT DE FROM
        LD   L,A                         ; HL
        LD   A,H
        sbc a,D
        LD   H,A
        RET

CHKSGN: LD   A,H                         ; *** CHKSGN ***
        OR  A                            ; CHECK SIGN OF HL
        RET P                            ; IF -, CHANGE SIGN

CHGSGN: LD   A,H                         ; *** CHGSGN ***
        PUSH AF
        CPL                              ; CHANGE SIGN OF HL
        LD   H,A
        LD   A,L
        CPL
        LD   L,A
        INC  HL
        POP  AF
        XOR  H
        JP P,QHOW
        LD   A,B                         ; AND ALSO FLIP B
        XOR  80H
        LD   B,A
        RET

CKHLDE: LD   A,H
        XOR  D                           ; SAME SIGN?
        JP P,CK1                         ; YES, COMPARE
        EX DE,HL                         ; NO, XCH AND COMP
CK1:    CALL COMP
        RET;,5                          ; No idea if this was a typo but it said ret,5 which didn't assemble.

        ; *************************************************************

        ; *** SETVAL *** FIN *** ENDCHK *** & ERROR (& FRIENDS) ***

        ; "SETVAL" EXPECTS A VARIABLE, FOLLOWED BY AN EQUAL SIGN AND
        ; THEN AN EXPR.  IT EVALUATES THE EXPR. AND SET THE VARIABLE
        ; TO THAT VALUE.

        ; "FIN" CHECKS THE END OF A COMMAND.  IF IT ENDED WITH ";",
        ; EXECUTION CONTINUES.  IF IT ENDED WITH A CR, IT FINDS THE
        ; NEXT LINE AND CONTINUE FROM THERE.

        ; "ENDCHK" CHECKS IF A COMMAND IS ENDED WITH CR.  THIS IS
        ; REQUIRED IN CERTAIN COMMANDS.  (GOTO, RETURN, AND STOP ETC.)

        ; "ERROR" PRINTS THE STRING POINTED BY DE (AND ENDS WITH CR).
        ; IT THEN PRINTS THE LINE POINTED BY 'CURRNT' WITH A "?"
        ; INSERTED AT WHERE THE OLD TEXT POINTER (SHOULD BE ON TOP
        ; OF THE STACK) POINTS TO.  EXECUTION OF TB IS STOPPED
        ; AND TBI IS RESTARTED.  HOWEVER, IF 'CURRNT' -> ZERO
        ; (INDICATING A DIRECT COMMAND), THE DIRECT COMMAND IS NOT
        ; PRINTED.  AND IF 'CURRNT' -> NEGATIVE # (INDICATING 'INPUT'
        ; COMMAND), THE INPUT LINE IS NOT PRINTED AND EXECUTION IS
        ; NOT TERMINATED BUT CONTINUED AT 'INPERR'.

        ; RELATED TO 'ERROR' ARE THE FOLLOWING:
        ; 'QWHAT' SAVES TEXT POINTER IN STACK AND GET MESSAGE "WHAT?"
        ; 'AWHAT' JUST GET MESSAGE "WHAT?" AND JUMP TO 'ERROR'.
        ; 'QSORRY' AND 'ASORRY' DO SAME KIND OF THING.
        ; 'AHOW' AND 'AHOW' IN THE ZERO PAGE SECTION ALSO DO THIS.

SETVAL: CALL TSTV                          ; *** SETVAL ***
        JP C,QWHAT                       ; "WHAT?" NO VARIABLE
        PUSH HL                          ; SAVE ADDRESS OF VAR.
        CALL TSTC                          ; PASS "=" SIGN
        DB   '='
        DB   SV1-$-1
        CALL EXPR                          ; EVALUATE EXPR.
        LD   B,H                         ; VALUE IS IN BC NOW
        LD   C,L
        POP  HL                          ; GET ADDRESS
        LD   (HL),C                      ; SAVE VALUE
        INC  HL
        LD   (HL),B
        RET
SV1:    JP  QWHAT                        ; NO "=" SIGN

FIN:    CALL TSTC                          ; *** FIN ***
        DB   3BH
        DB   FI1-$-1
        POP  AF                          ; ";", PURGE RET. ADDR.
        JP  RUNSML                       ; CONTINUE SAME LINE
FI1:    CALL TSTC                          ; NOT ";", IS IT CR?
        DB   CR
        DB   FI2-$-1
        POP  AF                          ; YES, PURGE RET. ADDR.
        JP  RUNNXL                       ; RUN NEXT LINE
FI2:    RET                              ; ELSE RETURN TO CALLER

ENDCHK: CALL IGNBLK                          ; *** ENDCHK ***
        CP  CR                           ; END WITH CR?
        RET Z                            ; OK, ELSE SAY: "WHAT?"

QWHAT:  PUSH DE                          ; *** QWHAT ***
AWHAT:  LD  DE,WHAT                      ; *** AWHAT ***
ERROR:  SUB  A                           ; *** ERROR ***
        CALL PRTSTG                      ; PRINT 'WHAT?', 'HOW?'
        POP  DE                          ; OR 'SORRY'
        LD A,(DE)                        ; SAVE THE CHARACTER
        PUSH AF                          ; AT WHERE OLD DE ->
        SUB  A                           ; AND PUT A 0 THERE
        LD (DE),A
        LD HL,(CURRNT)                   ; GET CURRENT LINE #
        PUSH HL
        LD   A,(HL)                      ; CHECK THE VALUE
        INC  HL
        OR  (HL)
        POP  DE
        JP Z,RSTART                      ; IF ZERO, JUST RESTART
        LD   A,(HL)                      ; IF NEGATIVE,
        OR  A
        JP M,INPERR                      ; REDO INPUT
        CALL PRTLN                       ; ELSE PRINT THE LINE
        DEC  DE                          ; UPTO WHERE THE 0 IS
        POP  AF                          ; RESTORE THE CHARACTER
        LD (DE),A
        LD   A,3FH                       ; PRINT A "?"
        CALL OUTC
        SUB  A                           ; AND THE REST OF THE
        CALL PRTSTG                      ; LINE
        JP  RSTART                       ; THEN RESTART

QSORRY: PUSH DE                          ; *** QSORRY ***
ASORRY: LD  DE,SORRY                     ; *** ASORRY ***
        JP  ERROR

        ; *************************************************************

        ; *** GETLN *** FNDLN (& FRIENDS) ***

        ; 'GETLN' READS A INPUT LINE INTO 'BUFFER'.  IT FIRST PROMPT
        ; THE CHARACTER IN A (GIVEN BY THE CALLER), THEN IT FILLS
        ; THE BUFFER AND ECHOS.  IT IGNORES LF'S AND NULLS, BUT STILL
        ; ECHOS THEM BACK.  RUB-OUT IS USED TO CAUSE IT TO DELETE
        ; THE LAST CHARACTER (IF THERE IS ONE), AND ALT-MOD IS USED TO
        ; CAUSE IT TO DELETE THE WHOLE LINE AND START IT ALL OVER.
        ; CR SIGNALS THE END OF A LINE, AND CAUSE 'GETLN' TO RETURN.

        ; 'FNDLN' FINDS A LINE WITH A GIVEN LINE # (IN HL) IN THE
        ; TEXT SAVE AREA.  DE IS USED AS THE TEXT POINTER.  IF THE
        ; LINE IS FOUND, DE WILL POINT TO THE BEGINNING OF THAT LINE
        ; (I.E., THE LOW BYTE OF THE LINE #), AND FLAGS ARE NC & Z.
        ; IF THAT LINE IS NOT THERE AND A LINE WITH A HIGHER LINE #
        ; IS FOUND, DE POINTS TO THERE AND FLAGS ARE NC & NZ.  IF
        ; WE REACHED THE END OF TEXT SAVE AREA AND CANNOT FIND THE
        ; LINE, FLAGS ARE C & NZ.
        ; 'FNDLN' WILL INITIALIZE DE TO THE BEGINNING OF THE TEXT SAVE
        ; AREA TO START THE SEARCH.  SOME OTHER ENTRIES OF THIS
        ; ROUTINE WILL NOT INITIALIZE DE AND DO THE SEARCH.
        ; 'FNDLNP' WILL START WITH DE AND SEARCH FOR THE LINE #.
        ; 'FNDNXT' WILL BUMP DE BY 2, FIND A CR AND THEN START SEARCH.
        ; 'FNDSKP' USE DE TO FIND A CR, AND THEN START SEARCH.

GETLN:  CALL OUTC                          ; *** GETLN ***
        LD  DE,BUFFER                    ; PROMPT AND INIT.
GL1:    CALL CHKIO                       ; CHECK KEYBOARD
        JP Z,GL1                         ; NO INPUT, WAIT
        CP  08H                          ; DELETE LAST CHARACTER?
        JP Z,GL3                         ; YES
        CALL OUTC                          ; INPUT, ECHO BACK
        CP  0AH                          ; IGNORE LF
        JP Z,GL1
        OR  A                            ; IGNORE NULL
        JP Z,GL1
        CP  7DH                          ; DELETE THE WHOLE LINE?
        JP Z,GL4                         ; YES
        LD (DE),A                        ; ELSE SAVE INPUT
        INC  DE                          ; AND BUMP POINTER
        CP  0DH                          ; WAS IT CR?
        RET Z                            ; YES, END OF LINE
        LD   A,E                         ; ELSE MORE FREE ROOM?
        CP  BUFEND & 0FFH
        JP NZ,GL1                        ; YES, GET NEXT INPUT
GL3:    LD   A,E                         ; DELETE LAST CHARACTER
        CP  BUFFER & 0FFH                ; BUT DO WE HAVE ANY?
        JP Z,GL4                         ; NO, REDO WHOLE LINE
        DEC  DE                          ; YES, BACKUP POINTER
        LD   A,08H                       ; AND move cursor left, print space, cursor left again (to rub-out)
        CALL OUTC
        ld a, ' '
        CALL OUTC
        ld a, 08h
        CALL OUTC
        JP  GL1                          ; GO GET NEXT INPUT
GL4:    CALL CRLF                        ; REDO ENTIRE LINE
        LD   A,05EH                      ; CR, LF AND UP-ARROW
        JP  GETLN

FNDLN:  LD   A,H                         ; *** FNDLN ***
        OR  A                            ; CHECK SIGN OF HL
        JP M,QHOW                        ; IT CANNOT BE -
        LD  DE,TXTBGN                    ; INIT TEXT POINTER

FNDLP:                                   ; *** FDLNP ***
FL1:    PUSH HL                          ; SAVE LINE #
        LD HL,(TXTUNF)                   ; CHECK IF WE PASSED END
        DEC  HL
        CALL COMP
        POP  HL                          ; GET LINE # BACK
        RET C                            ; C,NZ PASSED END
        LD A,(DE)                        ; WE DID NOT, GET BYTE 1
        SUB  L                           ; IS THIS THE LINE?
        LD   B,A                         ; COMPARE LOW ORDER
        INC  DE
        LD A,(DE)                        ; GET BYTE 2
        sbc a,H                          ; COMPARE HIGH ORDER
        JP C,FL2                         ; NO, NOT THERE YET
        DEC  DE                          ; ELSE WE EITHER FOUND
        OR  B                            ; IT, OR IT IS NOT THERE
        RET                              ; NC,Z:FOUND, NC,NZ:NO

FNDNXT:                                  ; *** FNDNXT ***
        INC  DE                          ; FIND NEXT LINE
FL2:    INC  DE                          ; JUST PASSED BYTE 1 & 2

FNDSKP: LD A,(DE)                        ; *** FNDSKP ***
        CP  CR                           ; TRY TO FIND CR
        JP NZ,FL2                        ; KEEP LOOKING
        INC  DE                          ; FOUND CR, SKIP OVER
        JP  FL1                          ; CHECK IF END OF TEXT

                                         ; *************************************************************

                                         ; *** PRTSTG *** QTSTG *** PRTNUM *** & PRTLN ***

                                         ; 'PRTSTG' PRINTS A STRING POINTED BY DE.  IT STOPS PRINTING
                                         ; AND RETURNS TO CALLER WHEN EITHER A CR IS PRINTED OR WHEN
                                         ; THE NEXT BYTE IS THE SAME AS WHAT WAS IN A (GIVEN BY THE
                                         ; CALLER).  OLD A IS STORED IN B, OLD B IS LOST.

                                         ; 'QTSTG' LOOKS FOR A BACK-ARROW, SINGLE QUOTE, OR DOUBLE
                                         ; QUOTE.  IF NONE OF THESE, RETURN TO CALLER.  IF BACKSLASH,
                                         ; OUTPUT A CR WITHOUT A LF.  IF SINGLE OR DOUBLE QUOTE, PRINT
                                         ; THE STRING IN THE QUOTE AND DEMANDS A MATCHING UNQUOTE.
                                         ; AFTER THE PRINTING THE NEXT 3 BYTES OF THE CALLER IS SKIPPED
                                         ; OVER (USUALLY A JUMP INSTRUCTION.

                                         ; 'PRTNUM' PRINTS THE NUMBER IN HL.  LEADING BLANKS ARE ADDED
                                         ; IF NEEDED TO PAD THE NUMBER OF SPACES TO THE NUMBER IN C.
                                         ; HOWEVER, IF THE NUMBER OF DIGITS IS LARGER THAN THE # IN
                                         ; C, ALL DIGITS ARE PRINTED ANYWAY.  NEGATIVE SIGN IS ALSO
                                         ; PRINTED AND COUNTED IN, POSITIVE SIGN IS NOT.

                                         ; 'PRTLN' PRINTS A SAVED TEXT LINE WITH LINE # AND ALL.

PRTSTG: LD   B,A                         ; *** PRTSTG ***
PS1:    LD A,(DE)                        ; GET A CHARACTER
        INC  DE                          ; BUMP POINTER
        CP  B                            ; SAME AS OLD A?
        RET Z                            ; YES, RETURN
        CALL OUTC                          ; ELSE PRINT IT
        CP  CR                           ; WAS IT A CR?
        JP NZ,PS1                        ; NO, NEXT
        RET                              ; YES, RETURN

QTSTG:  CALL TSTC                          ; *** QTSTG ***
        DB   34                          ; ascii for quote
        DB   QT3-$-1
        LD   A,22H                       ; IT IS A quote
QT1:    CALL PRTSTG                      ; PRINT UNTIL ANOTHER
        CP  CR                           ; WAS LAST ONE A CR?
        POP  HL                          ; RETURN ADDRESS
        JP Z,RUNNXL                      ; WAS CR, RUN NEXT LINE
QT2:    INC  HL                          ; SKIP 3 BYTES ON RETURN
        INC  HL
        INC  HL
        JP (HL)                          ; RETURN
QT3:    CALL TSTC                          ; IS IT A '?
        DB   27H
        DB   QT4-$-1
        LD   A,27H                       ; YES, DO THE SAME
        JP  QT1                          ; AS IN quote
QT4:    CALL TSTC                          ; IS IT BACKSLASH " \ "?
        DB   5CH
        DB   QT5-$-1
        LD   A,0DH                       ; YES, CR WITHOUT LF
        CALL OUTC
        POP  HL                          ; RETURN ADDRESS
        JP  QT2
QT5:    RET                              ; NONE OF ABOVE

PRTNUM: LD   B,0                         ; *** PRTNUM ***
        CALL CHKSGN                      ; CHECK SIGN
        JP P,PN1                         ; NO SIGN
        LD   B,'-'                       ; B=SIGN
        DEC  C                           ; '-' TAKES SPACE
PN1:    PUSH DE                          ; SAVE
        LD  DE,0AH                       ; DECIMAL
        PUSH DE                          ; SAVE AS A FLAG
        DEC  C                           ; C=SPACES
        PUSH BC                          ; SAVE SIGN & SPACE
PN2:    CALL DIVIDE                      ; DIVIDE HL BY 10
        LD   A,B                         ; RESULT 0?
        OR  C
        JP Z,PN3                         ; YES, WE GOT ALL
        EX (SP),HL                       ; NO, SAVE REMAINDER
        DEC  L                           ; AND COUNT SPACE
        PUSH HL                          ; HL IS OLD BC
        LD   H,B                         ; MOVE RESULT TO BC
        LD   L,C
        JP  PN2                          ; AND DIVIDE BY 10
PN3:    POP  BC                          ; WE GOT ALL DIGITS IN
PN4:    DEC  C                           ; THE STACK
        LD   A,C                         ; LOOK AT SPACE COUNT
        OR  A
        JP M,PN5                         ; NO LEADING BLANKS
        LD   A,20H                       ; LEADING BLANKS
        CALL OUTC
        JP  PN4                          ; MORE?
PN5:    LD   A,B                         ; PRINT SIGN
        OR  A
        CALL NZ,10H
        LD   E,L                         ; LAST REMAINDER IN E
PN6:    LD   A,E                         ; CHECK DIGIT IN E
        CP  0AH                          ; 10 IS FLAG FOR NO MORE
        POP  DE
        RET Z                            ; IF SO, RETURN
        ADD  A,30H                       ; ELSE CONVERT TO ASCII
        CALL OUTC                          ; AND PRINT THE DIGIT
        JP  PN6                          ; GO BACK FOR MORE

PRTLN:  LD A,(DE)                        ; *** PRTLN ***
        LD   L,A                         ; LOW ORDER LINE #
        INC  DE
        LD A,(DE)                        ; HIGH ORDER
        LD   H,A
        INC  DE
        LD   C,4H                        ; PRINT 4 DIGIT LINE #
        CALL PRTNUM
        LD   A,20H                       ; FOLLOWED BY A BLANK
        CALL OUTC
        SUB  A                           ; AND THEN THE NEXT
        CALL PRTSTG
        RET

        ; *************************************************************

        ; *** MVUP *** MVDOWN *** POPA *** & PUSHA ***

        ; 'MVUP' MOVES A BLOCK UP FROM WHERE DE-> TO WHERE BC-> UNTIL
        ; DE = HL

        ; 'MVDOWN' MOVES A BLOCK DOWN FROM WHERE DE-> TO WHERE HL->
        ; UNTIL DE = BC

        ; 'POPA' RESTORES THE 'FOR' LOOP VARIABLE SAVE AREA FROM THE
        ; STACK

        ; 'PUSHA' STACKS THE 'FOR' LOOP VARIABLE SAVE AREA INTO THE
        ; STACK

MVUP:   CALL COMP                          ; *** MVUP ***
        RET Z                            ; DE = HL, RETURN
        LD A,(DE)                        ; GET ONE BYTE
        LD (BC),A                        ; MOVE IT
        INC  DE                          ; INCREASE BOTH POINTERS
        INC  BC
        JP  MVUP                         ; UNTIL DONE

MVDOWN: LD   A,B                         ; *** MVDOWN ***
        SUB  D                           ; TEST IF DE = BC
        JP NZ,MD1                        ; NO, GO MOVE
        LD   A,C                         ; MAYBE, OTHER BYTE?
        SUB  E
        RET Z                            ; YES, RETURN
MD1:    DEC  DE                          ; ELSE MOVE A BYTE
        DEC  HL                          ; BUT FIRST DECREASE
        LD A,(DE)                        ; BOTH POINTERS AND
        LD   (HL),A                      ; THEN DO IT
        JP  MVDOWN                       ; LOOP BACK

POPA:   POP  BC                          ; BC = RETURN ADDR.
        POP  HL                          ; RESTORE LOPVAR, BUT
        LD (LOPVAR),HL                   ; =0 MEANS NO MORE
        LD   A,H
        OR  L
        JP Z,PP1                         ; YEP, GO RETURN
        POP  HL                          ; NOP, RESTORE OTHERS
        LD (LOPINC),HL
        POP  HL
        LD (LOPLMT),HL
        POP  HL
        LD (LOPLN),HL
        POP  HL
        LD (LOPPT),HL
PP1:    PUSH BC                          ; BC = RETURN ADDR.
        RET

PUSHA:  LD  HL,STKLMT                    ; *** PUSHA ***
        CALL CHGSGN
        POP  BC                          ; BC=RETURN ADDRESS
        ADD HL,SP                        ; IS STACK NEAR THE TOP?
        JP NC,QSORRY                     ; YES, SORRY FOR THAT
        LD HL,(LOPVAR)                   ; ELSE SAVE LOOP VAR'S
        LD   A,H                         ; BUT IF LOPVAR IS 0
        OR  L                            ; THAT WILL BE ALL
        JP Z,PU1
        LD HL,(LOPPT)                    ; ELSE, MORE TO SAVE
        PUSH HL
        LD HL,(LOPLN)
        PUSH HL
        LD HL,(LOPLMT)
        PUSH HL
        LD HL,(LOPINC)
        PUSH HL
        LD HL,(LOPVAR)
PU1:    PUSH HL
        PUSH BC                          ; BC = RETURN ADDR.
        RET

        ; *************************************************************

        ; *** OUTC *** & CHKIO ***

        ; THESE ARE THE ONLY I/O ROUTINES IN TBI.
        ; 'OUTC' IS CONTROLLED BY A SOFTWARE SWITCH 'OCSW'.  IF OCSW=0
        ; 'OUTC' WILL JUST RETURN TO THE CALLER.  IF OCSW IS NOT 0,
        ; IT WILL OUTPUT THE BYTE IN A.  IF THAT IS A CR, A LF IS ALSO
        ; SEND OUT.  ONLY THE FLAGS MAY BE CHANGED AT RETURN. ALL REG.
        ; ARE RESTORED.

        ; 'CHKIO' CHECKS THE INPUT.  IF NO INPUT, IT WILL RETURN TO
        ; THE CALLER WITH THE Z FLAG SET.  IF THERE IS INPUT, Z FLAG
        ; IS CLEARED AND THE INPUT BYTE IS IN A.  HOWEVER, IF THE
        ; INPUT IS A CONTROL-O, THE 'OCSW' SWITCH IS COMPLIMENTED, AND
        ; Z FLAG IS RETURNED.  IF A CONTROL-C IS READ, 'CHKIO' WILL
        ; RESTART TBI AND DOES NOT RETURN TO THE CALLER.




INIT:   LD  (OCSW),A

        call message
        DB 27,'[2J',27,'[H'
        DB 201,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,187,CR,LF
        DB 186,'  TINY BASIC v2.2 for Z80 Playground  ',186,CR,LF
        DB 200,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,188,CR,LF
        DB CR,LF
        db 'Disk commands are:',CR,LF
        db '  DIR',CR,LF
        db '  SAVE "filename"',CR,LF
        db '  LOAD "filename"',CR,LF
        db '  ERASE "filename"',CR,LF
        db 'Return to the monitor with:',CR,LF
        db '  EXIT',CR,LF
        db 'Other keywords:',CR,LF
        DB   '  REM, '
        DB   'NEW, '
        DB   'LIST, '
        DB   'RUN, '
        DB   'LET, '
        DB   'IF, '
        DB   'GOTO, '
        DB   'GOSUB,',13,10
        DB   '  RETURN, '
        DB   'FOR, '
        DB   'TO, '
        DB   'STEP, '
        DB   'NEXT, '
        DB   'INPUT, '
        DB   'PRINT, '
        DB   'STOP, '
        DB   'RND, '
        DB   'ABS, '
        DB   'SIZE, '
        DB   'PEEK',13,10
        db 'This version is case-insensitive!'
        DB CR,LF,0

        LD  HL,TBSTART
        LD (RANPNT),HL
        LD  HL,TXTBGN
        LD (TXTUNF),HL
        JP  RSTART

CHKIO:
        in a,(uart_LSR)                  ; get status from Line Status Register
        bit 0,a                          ; zero flag set to true if bit 0 is 0 (bit 0 = Receive Data Ready)
                                         ; "logic 0 = no data in receive holding register."
        ret z                            ; zero = no char received
        in a,(uart_tx_rx)                ; Get the incoming char from the keyboard
        cp 0
        ret z                            ; If no key pressed, return Z

        AND  7FH                         ; MASK BIT 7 OFF
        CP  0FH                          ; IS IT CONTROL-O?
        JP NZ,CI1                        ; NO, MORE CHECKING
        LD  A,(OCSW)                     ; CONTROL-O FLIPS OCSW
        CPL                              ; ON TO OFF, OFF TO ON
        LD  (OCSW),A
        JP  CHKIO                        ; GET ANOTHER INPUT
CI1:    CP  3H                           ; IS IT CONTROL-C?
        RET NZ                           ; NO, RETURN "NZ"
        JP  RSTART                       ; YES, RESTART TBI

        ; *************************************************************

        ; *** TABLES *** DIRECT *** & EXEC ***

        ; THIS SECTION OF THE CODE TESTS A STRING AGAINST A TABLE.
        ; WHEN A MATCH IS FOUND, CONTROL IS TRANSFERED TO THE SECTION
        ; OF CODE ACCORDING TO THE TABLE.

        ; AT 'EXEC', DE SHOULD POINT TO THE STRING AND HL SHOULD POINT
        ; TO THE TABLE-1.  AT 'DIRECT', DE SHOULD POINT TO THE STRING.
        ; HL WILL BE SET UP TO POINT TO TAB1-1, WHICH IS THE TABLE OF
        ; ALL DIRECT AND STATEMENT COMMANDS.

        ; A '.' IN THE STRING WILL TERMINATE THE TEST AND THE PARTIAL
        ; MATCH WILL BE CONSIDERED AS A MATCH.  E.G., 'P.', 'PR.',
        ; 'PRI.', 'PRIN.', OR 'PRINT' WILL ALL MATCH 'PRINT'.

        ; THE TABLE CONSISTS OF ANY NUMBER OF ITEMS.  EACH ITEM
        ; IS A STRING OF CHARACTERS WITH BIT 7 SET TO 0 AND
        ; A JUMP ADDRESS STORED HI-LOW WITH BIT 7 OF THE HIGH
        ; BYTE SET TO 1.

        ; END OF TABLE IS AN ITEM WITH A JUMP ADDRESS ONLY.  IF THE
        ; STRING DOES NOT MATCH ANY OF THE OTHER ITEMS, IT WILL
        ; MATCH THIS NULL ITEM AS DEFAULT.

TAB1:                                    ; DIRECT COMMANDS
        DB   'LIST'
        DWA  LIST
        DB   'RUN'
        DWA  RUN
        DB   'NEW'
        DWA  NEW
        DB   'DIR'
        DWA  TBDIR
        DB   'SAVE'
        DWA  SAVE
        DB   'LOAD'
        DWA  LOAD
        DB   'ERASE'
        DWA  ERASE
        DB   'EXIT'
        DWA  EXIT

TAB2:                                    ; DIRECT/STATEMENT
        DB   'NEXT'
        DWA  NEXT
        DB   'LET'
        DWA  LET
        DB   'IF'
        DWA  IFF
        DB   'GOTO'
        DWA  GOTO
        DB   'GOSUB'
        DWA  GOSUB
        DB   'RETURN'
        DWA  RETURN
        DB   'REM'
        DWA  REM
        DB   'FOR'
        DWA  FOR
        DB   'INPUT'
        DWA  INPUT
        DB   'PRINT'
        DWA  PRINT
        DB   'STOP'
        DWA  STOP
        DWA  DEFLT

TAB4:                                    ; FUNCTIONS
        DB   'RND'
        DWA  RND
        DB   'ABS'
        DWA  ABS
        DB   'SIZE'
        DWA  SIZE
        DB   'PEEK'
        DWA  PEEK
        DWA  XP40

TAB5:                                    ; "TO" IN "FOR"
        DB   'TO'
        DWA  FR1
        DWA  QWHAT

TAB6:                                    ; "STEP" IN "FOR"
        DB   'STEP'
        DWA  FR2
        DWA  FR3

TAB8:                                    ; RELATION OPERATORS
        DB   '>='
        DWA  XP11
        DB   '#'
        DWA  XP12
        DB   '>'
        DWA  XP13
        DB   '='
        DWA  XP15
        DB   '<='
        DWA  XP14
        DB   '<'
        DWA  XP16
        DWA  XP17

DIRECT: LD  HL,TAB1-1                    ; *** DIRECT ***

EXEC:                                    ; *** EXEC ***
EX0:    CALL IGNBLK                          ; IGNORE LEADING BLANKS
        PUSH DE                          ; SAVE POINTER
EX1:    LD A,(DE)                        ; IF FOUND '.' IN STRING
        INC  DE                          ; BEFORE ANY MISMATCH
        CP  '.'                          ; WE DECLARE A MATCH
        JP Z,EX3
        cp 'a'                           ; If text is in lowercase,
        jr c,not_lowercase               ; uppercase it
        res 5,a                          ; by clearing bit 5
not_lowercase:
        INC  HL                          ; HL->TABLE
        CP  (HL)                         ; IF MATCH, TEST NEXT
        JP Z,EX1
        LD   A,07FH                      ; ELSE SEE IF BIT 7
        DEC  DE                          ; OF TABLE IS SET, WHICH
        CP  (HL)                         ; IS THE JUMP ADDR. (HI)
                                         ; TODO: Change this to use "BIT" instruction?
        JP C,EX5                         ; C:YES, MATCHED
EX2:    INC  HL                          ; NC:NO, FIND JUMP ADDR.
        CP  (HL)
        JP NC,EX2
        INC  HL                          ; BUMP TO NEXT TAB. ITEM
        POP  DE                          ; RESTORE STRING POINTER
        JP  EX0                          ; TEST AGAINST NEXT ITEM
EX3:    LD   A,07FH                      ; PARTIAL MATCH, FIND
EX4:    INC  HL                          ; JUMP ADDR., WHICH IS
        CP  (HL)                         ; FLAGGED BY BIT 7
        JP NC,EX4
EX5:    LD   A,(HL)                      ; LOAD HL WITH THE JUMP
        INC  HL                          ; ADDRESS FROM THE TABLE
        LD   L,(HL)
        AND  7FH                         ; MASK OFF BIT 7
        LD   H,A
        POP  AF                          ; CLEAN UP THE GABAGE
        JP (HL)                          ; AND WE GO DO IT

READ_QUOTED_FILENAME:
        call IGNBLK                     ; Skip any spaces after "save".
        CALL TSTC                       ; Is this followed by quoted string?
        DB   '"'                        ; ascii for quote
        DB   SAVE_NO_QUOTE-$-1

        call IGNBLK                     ; Skip leading spaces at the start of the name.
        ld hl, filename_buffer          ; Clear out the filename and extension with NULLs
        ld b, 14
CLEAR_FILENAME_LOOP:
        ld (hl), 0
        inc hl
        djnz CLEAR_FILENAME_LOOP

        ld hl, filename_buffer          ; We store the filename here.
        ld b, 8
READ_FILE_NAME:
        LD A,(DE)                        ; GET A CHARACTER from string
        INC  DE                          
        CP  '.'                         ; Found dot?
        jr z, CONTINUE_TO_EXTENSION
        CP  '"'                         ; Found end quote?
        jr z, READ_FILE_NAME_DONE
        cp CR                           ; Or has command ended?
        jp z, QWHAT                         ; Well that's an error.

        cp 33
        jr c, KILL_CONTROL              ; Don't allow control chars or spaces!!!
        cp 96                           
        jr c, USE_LETTER                ; Do allow numbers and upper case letters
        cp 127
        jr nc, KILL_CONTROL             ; Don't allow weird chars
        and 11011111B                   ; Make lowercase letters uppercase
        jr USE_LETTER

KILL_CONTROL:
        ld a, '_'
USE_LETTER:
        ld (hl),a                       ; store this letter
        inc hl
        djnz READ_FILE_NAME

        LD A,(DE)                        ; GET A CHARACTER from string
        INC  DE                          
        CP  '.'                         ; Found dot?
        jp nz, QWHAT                    ; Error if not
CONTINUE_TO_EXTENSION:
        ld (hl), a
        inc hl

        ld b, 3                         ; 3 chars max for extension
READ_EXTENSION:
        LD A,(DE)                        ; GET A CHARACTER from string
        INC  DE                          
        CP  '.'                         ; Found dot?
        jp z, QWHAT
        CP  '"'                         ; Found end quote?
        jr z, READ_FILE_NAME_DONE
        cp CR                           ; Or has command ended?
        jp z, QWHAT                         ; Well that's an error.

        cp 32
        jr c, KILL_CONTROL_EXT          ; Don't allow control chars
        cp 96                           
        jr c, USE_LETTER_EXT            ; Do allow numbers and upper case letters
        cp 127
        jr nc, KILL_CONTROL_EXT         ; Don't allow weird chars
        and 11011111B                   ; Make lowercase letters uppercase
        jr USE_LETTER_EXT

KILL_CONTROL_EXT:
        ld a, '_'
USE_LETTER_EXT:
        ld (hl),a                       ; store this letter
        inc hl
        djnz READ_EXTENSION

        ld a, (de)                      ; So now there must be a quote
        inc de
        cp '"'
        jr nz, SAVE_NO_QUOTE

READ_FILE_NAME_DONE:
        ld (hl), 0
        call ENDCHK

;        call debug
;        db 'Filename is [',0
;        ld b, 14
;        ld hl, filename_buffer
;x1:
;        ld a, (hl)
;        inc hl
;        call OUTC
;        djnz x1

;        ld a, ']'
;        call OUTC
;        call newline

        ret

SAVE_NO_QUOTE:
        call message
        db 'Please specify a filename in quotes, such as "FILENAME.TXT"',13,0
        jp RSTART

LSTROM	equ	$                             ; ALL ABOVE CAN BE ROM


                                         ; HERE DOWN MUST BE RAM
RAMSTART equ 08000H                     ; This assumes we are switched into 32K ROM / 32K RAM mode. TODO: Maybe change this to 16k rom, 48k ram???

OCSW    equ	RAMSTART                     ; SWITCH FOR OUTPUT		1 byte
CURRNT	equ	OCSW+1                        ; POINTS TO CURRENT LINE		2 bytes
STKGOS	equ	CURRNT+2                      ; SAVES SP IN 'GOSUB'		2 bytes
VARNXT	equ	STKGOS+2                      ; TEMP STORAGE			2 bytes
STKINP	equ VARNXT+2                      ; SAVES SP IN 'INPUT'		2 bytes
LOPVAR	equ STKINP+2                      ; 'FOR' LOOP SAVE AREA		2 bytes
LOPINC	equ LOPVAR+2                      ; INCREMENT			2 bytes
LOPLMT	equ LOPINC+2                      ; LIMIT				2 bytes
LOPLN	equ LOPLMT+2                       ; LINE NUMBER			2 bytes
LOPPT	equ LOPLN+2                        ; TEXT POINTER			2 bytes
RANPNT	equ LOPPT+2                       ; RANDOM NUMBER POINTER		2 bytes
TXTUNF	equ RANPNT+2                      ; ->UNFILLED TEXT AREA		2 bytes

store_hl	equ	TXTUNF+2	; Temporary store for hl                2 bytes

TXTBGN	equ store_hl+2                      ; TEXT SAVE AREA BEGINS		2 bytes - This is where the program starts.


TBSTACK	equ 0FF00h                         ; STACK STARTS HERE		allow 255 byte stack
STKLMT	equ	TBSTACK-255                     ; TOP LIMIT FOR STACK		1 byte
BUFEND	equ	STKLMT-1                      ; BUFFER ENDS			1 byte
BUFFER	equ	BUFEND-64                     ; INPUT BUFFER			64 bytes
VARBGN	equ	BUFFER-55                     ; VARIABLE @(0)			55 bytes

tb_dir_count equ VARBGN-1
TXTEND	equ	tb_dir_count-1                      ; TEXT SAVE AREA ENDS		1 byte - This is the top limit for the program

                                        ; Just for reference for my tired brain:
                                        ; if a has 30 in it
                                        ; cp 32
                                        ; jr c, IF A < 32
                                        ; jr nc, IF A >= 32
                                        ; jr z, IF A == 32
