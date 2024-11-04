/*
 * my_macros.asm
 *
 *  Created: 03/05/2022 20:59:05
 *   Author: eliow
 */

 ;Stores immediate RGB values into z register
 .macro load_led_value_i
	ldi	w, @1	; pixel 1 [GRB]
	st	z+,w
	ldi w, @0
	st	z+,w
	ldi	w, @2
	st z+,w
.endmacro

;Stores RGB values from register into z register
 .macro load_led_value
	st	z+,@1	; pixel 1 [GRB]
	st	z+,@0
	st	z+,@2
.endmacro

;finds position for new snake head from dirBits (@1) & current snake (@0)
;stores result in w
.macro findNewHeadPosition
	mov		w, @0	;copy current Head in w
	cpi		@1, 0	;see if direction = 0 --> plusX
	breq	plusX
	cpi		@1, 1	;see if direction = 1 --> plusY
	breq	plusY
	cpi		@1, 2	;see if direction = 2 --> minusX
	breq	minusX
	cpi		@1, 3	;see if direction = 3 --> minusY
	breq	m_minusY
	rjmp	error_case

m_minusY:
	jmp minusY

plusX:
	;move in +x
	dec		w		;when not on right border
	CPI8	w, 0xff,7,15,23,31,39,47,55
	brne	PC + 2
	ADDI	w, 8	;rewind when on the right border
	rjmp	finishHeadFinding
plusY:
	;move in +y
	ADDI	w, 8	;when not on top border
	CPI8	w, 64,65,66,67,68,69,70,71
	brne	PC + 2
	subi	w, 64	;rewind when on the top border
	rjmp	finishHeadFinding
minusX:
	;move in -x
	inc		w		;when not on left border
	CPI8	w, 8,16,24,32,40,48,56,64
	brne	PC + 2
	subi	w, 8	;rewind when on the left border
	rjmp	finishHeadFinding

minusY:
	;move in -y
	subi	w, 8	;when not on bottom border
	CPI8	w, 0xff,0xfe,0xfd,0xfc,0xfb,0xfa,0xf9,0xf8
	brne	PC + 2
	ADDI	w, 64	;rewind when on the bottom border
	rjmp	finishHeadFinding

error_case:
	;This should never happen (if dirBit >3)
finishHeadFinding:
	;yey the head is succesfully found :D
.endmacro

;checks if first value is equal to one of the following 8
.macro CPI8
	mov		a1, @0

	cpi		a1, @1
	breq	CPI8_end
	cpi		a1, @2
	breq	CPI8_end
	cpi		a1, @3
	breq	CPI8_end
	cpi		a1, @4
	breq	CPI8_end
	cpi		a1, @5
	breq	CPI8_end
	cpi		a1, @6
	breq	CPI8_end
	cpi		a1, @7
	breq	CPI8_end
	cpi		a1, @8
	breq	CPI8_end
CPI8_end:
	
.endmacro

.macro checkSelfEating
	ldi		xl,low(0x04C2)		;where Snake is
	ldi		xh,high(0x04C2)
	ld		w, x+				;load in head
checkSelfEating_loop:
	ld		a2, x+
	cp		w, a2
	breq	checkSelfEating_game_over	;if head somewhere where snake already is --> game over
	cpi		a2, 0xff
	brne	checkSelfEating_loop		;loop until 0xff found

	ldi		xl,low(0x04C2)				;reset x pointer
	ldi		xh,high(0x04C2)
	rjmp	checkSelfEating_end

checkSelfEating_game_over:
	rcall	game_over
checkSelfEating_end:
.endmacro

.macro loadSnakeLength
	ldi		xl,low(0x04C1)		;where Snake is
	ldi		xh,high(0x04C1)
	clr		b3					;set length to zero
loadSnakeLength_loop:
	ld		w, x+
	cpi		w, 0xff				;check if at end of snake
	breq	loadSnakeLength_end
	inc		b3					;add one for every snake part found
	rjmp	loadSnakeLength_loop
loadSnakeLength_end:
	dec		b3					;adjust, because it adds before checking
.endmacro

 .macro IFAND	; r1, b1, r2, b2  sets clear if ether bits are '0'
	sbrs		@0, @1
	sec
	sbrs		@2, @3
	sec
.endmacro

.macro CPI2		;cpi on 2 bytes
	push		_w
	ldi			w,high(@2)
	ldi			_w,low(@2)
	CP2			@0, @1, w, _w
	pop			_w
.endmacro

.macro INC_LIM10		;reg,lim	;incremente de 5 avec une limite
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
	INC_LIM		@0,@1
.endmacro

.macro DEC_LIM10		;reg,lim	;décremente de 5 avec une limite
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
	DEC_LIM		@0,@1
.endmacro