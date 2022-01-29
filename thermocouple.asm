#ifdef __GNUC__

#include <avr/io.h>
.section .text

.global main

#define low(x)	lo8(x)
#define high(x)	hi8(x)

#else
.include	"devicedef.inc"

	;; interupt vectors (ATmega328)
	jmp	RESET
	jmp	RET_INTR		;jmp	INT0
	jmp	RET_INTR		;jmp	INT1
	jmp	RET_INTR		;jmp	PCINT0
	jmp	RET_INTR		;jmp	PCINT1
	jmp	RET_INTR		;jmp	PCINT2
	jmp	RET_INTR		;jmp	WDT
	jmp	RET_INTR		;jmp	TIMER2_COMPA
	jmp	RET_INTR		;jmp	TIMER2_COMPB
	jmp	RET_INTR		;jmp	TIMER2_OVF
	jmp	RET_INTR		;jmp	TIMER1_CAPT
	jmp	RET_INTR		;jmp	TIMER1_COMPA
	jmp	RET_INTR		;jmp	TIMER1_COMPB
	jmp	RET_INTR		;jmp	TIMER1_OVF
	jmp	RET_INTR		;jmp	TIMER0_COMPA
	jmp	RET_INTR		;jmp	TIMER0_COMPB

#ifdef USE_SSEG
	jmp	TIMER0_OVF_vect		;jmp	TIMER0_OVF
#else
	jmp	RET_INTR
#endif

	jmp	RET_INTR		;jmp	SPI_STC
	jmp	RET_INTR		;jmp	USART_RX
	jmp	RET_INTR		;jmp	USART_UDRE
	jmp	RET_INTR		;jmp	USART_TX
	jmp	RET_INTR		;jmp	ADC
	jmp	RET_INTR		;jmp	EE_READY
	jmp	RET_INTR		;jmp	ANALOG_COMP
	jmp	RET_INTR		;jmp	TWI
	jmp	RET_INTR		;jmp	SPM_READY

RET_INTR:
	reti

RESET:
	;; set stack pointer
	ldi	r16, low(RAMEND)
	out	SPL, r16
	ldi	r16, high(RAMEND)
	out	SPH, r16
#endif


;;; ============================================================
main:

;;; Initialize
#ifdef USE_USART
	;; USART
	rcall	USART_INITIALIZE
	ldi	r25, high(STR_HELLO)
	ldi	r24, low (STR_HELLO)
	rcall	USART_PUTS
#endif

	;; MAX31855
	rcall	MAX31855_INIT_PORTS

#ifdef USE_SSEG
	;; 7-Segment
	rcall	SSEG_INIT

	;; Interrupt
	ldi	r16, (1<<CS01)
	out	TCCR0B, r16	; clk/8 prescaler
	ldi	r16, (1<<TOV0)
	out	TIFR0, r16	; clear TOV0 (clear pending interrupts)
	ldi	r16, (1<<TOIE0)
	sts	TIMSK0, r16	; enable Timer/Counter0 Overflow Interrupt

	sei
#endif

;;; ============================================================
;;; main routine

#ifdef USE_SSEG
#ifdef SSEG_DEBUG
	rjmp	SSEG_TEST
#endif
#endif

do_measure:
	rcall	MAX31855_READDATA

	;; error check
	push	r22
	andi	r22, 0x07
	pop	r22
	breq	_measure2
	rcall	READ_ERROR
	ldi	r24, 5
	rcall	Waitsec
	rjmp	do_measure

_measure2:
	;; thermocouple temperature
	rcall	MAX31855_FORMAT_TEMP

#ifdef USE_USART
	push	r25
	push	r24
	movw	r24, r22
	rcall	USART_INTTEMP_SHOW
	pop	r24
	pop	r25

	rcall	USART_TCTEMP_SHOW
#endif

#ifdef TC_CORRECTION
	cli
	rcall	correctedTemperature
	sei

	;; error check (out of range)
	cpi	r25, 0x80
	brne	_measure3

	rcall	CORRECTION_ERROR
	ldi	r24, 5
	rcall	Waitsec
	rjmp	do_measure

_measure3:
#ifdef USE_USART
	rcall	USART_CORRTEMP_SHOW
#endif
#endif

	;; output of result
#ifdef USE_SSEG
	rcall	SSEG_SET_TCTEMP
#endif

