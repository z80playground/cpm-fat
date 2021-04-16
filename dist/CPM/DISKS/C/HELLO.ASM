	extrn	.begin,.chl,.swt
	extrn	csave,cret,.move
	PUBLIC main_
main_:	lxi d,.2
	call csave
	LXI H,.1+0
	PUSH H
	CALL printf_
	POP D
	LXI H,0
	RET
.2 EQU 0
.1:
	DB 72,101,108,108,111,44,32,119,111,114,108,100,10,0
	extrn	printf_
	END
