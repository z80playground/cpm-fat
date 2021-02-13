; This was written by Albert Pauw in February 2021, originally for CP/M,
; and adapted for the Z80 playground Monitor by john Squires

Width:   EQU 80
Height:  EQU 25
Size:    EQU Width*Height
DOT:     EQU '.'
HASH:    EQU '#'
ESC:     EQU 27

GOFL_Begin:   
        call show_intro_screen
        call long_pause
        call wait_for_key
        CALL GOFL_HCursor   ; Hide cursor
        CALL GOFL_Cls       ; Clear screen
        call copy_initial_pattern
GOFL_Start:  
        ld hl, Buffer1
        CALL GOFL_Print     ; Show screen
        LD BC,0             ; Start at (0,0)
        LD HL,Buffer1       ;
        LD DE,Buffer2       ;
        call GOFL_Loop

        ld hl, Buffer2
        CALL GOFL_Print     ; Show screen
        LD BC,0             ; Start at (0,0)
        LD HL,Buffer2       ;
        LD DE,Buffer1       ;
        call GOFL_Loop

        CALL char_in        ; Check for keypress
        AND A               ;
        Jp Z,GOFL_Start     ; Loop around again if no key

        CALL GOFL_SCursor   ; Show cursor again
        CALL GOFL_Cls       ; Clear screen
        RET                 ; Done

GOFL_Loop:    
        LD A,(HL)           ; Get cell state
        CP HASH             ; Alive?
        jp NZ,GOFL_Dead     ; No, -> dead
        CALL GOFL_GetNB     ; Get nr of neighbours
        CP 2                ;
        jp Z,GOFL_Live      ;
        CP 3                ;
        jp Z,GOFL_Live      ;
        jp GOFL_Die         ;
GOFL_Dead:   
        CALL GOFL_GetNB     ;
        CP 3                ;
        jp Z,GOFL_Live      ;
GOFL_Die:    
        LD A,DOT            ; <2 Store as dead cell
        jp GOFL_Next        ;
GOFL_Live:    
        LD A,HASH           ;
GOFL_Next:    
        LD (DE),A           ; Store it in temporary buffer
        INC DE              ; 
        INC HL              ; Next cell
        INC B               ; Loop through width
        LD A,B              ;
        CP Width            ; And of line reached?
        jp NZ,GOFL_Loop     ; No, next
        LD B,0              ; Go to start of line
        INC C               ; Next line
        LD A,C              ;
        CP Height           ; Last line reached? 
        jp NZ,GOFL_Loop     ; No, next line
        ret


GOFL_GetNB:   
        PUSH HL        ; Save HL (B=X, C=Y coordinate)
        PUSH DE        ; save de too
	    LD D,HASH      ; D=HASH
        LD E,0         ; E=0 (neighbour count)
        LD A,B         ; Check if we're on the left margin
        AND A          ;
        jp Z,Lbl1      ; Yes, Skip left location
        DEC HL         ; Go to left
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,Lbl0     ; No, no count
        INC E          ; Yes, add 1
Lbl0:    
        INC HL         ; Back to standard location
Lbl1:    
        LD A,B         ; Check if we're on the right margin
        CP Width-1     ; 0-79 when width is 80
        jp Z,Lbl3      ; Yes, skip right location
        INC HL         ; Go to right
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,lbl2     ; No, no count
        INC E          ; Yes, add 1
lbl2:    
        DEC HL         ; Back to original location
Lbl3:    
        LD A,C         ; Check if we're at the top
        AND A          ; 
        jp Z,Lbl8      ; Yes, skip top three locations
        PUSH DE        ; Save count
        LD DE,Width    ; 
        AND A          ; Clear carry
        SBC HL,DE      ; Go to previous line
        POP DE         ; Restore count
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,Lbl4     ; No, no count
        INC E          ; Yes, add 1
Lbl4:    
        LD A,B         ; Check if we're on the left margin
        AND A          ;
        jp Z,Lbl6      ; Yes, skip left location
        DEC HL         ; Go to left
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,Lbl5     ; No, No count
        INC E          ; Yes, count
