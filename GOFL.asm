; This was written by Albert Pauw in February 2021, originally for CP/M,
; and adapted for the Z80 playground Monitor by john Squires

; After boiling it down A LOT, it turns out that Game-Of-Life is very simple:
; Arrange a large grid of cells, where each can be either alive = 1 or dead = 0.
; Make sure there is an empty row all around the grid with a dead cell in it, like this:
; 0000000000
; 0XXXXXXXX0
; 0XXXXXXXX0
; 0000000000 Where 0 = dead cell, and X = active area which can be 0s or 1s.
; Iterate over all the cells in the active area. For each:
; Make a note of whether the cell is alive or dead.
; Add to this value the alive/dead value of all 8 neighbouring cells around it.
; Store the neighbour count in the top 4 bits, and the alive/dead state of the cell
; in bit 0. You will then end up with each cell having a binary value something like this:
; 0010 0001 - This is 2 neighbours and the cell is currently alive.
; 0011 0000 - This is a dead cell with 3 neighbours.
; 1000 0001 - This is an alive cell with 8 neighbours.
;
; Now, it turns out that all possible combinations result in the death of a cell, or
; a dead cell staying dead, except these three:
; 0010 0001 - Alive cell with 2 neighbours stays alive.
; 0011 0001 - Alive cell with 3 neighbours stays alive.
; 0011 0000 - Dead cell with 3 neighbours comes to life.
;
; So all we need to do is iterate over the cells again.
; If the cell contains one of these 3 values, set the cell to 1.
; Otherwise set it to 0.
;
; Then show them all on screen, and start again!

Width:   EQU 80
Height:  EQU 25
PatternWidth: equ 80
Size:    EQU Width*Height
DOT:     EQU '.' ; ASCII 46, so EVEN. This is important later!
HASH:    EQU '#' ; ASCII 25, so ODD. This is important later!
ESC:     EQU 27

GOFL_Begin:   
        call show_intro_screen
        call long_pause
        call wait_for_key
        CALL GOFL_HCursor   ; Hide cursor
        CALL GOFL_Cls       ; Clear screen
        call copy_initial_pattern
        call GOFL_Print

again:
        call iterate
        call apply_rules
        call GOFL_Print
        
        CALL char_in        ; Check for keypress
        AND A               ;
        Jp Z,again          ; Loop around again if no key
        ret

apply_rules:
        ld c, Height
        ld h, BufferPage+1
apply_rules_outer:
        ld l, 1                 ; Start at 1,1
        ld b, Width
apply_rules_loop:
        ; 0010 0001 - Alive cell with 2 neighbours stays alive.
        ; 0011 0001 - Alive cell with 3 neighbours stays alive.
        ; 0011 0000 - Dead cell with 3 neighbours comes to life.

        ld a, (hl)              ; Get the content into a
        cp %00100001
        jr z, cell_alive
        cp %00110001
        jr z, cell_alive
        cp %00110000
        jr z, cell_alive
        ld (hl), 0              ; Cell dies
        jp apply_rules_continue
cell_alive:
        ld (hl), 1              ; Cell lives
apply_rules_continue:        
        inc l
        djnz apply_rules_loop
        inc h
        ld l, 1
        dec c
        jr nz, apply_rules_outer
        ret

iterate:
        ld c, Height
        ld h, BufferPage+1
iterate_outer:
        ld l, 1                 ; Start at 1,1
        ld b, Width
iterate_loop:
        call CountNeighbours
        inc l
        djnz iterate_loop
        inc h
        ld l, 1
        dec c
        jr nz, iterate_outer
        ret

