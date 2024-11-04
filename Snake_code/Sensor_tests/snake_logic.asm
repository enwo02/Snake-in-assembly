/*
 * snake_logic.asm
 *
 *  Created: 03/05/2022 20:30:20
 *   Author: Elio Wanner and Axel Barbelanne
 */ 

game_over:
	ldi zl,low(0x0400)
	ldi zh,high(0x0400)
	ldi a0, 64

game_over_loop:
	load_led_value_i 10,0,0		;show red screen to show failure (R=10)
	dec		a0
	brne	game_over_loop
	ldi		zl,low(0x0400)
	ldi		zh,high(0x0400)
	rcall	show_on_matrix		;actually load red pixels on matrix
	sbr		a3, (1 << 4)

	ret

;SUBROUTINES---------------------------------------------------------------------

;set all LEDs to OFF
reset_all_LEDs:
	ldi		zl,low(0x0400)		;Where display starts
	ldi		zh,high(0x0400)
	ldi		a0, 192				;3*64 (3 colours, 64 pixels)
reset_ram_internal:
	ldi		w, 0x00				;write a 0 to turn LED off
	st		z+,w
	dec		a0
	brne	reset_ram_internal	;loop until all off
	ldi		zl,low(0x0400)		;reset z to display start
	ldi		zh,high(0x0400)
ret

;show what is stored in the SRAM at 0x0400 + 64
show_on_matrix:
	ldi		zl,low(0x0400)
	ldi		zh,high(0x0400)
	_LDI	r0,64
show_on_matrix_loop:
	ld		a0, z+		;load values into a0,a1,a2 
	ld		a1, z+		;because that is what the matrix driver will output
	ld		a2, z+

	cli
	rcall	ws2812b4_byte3wr	;output the values to display
	sei

	dec		r0
	brne	show_on_matrix_loop
	ldi		zl,low(0x0400)		;reset z pointer
	ldi		zh,high(0x0400)
ret

;Shows the length of the snake (score) on the LCD
showScore:
	loadSnakeLength			;b3=snake length

	ldi		xl, low(200)
	ldi		xh, high(200)
	clr		a0
	rcall	eeprom_load			;loads highscore to a0

	cp		a0, b3				
	brsh	showScore_showNow	;if lower --> don't change highscores
	mov		a0, b3
	ldi		xl, low(200)
	ldi		xh, high(200)
	rcall	eeprom_store		;store new highscore in eeprom
	
showScore_showNow:
	rcall	LCD_clear		;Clear LCD display
	rcall	LCD_home
	PRINTF	LCD				;call display
	.db		"Score=",FDEC,b+3, LF,"Highscore=",FDEC, a ,0	;Show Score on the first line and highscore on the second line
	
ret

;This sets the SnakeUnit in SRAM to 0xff
setupSnake:
	ldi	xl,low(0x04C2)		;where Snake starts
	ldi	xh,high(0x04C2)
	ldi a0, 64
setupSnake_internal:
	ldi	w, 0xff				;set ram in SnakeUnit to 0xff (to indicate the absence of a snake part)
	st	x+, w
	dec a0
	brne setupSnake_internal

	;INITIAL SNAKE
	ldi	xl,low(0x04C2)		;where Snake is
	ldi	xh,high(0x04C2)
	ldi	w, 0x23				;initial length = 3 at the positions 0x23, 0x24, 0x25
	st	x+, w
	ldi	w, 0x24
	st	x+, w
	ldi	w, 0x25
	st	x+, w

	ldi		b0, 0			;initial direction
ret

setupApple:
	ldi	xl,low(0x04C1)		;where Snake is
	ldi	xh,high(0x04C1)
	ldi	w, 0x20				;first apple location
	st	x+, w
ret

;Loads snake from snake storage in SRAM into the display (also in SRAM)
;z points to the place where it will be stored
;x points to the original place of the snake
loadSnakeToDisplay:
	ldi		zl,low(0x0400)		;where Display is
	ldi		zh,high(0x0400)

	ldi		xl,low(0x04C2)		;where Snake is
	ldi		xh,high(0x04C2)

	rcall	reset_all_LEDs		;first reset display to all OFF
	ldi		a0,0				;define head colour (G=40)
	ldi		a1,40
	ldi		a2,0
loopThroughSnake:
	ld		w, x+

	ldi		zl,low(0x0400)		;where Display is
	ldi		zh,high(0x0400)
	
	;add thrice, because for each colour
	ADDZ	w
	ADDZ	w
	ADDZ	w

	load_led_value a0,a1,a2		;COLOUR OF THE SNAKE

	tst		a1					;Stop colour change if fully blue
	breq	PC+3
	subi	a1, 5				;Gradually change colour to blue
	ADDI	a2, 5

	ld		w, x
	cpi		w, 0xff				;if 0xff is found that means the snake is fully displayed
	brne	loopThroughSnake
ret

loadAppleToDisplay:
	ldi		zl,low(0x0400)		;where Display is
	ldi		zh,high(0x0400)

	ldi		xl,low(0x04C1)		;where Apple is
	ldi		xh,high(0x04C1)

	ldi		a0,50				;Apple Colour
	ldi		a1,0
	ldi		a2,0
	ld		w, x+
	ADDZ	w
	ADDZ	w
	ADDZ	w
	load_led_value a0,a1,a2
ret

;	-Advances snake into the direction of the directionByte
;	-Checks for self eating
;	-Loops the head around if snake surpassing field limit
autoAdvanceSnake:
	ldi		zl,low(0x0400)		;where Display is
	ldi		zh,high(0x0400)

	ldi		xl,low(0x04C2)		;where Snake is
	ldi		xh,high(0x04C2)

	ldi		yl, low(0x04C1)		;where Apple is
	ldi		yh, high(0x04C1)

	;load new head
	ld		a0, x					;store current head position in a0
	findNewHeadPosition		a0, b0	;calculate new head position and put in w

	ldi		xl,low(0x04C2)			;reset because checkSelfEating modifies it
	ldi		xh,high(0x04C2)
	ld		a2, y					;get apple position
	cp		w, a2					;see if new head on apple
	brne	PC+3					;if on apple
	ldi		a2, 1					;	a2=1
	rjmp	PC+2
	ldi		a2,0					;else: a2=0
	st		x+, w					;	add new head

autoAdvanceSnake_movingInternal:	;Shifts the snake in the memory
	ld		a1, x
	st		x+,a0
	cpi		a1, 0xff
	breq	autoAdvanceSnake_endMove

	ld		a0, x
	st		x+, a1
	cpi		a0, 0xff
	breq	autoAdvanceSnake_endMove

	rjmp	autoAdvanceSnake_movingInternal
autoAdvanceSnake_endMove:
	cpi		a2, 1		;if on apple, don't remove tail (meaning snake gets longer)
	breq	autoAdvance_setNewApple
	ldi		w, 0xff
	st		-x, w		;removing tail
	rjmp	autoAdvance_dontSetNewApple		;only setNewApple when one is eaten
autoAdvance_setNewApple:
	ld		w, -x
	ldi		xl,low(0x04C1)		;where apple is stored
	ldi		xh,high(0x04C1)
	add		w, b0				;Do some pseudo random operations to randomize new apple position
	subi	w, -10
	cpi		w, 63
	brlo	PC+2				;check if apple is in range (not exceeding the display) --> jump
	ldi		w, 2				;if out of bounds set apple to position 2
	st		x, w
autoAdvance_dontSetNewApple:

checkSelfEating					;check if the snake is eating itself --> game over
ret