Lbl5:    
        INC HL         ; Go to middle top
Lbl6:    
        LD A,B         ; Check if we're on the right margin
        CP Width-1     ;
        jp Z,Lbl8      ; Yes, skip right location
        INC HL         ; Go to right
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,Lbl7     ; No, no count
        INC E          ; Yes, add 1
Lbl7:    
        DEC HL         ; Back to middle
Lbl8:    
        LD A,C         ;
        CP Height-1    ; Check if we're at the bottom
        jp Z,Lbl13     ;
        PUSH DE        ; Save counter
        LD DE,Width    ;
        ADD HL,DE      ; Go two lines down
        ADD HL,DE      ;
        POP DE         ; Restore counter
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,Lbl9     ; No, no count
        INC E          ; Yes, add 1
Lbl9:    
        LD A,B         ; Check if we're on the left margin
        AND A          ;
        jp Z,Lbl12     ; Yes, skip left location
        DEC HL         ; Go to left
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,Lbl10    ; No, No count
        INC E          ; Yes, count
Lbl10:   
        INC HL         ; Go to middle bottom
Lbl12:  
        LD A,B         ; Check if we're on the right margin
        CP Width-1     ;
        jp Z,Lbl13     ; Yes, skip right location
        INC HL         ; Go to right
        LD A,(HL)      ; Get value
        CP D           ; Occupied?
        jp NZ,Lbl13    ; No, no count
        INC E          ; Yes, add 1
Lbl13:   
        LD A,E         ; Get counter
        pop de
        POP HL         ; Back to start location
        RET            ;

GOFL_Print:  
        ; Pass in the pointer to the buffer to print, in HL
        call GOFL_Home
        LD c, Height-1    ; Set size
Pr0:
        ld b, Width
Pr1:    
        LD A,(HL)       ; Get character in buffer
        call print_a
        INC HL          ; Next character in buffer
        djnz Pr1        ; Count down and loop
        ld a, 13
        call print_a
        ld a, 10
        call print_a
        dec C
        ld a, c
        cp 0
        jp nz, Pr0

        ld b, Width
Pr2:    
        LD A,(HL)       ; Get character in buffer
        call print_a
        INC HL          ; Next character in buffer
        djnz Pr2        ; Count down and loop

        RET             ; Done

GOFL_Home:   
        call message
        DB ESC,'[H',0
        ret

GOFL_Cls:
        call message
        DB ESC,'[2J',ESC,'[H',0
        ret

GOFL_HCursor: 
        ; ANSI hide cursor
        call message
        DB ESC,'[?25l',0
        ret

GOFL_SCursor: 
        ; ANSI show cursor
        call message
        DB ESC,'[?25h',0
        ret

initial_pattern: 
        DB '................................................................................'
        DB '................................................................................'
        DB '.........................#......................................................'
        DB '.......................#.#......................................................'
        DB '.............##......##............##...........................................'
        DB '............#...#....##............##...........................................'
        DB '.##........#.....#...##.........................................................'
        DB '.##........#...#.##....#.#......................................................'
        DB '...........#.....#.......#......................................................'
        DB '............#...#...............................................................'
        DB '.............##.................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'

show_intro_screen:
    call GOFL_Cls
    call message
    db 'This is the "Game Of Life", originally devised by John Conway in the 1970s.',13,10
    db 'This implementation was written by Albert Pauw on a Z80 Playground using CP/M.',13,10
    db 'It has been adapted to run in the Monitor as a demo.',13,10
    db 'Make sure you have a screen of at least 80 x 25 characters.',13,10
    db 'Press any key to start...',13,10,0
    ret

wait_for_key:
    call char_in
    cp 0
    jp z, wait_for_key
    ret

copy_initial_pattern:
    ; Copy the starting pattern into buffer 1
    ld bc, Size
    ld de, Buffer1
    ld hl, initial_pattern
    ldir
    ret

; Up until this point, all is in ROM, but this next area needs to be ram:

Buffer1 equ 32768 
Buffer2 equ 32768+Size





