/*
 * input_drivers.asm
 *
 *  Created: 27/05/2022 16:53:24
 *   Author: Axelb
 */ 

 ; DISTANCE SENSOR

 measure:	

	sbi			ADCSR,ADSC			; AD start conversion
	
	in			d0,ADCL				; read low byte first
	in			d1,ADCH				; read high byte second

	cbr			a3,ADC_RDY_BIT		;Wait until next ADC data ready
	
	ret

 change_dir:
	sbi			PORTB,3
	sbi			PORTB,4
	sbi			PORTB,5
	sbi			PORTB,6
	sbi			PORTB,7
	mov			_w, b0
	
	CPI2		d1, d0, TOO_FAR_VAL		; straight as default
	brlo		led_4
	CPI2		d1, d0, TURN_L_VAL		; left turn
	brlo		led_3
	CPI2		d1, d0, TURN_R_VAL		; right turn
	brsh		led_5
	;show position on LED's
	led_4:
	cbi			PORTB,5
	rjmp		end_check
	led_5:
	cbi			PORTB,7
	cbi			PORTB,6
	ADDI		_w,1
	rjmp		end_check
	led_3:
	cbi			PORTB,3
	cbi			PORTB,4
	subi		_w, 1
	
	end_check:
	clr			b0
	ANDI		_w, 0b11
	add			b0, _w		;sets the new direction
	ret

; IR REMOTE

prep:	
	PUSH4		a0, a1, a2, a3
	PUSH4		d0, d1, d2, d3

	CLR2		a3,a2			; clear 2-byte register
	CLR2		a1,a0
	ldi			_w,16			; load bit-counter
	
addr: 
	P2C			PINE,IR			; move Pin to Carry (P2C, 4 cycles)
	ROL2		a3,a2			; roll carry into 2-byte reg (ROL2, 2 cycles)
	sbrc		a2,0			; (branch not taken, 1 cycle; taken 2 cycles)
	rjmp		rdz_a			; (rjmp, 2 cycles)
	WAIT_US		(T1 - 4.5)
	DJNZ		_w,addr			; Decrement and Jump if Not Zero (true, 2 cycles; false, 1 cycle)
	jmp			next_a			; (jmp, 3 cycles)

rdz_a:							; read a zero
	WAIT_US		(2*T1 - 5.5)
	DJNZ		_w,addr			; Decrement and Jump if Not Zero

next_a: 
	MOV2	d1,d0, a3, a2	; store current address
	MOV2		a1,a0,a3,a2
	ldi			_w,16			; load bit-counter
	clc
	CLR2	a3,a2

data: 
	P2C		PINE,IR			
	ROL2		a3,a2			
	sbrc		a2,0			
	rjmp		rdz_d			
	WAIT_US		(T1 - 4.5)
	DJNZ		_w,data			
	jmp			next_b	
			
rdz_d:	
	WAIT_US		(2*T1 - 5.5)
	DJNZ		_w,data				

next_b:
	MOV2		d3,d2,a3, a2	; store current command

data_proc01:					; detect repeated code
	_CPI			d3, 0xff
	brne		data_proc02
	_CPI			d2, 0xff
	brne		data_proc02
	_CPI			d1, 0xff 
	brne		data_proc02
	_CPI			d0, 0xff
	brne		data_proc02 

display_repeat:
	MOV4		a1,a0,a3,a2,c3,c2,c1,c0		; display the last correct code, i.e,
	rjmp		data_recover

data_proc02:								; detect transmission error
	com			d1
	cpse		d0, d1
	brne		data_recover
	com			d3
	cpse		d2, d3
	brne		data_recover

display_correct:	
	com			a2							; complement b0 (chip delivers the complement)
	com			a3
	com			a0
	com			a1
	CPI2		a1, a0, 0xff00			;check if correct address
	brne		end_display
	;check each direction value individually
	CPI2		a3, a2, 0x3dc2
	brne		PC+3
	ldi			b0, 0
	rjmp		store_correct
	CPI2		a3, a2, 0x9d62
	brne		PC+3
	ldi			b0, 1
	rjmp		store_correct
	CPI2		a3, a2, 0xdd22
	brne		PC+3
	ldi			b0, 2
	rjmp		store_correct
	CPI2		a3, a2, 0x57a8
	ldi			b0, 3
	store_correct:
	MOV4		c3,c2,c1,c0,a1,a0,a3,a2		; storing correct code to display/use in 
	end_display:
	rjmp		data_recover
	

data_recover:
	POP4		d0, d1, d2, d3
	POP4		a0, a1, a2, a3
	ret