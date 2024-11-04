; file	main.asm   target ATmega128L-4MHz-STK300
; purpose timers 0,1,2 overflows	

.include "macros.asm"		; include macro definitions
.include "definitions.asm"	; include register/constant definitions

;note: b0: ir_ready // button_ready // data_ready // toggle_mode

; === interrupt vector table ===
.org	0
	rjmp		reset
.org			INT0addr		;reset button
	jmp			ext_int0
.org			INT1addr		;toggle button
	jmp			ext_int1		
.org			INT2addr		;speed up button
	jmp			ext_int2		
.org			INT3addr		;slow down button
	jmp			ext_int3		
.org			INT7addr		;IR remote interrupt
	jmp			ext_int7
.org			OC0addr			;snake turn timer
	rjmp		output_compare0
.org			OVF2addr		;measure timer
	rjmp		overflow2
.org 			ADCCaddr		;AC/DC converter
	rjmp		ADCCaddr_sra


.include "lcd.asm"
.include "printf.asm"
.include "my_macros.asm"
.include "matrix_driver.asm"
.include "input_drivers.asm"	;distance sensor and IR sensor drivers
.include "snake_logic.asm"		;game logic code
.include "eeprom.asm"

.equ	TOGGLE_BIT = 0			;mode toggle
.equ	ADC_RDY_BIT = 1		;ADC converter ready
.equ	BTN_RDY_BIT = 2		;toggle button ready
.equ	IR_RDY_BIT = 3			;IR sensor ready
.equ	GO_STATE = 4			;game over state
.equ	SPD_RDY_BIT = 5		;speed buttons ready

.equ	TURN_R_VAL = 0x0320
.equ	TURN_L_VAL = 0x0190
.equ	TOO_FAR_VAL = 0x0070	;value too far => ignored
.equ	DIST_PRESC = 3			
.equ	DEF_SNAKE_TIMER = 200	; 1 => 7.8ms
.equ	HIGH_SPD_LIM = 50
.equ	LOW_SPD_LIM = 244

;delay times for IR protocol
.equ	T2 = 15532		
.equ	T1 = 1180

; === interrupt service routines ====
ext_int0:	;reset
	cbr			a3, (1 << GO_STATE)	;clear game over
	rcall		setupSnake
	rcall		setupApple
	ldi			b1,DEF_SNAKE_TIMER	;set default speed
	out			OCR0,b1	
	reti

ext_int1:	;toggle mode (IR sensor/distance sensor)
	sbrs		a3,BTN_RDY_BIT			;debounce (check if button is ready)
	rjmp		ext_int1_end
	cbr			a3,(1 << BTN_RDY_BIT)	;button not ready until small delay
	_EORI		a3, (1 << TOGGLE_BIT)	;invert toggle pin
	in			_w, EIMSK				;toggle IR sensor interrupt
	_EORI		_w, 0x80
	out			EIMSK, _w
	INVP		PORTB, 0				;toggle mode LED
	ext_int1_end:
	reti

ext_int2:	;slow down snake
	sbrs		a3,SPD_RDY_BIT			;debounce (check if button is ready)
	rjmp		ext_int2_end
	cbr			a3,(1 << SPD_RDY_BIT)	;button not ready until small delay
	INC_LIM10	b1, LOW_SPD_LIM			;increase by 10 with a limit (slow down snake)
	out			OCR0,b1
	ext_int2_end:
	reti

ext_int3:	;speed up snake
	sbrs		a3,SPD_RDY_BIT		;debounce (check if button is ready)
	rjmp		ext_int3_end
	cbr			a3,(1 << SPD_RDY_BIT)		;button not ready until small delay
	DEC_LIM10	b1, HIGH_SPD_LIM			;decrease by 10 with a limit (speed up snake)
	out			OCR0,b1
	ext_int3_end:
	reti

