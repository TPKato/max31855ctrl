;;; regsters:
;;; r15, r14, r13, r12: decoded 7-Segment data for each digit
;;; SSEG_OFFSET	 (r11): digit (0-3)
;;; SSEG_SEL	 (r10): select digit (0001, 0010, 0100, 1000) (= 1 << SSEG_OFFSET)

#define	SSEG_DOT	0x40
#define	SSEG_MINUS	0x01

#define	SSEG_CHAR_MINUS	10
#define	SSEG_CHAR_OFF	11
#define	SSEG_CHAR_E	12
#define	SSEG_CHAR_R	13

#ifdef __GNUC__

#include <avr/io.h>

#define	high(x)	hi8(x)
#define	low(x)	lo8(x)

.global SSEG_INIT
.global SSEG_SET_TCTEMP
.global SSEG_UPDATE
.global SSEG_DISP_ERROR
.global TIMER0_OVF_vect

#define SSEG_SEL	r10
#define SSEG_OFFSET	r11

#else

;; for AVRA
.def	SSEG_SEL	= r10	; (1<<SSEG_OFFSET)
.def	SSEG_OFFSET	= r11

#endif

SSEG_INIT:
	;; PB0-7: segment
	;; PC0-3: segselect

	;; set port B as output
	ldi	r16, 0xff
	out	DDRB, r16
	;; off all segments
	out	PORTB, r16

	;; set PC0-PC3 as output
	in	r16, DDRC
	ori	r16, 0x0f
	out	DDRC, r16
	;; off all digits
	in	r16, PORTC
	ori	r16, 0x0f
	out	PORTC, r16

	;; registers
	clr	SSEG_SEL
	inc	SSEG_SEL	; ldi SSEG_SEL, 0x01
	clr	SSEG_OFFSET
	ret

;;; r25:r24: temperature data in 14 bit format
SSEG_SET_TCTEMP:
	push	r26
	push	r25
	push	r24
	push	r23
	push	r22

	clr	r22

	;; check if negative
	sbrs	r25, 5
	rjmp	_SSEG_SET_TCTEMP1

	;; if negative
	;; 2's complement of r25:r24
	ori	r25, 0xc0
	com	r25
	com	r24
	adiw	r24, 1

	ldi	r22, 0xff	; flag as negative

_SSEG_SET_TCTEMP1:
	push	r22		; save if negative

	clr	r22

	asr	r25
	ror	r24
	ror	r22
	asr	r25
	ror	r24
	ror	r22
	rcall	BIN2BCD16

	push	r24
	mov	r24, r22
	rcall	FRAC2BCD
	mov	r22, r25
	pop	r24

	pop	r25		; r25 <- negative flag

	tst	r25
	breq	_SSEG_SET_TCTEMP2

	;; add minus sign if negative
	tst	r24		; |T| < 100 ?
	brne	_SSEG_TCTEMP_NEG1
	cpi	r23, 0x10	; |T| < 10 ?
	brcc	_SSEG_TCTEMP_NEG2
	ori	r23, (SSEG_CHAR_MINUS<<4)
	rjmp	_SSEG_SET_TCTEMP2

_SSEG_TCTEMP_NEG2:
	ori	r24, SSEG_CHAR_MINUS
	rjmp	_SSEG_SET_TCTEMP2

_SSEG_TCTEMP_NEG1:
	ori	r24, (SSEG_CHAR_MINUS<<4)

_SSEG_SET_TCTEMP2:
	;; save the position of the decimal point
	;; (0th digit if r25 = 0, otherwise 1st digit)
	clr	r25
	cpi	r24, 0x10
	brcc	_SSEG_TCTEMP_BCD2SEG
	ldi	r25, 0xff

_SSEG_TCTEMP_SHIFT_NIBBLE:
	;; shift nibbles
	swap	r24
	andi	r24, 0xf0
	swap	r23
	push	r23
	andi	r23, 0x0f
	add	r24, r23
	pop	r23
	andi	r23, 0xf0
	swap	r22
	andi	r22, 0x0f
	add	r23, r22

_SSEG_TCTEMP_BCD2SEG:
	;; remove preceding 0s
	cpi	r24, 0x10
	brcc	_SSEG_TCTEMP_BCD2SEG2
	ori	r24, (SSEG_CHAR_OFF<<4)
	push	r24
	andi	r24, 0x0f
	tst	r24
	pop	r24
	brne	_SSEG_TCTEMP_BCD2SEG2
	ori	r24, SSEG_CHAR_OFF

_SSEG_TCTEMP_BCD2SEG2:
	push	r24
	rcall	SSEG_LOAD_SEGDATA_H
	mov	r15, r24
	pop	r24
	rcall	SSEG_LOAD_SEGDATA
	mov	r14, r24

	mov	r24, r23
	rcall	SSEG_LOAD_SEGDATA_H

	tst	r25
	ldi	r25, ~SSEG_DOT	; common anode
	breq	_SSEG_TCTEMP_BCD2SEG3
	andi	r24, ~SSEG_DOT	; common anode
	ldi	r25, 0xff	; common anode

_SSEG_TCTEMP_BCD2SEG3:
	mov	r13, r24
	mov	r24, r23
	rcall	SSEG_LOAD_SEGDATA
	and	r24, r25
	mov	r12, r24

