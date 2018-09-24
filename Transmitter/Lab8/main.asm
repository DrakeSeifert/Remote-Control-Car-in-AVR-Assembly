;
; lab 8 transmitter code
;
; Created: 3/1/2017 5:08:10 PM
; Author : Brock
;



;***********************************************************

.include "m128def.inc"				; Include definition file

;************************************************************
;* Variable and Constant Declarations
;************************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	waitcnt = r17				; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter
.def	buff = r20				; data output buffer

.equ	WTime = 100				; Time to wait in wait loop

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	MovBck = $00				; Move Backward Command
.equ	TurnR = (1<<EngDirL)			; Turn Right Command
.equ	TurnL = (1<<EngDirR)			; Turn Left Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command


;/////////////////////////////////////////////////////////////
; Macros for commands to send
;/////////////////////////////////////////////////////////////

.equ	CmdFwd =	0b10110000
.equ	CmdBck =	0b10000000
.equ	CmdRight =	0b10100000
.equ	CmdLeft =	0b10010000
.equ	CmdHalt =	0b11001000
.equ	CmdFrz =	0b11111000
.equ	CmdGetFrz = 0b01010101
.equ	Address =	30
;.equ	Address =	42

;**************************************************************
;* Beginning of code segment
;**************************************************************
.cseg

;--------------------------------------------------------------
; Interrupt Vectors
;--------------------------------------------------------------
.org	$0000				; Reset and Power On Interrupt
		rjmp	INIT		; Jump to program initialization
.org	$0040				; USART0 transmit complete vector
		rcall TransmitComplete
		reti
.org	$0046				; End of Interrupt Vectors

;--------------------------------------------------------------
; Program Initialization
;--------------------------------------------------------------
INIT:
    ; Initialize the Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

    ; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low		

	; Initialize Port D for I/O
		ldi		mpr, 0b00001000	; Set Port D Data Direction Register
		out		DDRD, mpr		; input for buttons; output for UART
		ldi		mpr, 0b11110011	; Initialize Port D Data Register
		out		PORTD, mpr		; 


	; Initialize USART1
		ldi mpr, (1<<U2X1)		; Set double data rate
		sts UCSR1A, mpr

	; Set data frame format
		ldi mpr, (0<<UMSEL1 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10 | 1<<UPM11 | 1<<UPM10)
		sts UCSR1C, mpr

	; Enable transmitter interrupt
		ldi mpr, (1<<TXEN1|1<<TXCIE1)
		sts UCSR1B, mpr
		
	; set baud rate to 2400
		ldi		mpr, high(832)
		sts		UBRR1H, mpr
		ldi		mpr, low(832)
		sts		UBRR1L, mpr

	; turn on interrupts
		sei

;---------------------------------------------------------------
; Main Program
;---------------------------------------------------------------
MAIN:
		in mpr, PIND		; get button states
		; check (hi-state) button presses (buttons 7-4)
		cpi mpr, 0b01111111		
		breq SendBackward
		
		cpi mpr, 0b10111111
		breq SendLeft
		
		cpi mpr, 0b11011111
		breq SendRight

		cpi mpr, 0b11101111
		breq SendForward
		
		cpi mpr, 0b11111101
		breq SendHalt
		
		cpi mpr, 0b11111110
		breq SendFreeze
		
		rjmp	MAIN			; Continue with program
;****************************************************************
;* Subroutines and Functions
;****************************************************************

USART_Transmit:
	; wait for data buffer empty
	ldi ZH, high(UCSR1A)	; get value of UCSR1A (byte) to retrieve UDRE1 (bit) from it
	ldi ZL, low(UCSR1A)		; ^
	lpm mpr, Z				; ^
	sbrs mpr, UDRE1			; check for UDR-empty bit (UDRE1)
	rjmp USART_Transmit		; loop until empty; skip this if UDRE set
	ldi mpr, Address
	sts UDR1, mpr			; transmit address
	TRANSMIT_2:
	; wait for data buffer empty again
	ldi ZH, high(UCSR1A)
	ldi ZL, low(UCSR1A)
	lpm mpr, Z
	sbrs mpr, UDRE1			; check for UDR-empty bit (UDRE1)
	rjmp TRANSMIT_2
	sts UDR1, buff			; move data from our buff to transmit data buffer (UDR)
	ret

SendForward:
		ldi mpr, CmdFwd
		out PORTB, mpr

		ldi buff, CmdFwd	; load our command into command buffer 'buff'
		rcall USART_Transmit

		rjmp MAIN

SendBackward:
		ldi mpr, CmdBck
		out PORTB, mpr
		
		ldi buff, CmdBck
		rcall USART_Transmit

		rjmp MAIN

SendLeft:
		ldi mpr, CmdLeft
		out PORTB, mpr

		ldi buff, CmdLeft
		rcall USART_Transmit

		rjmp MAIN

SendRight:
		ldi mpr, CmdRight
		out PORTB, mpr

		ldi buff, CmdRight
		rcall USART_Transmit

		rjmp MAIN

SendHalt:
		ldi mpr, CmdHalt
		out PORTB, mpr

		ldi buff, CmdHalt
		rcall USART_Transmit

		rjmp MAIN

SendFreeze:
		ldi mpr, CmdFrz
		out PORTB, mpr

		ldi buff, CmdFrz
		rcall USART_Transmit

		rjmp MAIN

TransmitComplete:
		out PORTB, buff		; write command to LEDs

		ret