ext_int7:	;IR sensor
	sbrs		a3,IR_RDY_BIT
	rjmp		end_interrupt
	cbr			a3, (1 << IR_RDY_BIT)
	WAIT_US		T2				; wait for timeout
	clc							; clearing carry
	rcall		prep
	cbi			PORTB,2			;indicate received code
	end_interrupt:
	reti

overflow2:	;counter for distance sensor measurement
	sbrc		a3, GO_STATE
	rjmp		after_measure
	sbrs		a3, TOGGLE_BIT		;check toggle mode before measurement
	rcall		measure
	after_measure:	
	sbr			a3, (1 << SPD_RDY_BIT)	;make speed changing buttons available again
	reti

output_compare0:	;counter for snake turns
	sbrc		a3, GO_STATE		;check game over state, skip if true
	rjmp		output_compare0_end
	sbrs		a3, TOGGLE_BIT		;check toggle
	rcall		change_dir
	sbrc		a3, TOGGLE_BIT
	sbi			PORTB,2
	rcall		autoAdvanceSnake		;move snake
	rcall		loadSnakeToDisplay		;display snake
	rcall		loadAppleToDisplay		;display apple
	sbrc		a3, GO_STATE			
	rjmp		output_compare0_end		;end if game over
	rcall		show_on_matrix			;shows Display in SRAM to hardware
	rcall		ws2812b4_reset			;resets hardware-display
	rcall		showScore				;show score on LCD screen
	sbr			a3,(1 << BTN_RDY_BIT)	;Make buttons available again
	sbr			a3, (1 << IR_RDY_BIT)
	output_compare0_end:
	reti
	

ADCCaddr_sra:
	sbr			a3,(1 << ADC_RDY_BIT)	;ADC data ready
	reti								

; === initialisation (reset) ===	
reset: 
	LDSP		RAMEND			; load stack pointer (SP)
	OUTI		PORTB,0xff		; turn LEDs off
	OUTI		DDRB,0xff		; LED's:output
	OUTI		DDRE,0x7f		; IR sensor input, ADC output
	OUTI		DDRA, 0xff		;used by LCD
	OUTI		DDRC, 0xff		;used by LCD
	OUTI		DDRD, 0b11110000;configure first two pins as inputs (for interrupt)
								;pin7 is used for matrix LED
	OUTI		EIMSK, 0x8f		;allow all interrupts at startup
	ldi			w, 0b10101010
	sts			EICRA, w		;detect on falling edge
	ldi			w, 0b11000000
	sts			EICRB, w		;detect on rising edge

	OUTI		ASSR, (1<<AS0)	; clock from TOSC1
	OUTI		TCCR2,5			; set prescaler
	
	OUTI		TCCR0,(1<<CTC0)+5	;clear on compare
	ldi			b1, DEF_SNAKE_TIMER
	out			OCR0,b1				;set snake speed
	OUTI		TIMSK,(1<<TOIE2) + (1<<OCIE0)
	
	OUTI		ADCSR,(1<<ADEN)+(1<<ADIE)+6 ; AD Enable, AD int. enable, PS=CK/64	
	OUTI		ADMUX,3						; select channel POT
	cbr			a3,ADC_RDY_BIT	
	cbr			a3, (1 << GO_STATE)			;remomve game over state
	sbr			a3, (1 << IR_RDY_BIT)		;make button available
	sbr			a3,(1 << TOGGLE_BIT)		;default: remote

	rcall		LCD_init			; initialize the LCD
	rcall		ws2812b4_init
	rcall		setupSnake
	rcall		setupApple

	ldi		xl, low(200)		;initializing highscore
	ldi		xh, high(200)
	rcall	eeprom_load
	cpi		a0, 0xff			;on first boot up eeprom is 0xff, so need to clear it
	brne	PC+3
	clr		a0
	rcall	eeprom_store		;loads highscore to a0

	sei					; set global interrupt

; === main program ===
main:
	rjmp		main
