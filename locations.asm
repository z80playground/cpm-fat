; locations.asm
; Stores the ORG values for the CCP, BDOS, BIOS and CORE

CORE_START  equ $F600           ; $FFFF - 2.5K
BIOS_START  equ $F400           ; $F600 - 0.5K
BDOS_START  equ $EA00           ; $F400 - 2.5K
CCP_START   equ $DE00           ; $EA00 - 3.0K