CountNeighbours:
        ; Pass in cell to process in HL
        ; It modifies this cell!
        ld a, (hl)                      ; Get original cell content
        and %00000001
        ld d, a                         ; Store in d

        xor a                           ; Clear a

        dec l                           ; West neighbour
        add a, (hl)
        dec h                           ; North-West neighbour
        add a, (hl)
        inc l                           ; North neighbour
        add a, (hl)
        inc l                           ; North-East neighbour
        add a, (hl)
        inc h                           ; East neighbour
        add a, (hl)
        inc h                           ; South-East neighbour
        add a, (hl)
        dec l                           ; South neighbour
        add a, (hl)
        dec l                           ; South-West neighbour
        add a, (hl)
        inc l                           ; Get back to cell
        dec h

        sla a                           ; rotate left
        sla a                           ; rotate left
        sla a                           ; rotate left
        sla a                           ; rotate left
        or d                            ; Put back the original cell content
        ld (hl), a                      ; Store final result
        ret

GOFL_Print:  
        ; Prints the buffer to the screen, for diagnostic purposes.
        call GOFL_Home
        ld h, BufferPage+1
        ld l, 1
        LD c, Height    ; Set size
Pr0:
        ld b, Width
Pr1:    
        LD A,(HL)               ; Get cell value in buffer
        and 1                   ; Is it ODD?
        jp z, print_empty_cell  ; If not, it is an empty cell
        ld d, HASH
        jp print_got_character
print_empty_cell:
        ld d, DOT        
print_got_character:
        in a,(uart_LSR)                 ; check UART is ready to send.
        bit 5,a                         ; zero flag set to true if bit 5 is 0
        jp z, print_got_character       ; non-zero = ready for next char.
        ld a, d
        out (uart_tx_rx), a             ; AND SEND IT OUT
        
        INC L           ; Next character in buffer
        djnz Pr1        ; Count down and loop

        dec c           ; decrease row counter
        jp z, skip_newline_on_last_row
        call newline
skip_newline_on_last_row:
        ld l, 1         ; Back to start of row
        inc h           ; Move down a row
        ld a, c
        cp 0
        jp nz, Pr0      ; Loop over rows
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
        DB '...................................................#............................'
        DB '.....................................................#..........................'
        DB '..................................................##..###.......................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'
        DB '................................................................................'

; initial_pattern: 
;         DB '................................................................................'
;         DB '..##............................................................................'
;         DB '.........................#......................................................'
;         DB '.......................#.#......................................................'
;         DB '.............##......##............##...........................................'
;         DB '............#...#....##............##...........................................'
;         DB '.##........#.....#...##.........................................................'
;         DB '.##........#...#.##....#.#......................................................'
;         DB '...........#.....#.......#......................................................'
;         DB '............#...#...............................................................'
;         DB '.............##.................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'
;         DB '................................................................................'

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
    ; Copy the starting pattern into the buffer.
    ; The pattern is made of "." and "#" but we store it in the buffer as
    ; 1s and 0s. We do this by ANDing the char with %00000001, which is
    ; why the '#' char needs to be ODD and the '.' char needs to be EVEN.
    
    ; But first, totally zero out the entire buffer
    ld hl, Buffer
    ld (hl), 0
    ld de, Buffer+1
    ld b, Height+3
    ld c, 0
    ldir

    ; Now copy the pattern to the buffer
    ld d, BufferPage+1                  ; Initialise at location 1,1
    ld e, 1                             ; in the buffer (top left is 0,0)
    ld hl, initial_pattern
    ld c, Height
copy_initial_pattern_rows:
    ld b, Width
    push hl                             ; Store pattern pointer
copy_initial_pattern_cols:
    ld a, (hl)                          ; Copy from pattern to buffer
    and %00000001                       ; Isolate bit 0 only
    ld (de), a
    inc hl                              ; Move to next location in pattern
    inc e                               ; next column
    djnz copy_initial_pattern_cols      ; loop columns
    pop hl                              ; Back to start of current row in pattern
    push de
    ld de, PatternWidth
    add hl, de                          ; Move to next row in pattern
    pop de
    ld e, 1                             ; Back to start of buffer row
    inc d                               ; But move down a row
    dec c                               ; loop rows
    jr nz, copy_initial_pattern_rows
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The buffer needs to be in RAM... ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Buffer equ $8000
BufferPage equ $80







