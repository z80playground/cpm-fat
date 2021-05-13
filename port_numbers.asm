; port_numbers.asm

; Here are the port numbers for various UART registers:
uart_tx_rx 		equ    	8
uart_IER 		equ    	9
uart_ISR 		equ     10           ; Also known as FCR
uart_LCR 		equ     11
uart_MCR 		equ     12           ; modem control reg
uart_LSR 		equ     13
uart_MSR 		equ     14
uart_scratch 	equ     15