_SSEG_SET_TCTEMP_EXIT:
	pop	r22
	pop	r23
	pop	r24
	pop	r25
	pop	r26

	ret

;;; ------------------------------------------------------------
;;; in: r24: data (0-9 (or 0-F)) in upper nibble
;;; out: r24: segdata
SSEG_LOAD_SEGDATA_H:
	swap	r24

;;; in: r24: data (0-9 (or 0-F)) in lower nibble
;;; out: r24: segdata
SSEG_LOAD_SEGDATA:
	andi	r24, 0x0f

	push	ZH
	push	ZL

	ldi	ZH, high(SEGMENTS)
	ldi	ZL, low (SEGMENTS)
#ifndef __GNUC__
	lsl	ZL
	rol	ZH
#endif

	push	r16
	clr	r16

	add	ZL, r24
	adc	ZH, r16

	lpm	r24, Z
	com	r24		; common anode

	pop	r16
	pop	ZL
	pop	ZH
	ret

;;; in: r24: error code to display (0-9)
SSEG_DISP_ERROR:
	push	r24
	ldi	r24, SSEG_CHAR_E
	rcall	SSEG_LOAD_SEGDATA
	mov	r15, r24
	ldi	r24, SSEG_CHAR_R
	rcall	SSEG_LOAD_SEGDATA
	mov	r14, r24
	mov	r13, r24
	pop	r24
	push	r24
	rcall	SSEG_LOAD_SEGDATA
	mov	r12, r24
	pop	r24
	ret

;;; ------------------------------------------------------------
;;; interrupt handler

TIMER0_OVF_vect:
SSEG_UPDATE:
	push	r16

	in	r16, SREG
	push	r16

	;; turn off all LEDs
	ldi	r16, 0xff	; common anode
	out	PORTB, r16

	push	XL
	push	XH

	clr	XH
	ldi	XL, 12		; r12
	add	XL, SSEG_OFFSET

	;; select digit
	;; (common anode)
	in	r16, PORTC
	com	r16
	andi	r16, 0xf0
	or	r16, SSEG_SEL
	com	r16
	out	PORTC, r16

	;; segment data
	ld	r16, X
	out	PORTB, r16

	;; increment
	inc	SSEG_OFFSET
	lsl	SSEG_SEL

	;; cpi	SSEG_SEL, 0x10	; 4 digits
	;; brne	_SSEG_UPDATE_EXIT
	brhc	_SSEG_UPDATE_EXIT

	clr	SSEG_SEL
	inc	SSEG_SEL	; ldi SSEG_SEL, 0x01
	clr	SSEG_OFFSET

_SSEG_UPDATE_EXIT:
	pop	XH
	pop	XL
	pop	r16
	out	SREG, r16
	pop	r16

	reti

;;; ------------------------------------------------------------
SEGMENTS:
#ifdef __GNUC__
	.byte	0xbe, 0x12, 0x9d, 0x1f, 0x33, 0x2f, 0xaf, 0x1a, 0xbf, 0x3f, 0x01, 0x00, 0xad, 0x81
#else
	.db	0xbe, 0x12, 0x9d, 0x1f, 0x33, 0x2f, 0xaf, 0x1a, 0xbf, 0x3f, 0x01, 0x00, 0xad, 0x81
		;; 0,	 1,    2,    3,	   4,	 5,    6,    7,	   8,	 9,    -,  off,	   E,	 r
#endif


;;; ============================================================
;;; Test of 7-segment
;;; (infinite loop)

#ifdef SSEG_DEBUG
.global SSEG_TEST

SSEG_TEST:
;;; test 1
;;; 0.0.0.0. -> 1.1.1.1. -> ... -> 9.9.9.9.
SSEG_TEST1:
	clr	r16

_SSEG_TEST1_LOOP:
	mov	r24, r16
	rcall	SSEG_LOAD_SEGDATA
	andi	r24, ~SSEG_DOT	; common anode
	mov	r15, r24
	mov	r14, r24
	mov	r13, r24
	mov	r12, r24

	;; wait 500 ms
	ldi	r24, 250
	rcall	Waitms
	rcall	Waitms

	inc	r16
	cpi	r16, 10
	brne	_SSEG_TEST1_LOOP

;;; test 2
;;; 0123 -> 1234 -> ... -> 9012
SSEG_TEST2:
	clr	r17

_SSEG_TEST2_LOOP:
	mov	r16, r17

	clr	XH
	ldi	XL, 16		; r(15+1)

_SSEG_TEST2_DIGIT:
	mov	r24, r16
	rcall	SSEG_LOAD_SEGDATA
	st	-X, r24
	cpi	XL, 12
	breq	_SSEG_TEST2_NEXT

	;; r16++ (mod 10)
	inc	r16
	cpi	r16, 10
	brne	_SSEG_TEST2_DIGIT

	ldi	r16, 0
	rjmp	_SSEG_TEST2_DIGIT

_SSEG_TEST2_NEXT:
	;; wait 500 ms
	ldi	r24, 250
	rcall	Waitms
	rcall	Waitms

	inc	r17
	cpi	r17, 10
	brne	_SSEG_TEST2_LOOP

	rjmp	SSEG_TEST
#endif
