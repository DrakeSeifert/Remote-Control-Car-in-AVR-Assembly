;
;Lab8 RECEIVE CODE --> used Lab6 as a base
;
;***********************************************************

.include "m128def.inc"				; Include definition file

;************************************************************
;* Variable and Constant Declarations
;************************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	waitcnt = r17			; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter
.def	databuffer = r20

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

;============================================================
; NOTE: Let me explain what the macros above are doing.  
; Every macro is executing in the pre-compiler stage before
; the rest of the code is compiled.  The macros used are
; left shift bits (<<) and logical or (|).  Here is how it 
; works:
;	Step 1.  .equ	MovFwd = (1<<EngDirR|1<<EngDirL)
;	Step 2.		substitute constants
;			 .equ	MovFwd = (1<<5|1<<6)
;	Step 3.		calculate shifts
;			 .equ	MovFwd = (b00100000|b01000000)
;	Step 4.		calculate logical or
;			 .equ	MovFwd = b01100000
; Thus MovFwd has a constant value of b01100000 or $60 and any
; instance of MovFwd within the code will be replaced with $60
; before the code is compiled.  So why did I do it this way 
; instead of explicitly specifying MovFwd = $60?  Because, if 
; I wanted to put the Left and Right Direction Bits on different 
; pin allocations, all I have to do is change thier individual 
; constants, instead of recalculating the new command and 
; everything else just falls in place.
;==============================================================

;**************************************************************
;* Beginning of code segment
;**************************************************************
.cseg

;--------------------------------------------------------------
; Interrupt Vectors
;--------------------------------------------------------------
.org	$0000				; Reset and Power On Interrupt
		rjmp	INIT		; Jump to program initialization
.org	$0002				; initialize interrupt vector for left hit
		rcall HitRight
		reti
.org	$0004				; initialize interrupt vector for left hit
		rcall HitLeft
		reti
.org	$003C
		rcall ReceiveData
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

	;Set Port D pin 2 (RXD0) for input and pin 3 (TXD0) for output
		ldi		mpr, 0b00001000
		out		DDRD, mpr
	;Enable bumpbot behavior
		ldi		mpr, 0b00000011
		out		PORTD, mpr

	;Initialize USART1
		ldi		mpr, (1<<U2X1)	; Set double data rate
		sts		UCSR1A, mpr

	;Set baud rate at 2400
		ldi		mpr, high(832)
		sts		UBRR1H, mpr
		ldi		mpr, low(832)
		sts		UBRR1L, mpr

	;Set frame format: 8-bit data, 2 stop bits, asynchronous
		ldi mpr, (0<<UMSEL1 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10)
		sts UCSR1C, mpr ; UCSR1C in extended I/O space

	; Enable both receiver and transmitter, and receive interrupt
		ldi mpr, (1<<RXEN1 | 1<<TXEN1 | 1<<RXCIE1)
		sts UCSR1B, mpr

		

	; Bumper Behavior
	; Initialize external interrupts
		ldi mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)
		sts EICRA, mpr
	; Set ext. interrupt mask
		ldi mpr, (1<<INT0)|(1<<INT1)
		out EIMSK, mpr
	; turn on interrupts
		sei

	; Initialize TekBot Forward Movement
		ldi		mpr, MovFwd		; Load Move Forward Command
		out		PORTB, mpr		; Send command to motors

;---------------------------------------------------------------
; Main Program
;---------------------------------------------------------------
MAIN:
		
		rjmp	MAIN			; Continue with program
;****************************************************************
;* Subroutines and Functions
;****************************************************************

;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
HitRight:
		push	mpr			; Save mpr register
		push	waitcnt		; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr

		; disable interrupts
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the left whisker
;		is triggered.
;----------------------------------------------------------------
HitLeft:
		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr

		;disable interrupts
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine

;Function to interpret receive data from remote
ReceiveData:

		;Save byte, check for next byte in some sort of buffer (check homework for deetz)

		lds			databuffer, UDR1	; Read data from Receive Data Buffer

		ldi			mpr, $FF
		out			PORTB, mpr

		reti

		;Check that data is address --> check most significant bit?
		;If bit7 == 0 --> verify correct address, check buffer? wait for interrupt again?
		;else if bit7 == 1 --> perform the following commands:

		;verify correct address
		ldi			mpr, 0b01010101		;Special pre-defined address
		cp			databuffer, mpr
		brne		ExitInterrupt

		;Decide which Action Code to use
		ldi			mpr, 0b10110000 ;Move Forward
		cp			databuffer, mpr
		breq		MoveForward

		ldi			mpr, 0b10000000 ;Move Backward
		cp			databuffer, mpr
		breq		MoveBackward
	
		ldi			mpr, 0b10100000 ;Turn Right
		cp			databuffer, mpr
		breq		TurnRight

		ldi			mpr, 0b10010000 ;Turn Left
		cp			databuffer, mpr
		breq		TurnLeft

		ldi			mpr, 0b11001000 ;Halt
		cp			databuffer, mpr
		breq		HaltInterrupt

		ldi			mpr, 0b11111000 ;Future Use
		cp			databuffer, mpr
		breq		FutureUse

		reti		;Return if no matches occur

ExitInterrupt:
		reti

MoveForward:
		ldi		mpr, MovFwd	; Load Move Forward command
		out		PORTB, mpr	; Send command to port

		;Clear interrupt queue
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		reti

MoveBackward:
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port

		;Clear interrupt queue
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		reti

TurnRight:
		ldi		mpr, TurnR	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port

		;Clear interrupt queue
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		reti

TurnLeft:
		ldi		mpr, TurnL	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port

		;Clear interrupt queue
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		reti

HaltInterrupt:
		ldi		mpr, HALT
		out		PORTB, mpr

		;Clear interrupt queue
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		reti

FutureUse:
		;Clear interrupt queue
		cli
		ldi mpr, 0b11111111
		out EIFR, mpr

		reti