#ifdef USE_USART
	ldi	r24, 0x0d
	rcall	USART_TRANSMIT
	ldi	r24, 0x0a
	rcall	USART_TRANSMIT
#endif

	rcall	Wait1sec

	rjmp	do_measure

;;; ------------------------------------------------------------
;;; USART related

#ifdef USE_USART

USART_CORRTEMP_SHOW:
	push	r24
	ldi	r24, 'C'
	rcall	USART_TRANSMIT
	ldi	r24, 'o'
	rcall	USART_TRANSMIT
	ldi	r24, 'r'
	rcall	USART_TRANSMIT
	ldi	r24, ':'
	rcall	USART_TRANSMIT
	ldi	r24, ' '
	rcall	USART_TRANSMIT
	pop	r24

	rcall	MAX31855_USART_TCTEMP
	rcall	USART_CRLF
	ret

USART_TCTEMP_SHOW:
	push	r24
	ldi	r24, 'R'
	rcall	USART_TRANSMIT
	ldi	r24, 'a'
	rcall	USART_TRANSMIT
	ldi	r24, 'w'
	rcall	USART_TRANSMIT
	ldi	r24, ':'
	rcall	USART_TRANSMIT
	ldi	r24, ' '
	rcall	USART_TRANSMIT
	pop	r24

	rcall	MAX31855_USART_TCTEMP
	rcall	USART_CRLF
	ret

USART_INTTEMP_SHOW:
	push	r24
	ldi	r24, 'I'
	rcall	USART_TRANSMIT
	ldi	r24, 'n'
	rcall	USART_TRANSMIT
	ldi	r24, 't'
	rcall	USART_TRANSMIT
	ldi	r24, ':'
	rcall	USART_TRANSMIT
	ldi	r24, ' '
	rcall	USART_TRANSMIT
	pop	r24

	rcall	MAX31855_USART_INTTEMP
	rcall	USART_CRLF
	ret

USART_CRLF:
	push	r24
	ldi	r24, 0x0d
	rcall	USART_TRANSMIT
	ldi	r24, 0x0a
	rcall	USART_TRANSMIT
	pop	r24
	ret

#endif

;;; ------------------------------------------------------------
;;; Error

READ_ERROR:
	andi	r22, 0x07
#ifdef USE_SSEG
	mov	r24, r22
	rcall	SSEG_DISP_ERROR
#endif

#ifdef USE_USART
	ldi	r25, high(STR_READ_ERROR)
	ldi	r24, low (STR_READ_ERROR)
	rcall	USART_PUTS
	mov	r24, r22
	rcall	USART_PUTHEX
	ldi	r24, 0x0d
	rcall	USART_TRANSMIT
	ldi	r24, 0x0a
	rcall	USART_TRANSMIT
#endif

	ret

CORRECTION_ERROR:
#ifdef USE_SSEG
	ldi	r24, 0
	rcall	SSEG_DISP_ERROR
#endif

#ifdef USE_USART
	ldi	r25, high(STR_CORRECTION_ERROR)
	ldi	r24, low (STR_CORRECTION_ERROR)
	rcall	USART_PUTS
#endif

	ret

;;; ------------------------------------------------------------
#ifndef __GNUC__
#ifdef USE_USART
.include	"usart.asm"
.include	"usart-puts.asm"
.include	"usart-puthex.asm"
.include	"bin2ascii.asm"
#endif

.include	"devices/max31855.asm"

#ifdef USE_SSEG
.include	"ssegment.asm"
#endif

.include	"frac2bcd.asm"
.include	"bin2bcd16.asm"
.include	"wait.asm"
#endif

;;; ------------------------------------------------------------
STR_HELLO:
#ifdef __GNUC__
	;; note: The length of the string must be even.
	.asciz	"# Hallo MAX31855\r\n"
	.byte 0
#else
	.db	"# Hallo MAX31855", 0x0d, 0x0a, 0, 0
#endif

STR_READ_ERROR:
#ifdef __GNUC__
	.asciz	"Read Error "
	.byte 0
#else
	.db	"Read Error ", 0
#endif

STR_CORRECTION_ERROR:
#ifdef __GNUC__
	.asciz	"Correction: Out of range\r\n\r\n"
#else
	.db	"Correction: Out of range", 0x0d, 0x0a, 0x0d, 0x0a, 0, 0
#endif
