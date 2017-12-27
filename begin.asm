:BasicUpstart2(start)
.pc = $0840 "Program start"
.encoding "screencode_mixed"

sprite: .byte 	%00000000,%00000000,%00000000
		.byte	%00001000,%00000000,%00010000
		.byte	%00000000,%00000000,%00000000
		.byte	%00001000,%00000000,%00010000
		.byte	%00000000,%00000000,%00000000
		.byte	%00001000,%00000000,%00010000
		.byte	%00000000,%00011000,%00000000
		.byte	%00001000,%00100100,%00010000
		.byte	%00001000,%01000010,%00010000
		.byte	%00001000,%10000001,%00010000
		.byte	%00001001,%00011000,%10010000
		.byte	%00001010,%00111100,%01010000
		.byte	%00001100,%00111100,%00110000
		.byte	%00001000,%00000000,%00010000
		.byte	%00010000,%10000001,%00001000
		.byte	%00100000,%10000001,%00000100
		.byte	%00100000,%00000000,%00000100
		.byte	%00111111,%11111111,%11111100
		.byte	%00001111,%00000000,%11110000
		.byte	%00000000,%00000000,%00000000
		.byte	%00000000,%00000000,%00000000
		.byte	0

// 6502
.const CPU_PORT = $01            	// CIA#1 (Port Register A)
.const CPU_NMIVECLO = $fffa
.const CPU_NMIVECHI = $fffb

.const CPU_RESETVEC = $fffc //&fffd

.const CPU_IRQVECLO = $fffe
.const CPU_IRQVECHI = $ffff

// Keyboard
.const CIA1_PRA = $dc00 // CIA#1 (Port Register A)
.const CIA1_DDRA = $dc02 // CIA#1 (Data Direction Register A)
.const CIA1_PRB = $dc01 // CIA#1 (Port Register B)
.const CIA1_DDRB = $dc03            // CIA#1 (Data Direction Register B)

// Interrupts and timers
.const CIA1_ICS = $dc0d            // CIA#1 (Data Direction Register B)
.const CIA2_ICS = $dd0d            // CIA#1 (Data Direction Register B)

// Timers
.const CIA1_TALO = $dc04
.const CIA1_TAHI = $dc05
.const CIA1_TAC = $dc0e            // CIA#1 (Data Direction Register B)

// Video
.const VIC_BORDERCOL = $d020
.const VIC_BGCOL = $d021
.const VIC_MEMCTL = $d018

.const VIC_INT_STS = $D019
.const VIC_INT_CTL = $D01A

.const VIC_SCR_CTL1 = $D011
.const VIC_RASTERLINE = $D012

.const VIC_SPRITE_EN = $d015

.const VIC_SPRITE1_PTR = $07F8
.const VIC_SPRITE1_X = $D000
.const VIC_SPRITE1_Y = $D001

// Screen memory
.const SCREEN_MEM = $0400
 
done: .byte 0
message: .text "A FaStEcNiX PRODUCTION"
	  .byte 0

// -------------------------------------------------------------------------------------

start:
	
	// Kernal clear screen
	jsr $e544

 	// Disable interrupts
	sei        		

	//Turn off the BASIC and KERNAL rom, $d000-$e000 is still IO
	lda #$35   		
	sta CPU_PORT

	// Turn of Kernal CIA timers
	lda #$7f		
	sta CIA1_ICS
	sta CIA2_ICS  		
           			
    // ACK any pending interrupts that arose since the disable
	bit CIA1_ICS  		
	bit CIA2_ICS  		           			
	
    // New NMI vector
    lda #<nmi  	
	sta CPU_NMIVECLO  	 	
	lda #>nmi  	
	sta CPU_NMIVECHI
	
	// New IRQ vector    
    lda #<irq  	  	 	  	 	
	sta CPU_IRQVECLO
	lda #>irq
	sta CPU_IRQVECHI
	
	// COuld set up timer here jsr start_timer 	
	// Set mixed character rom
	lda #$17
	sta VIC_MEMCTL

	// Set border and background colors to black   	
	lda #$00 	
	sta VIC_BORDERCOL
 	sta VIC_BGCOL

	// Set (default location) color ram to white
	ldx #$fa
	lda #$01
clearcol:	
	dex
	sta $D800+($FA*0),x	
	sta $D800+($FA*1),x	
	sta $D800+($FA*2),x	
	sta $D800+($FA*3),x		
	bne clearcol

	// Enable raster interrupts
	lda #$01
	sta VIC_INT_CTL
	
	// Raise IRQ on line 230
	lda #$FB
	sta VIC_RASTERLINE

	// Top bit of raster line, plus desired values for other stuff
	lda #$1b
	sta VIC_SCR_CTL1

	// Sprite
	lda #$21
	sta VIC_SPRITE1_PTR
	lda #$01
	sta VIC_SPRITE_EN
	lda #$50
	sta VIC_SPRITE1_X
	sta VIC_SPRITE1_Y
	
	// Start interrupts
	cli

	ldx #$0
printloop:
	lda message,x
	cmp #$0
	beq printdone
	sta SCREEN_MEM + $01E9,x
	inx
	jmp printloop
printdone:
	// Main Loop
loop:	
	// Test Keyboard
	// CIA#1 port A = outputs 
	// CIA#1 port B = inputs
 	lda #$ff  
    sta CIA1_DDRA             
	lda #$00  		
    sta CIA1_DDRB             

    lda #%11111101  // testing column 1 (COL1) of the matrix
    sta CIA1_PRA
        
	lda CIA1_PRB
    and #%00100000  // masking row 5 (ROW5) 
    bne nokey        // wait until key "S"

    inc VIC_BGCOL
nokey:
 	// Loop while flag is 0 
	lda done
	cmp #$0
	beq loop

	// Exit code --
	
	// Put memory mappings back
	lda #$37   		
	sta CPU_PORT
	
	// Jump to 6502 reset vector
	jmp (CPU_RESETVEC) 

nmi:
	// Flag our quit condition.
	inc done		
	bit CIA2_ICS	// ack
	rti				// quit interrupt routine

irq:
	sta restore_regs+1 // Faster than push, and no stack req. here

	inc VIC_BORDERCOL
 	inc VIC_SPRITE1_X  
 	inc VIC_SPRITE1_Y 
 	lda #$ff
 	sta VIC_INT_STS

restore_regs: 
	lda #$00
 	rti				// quit interrupt routine


// NOT USED
// Will also need IRQ handler to ack we handled it
// bit CIA1_ICS

start_timer:
	// Enable timer 1 interrupts  	
   	lda #$81
   	sta CIA1_ICS

	// Set timer start value
	lda #$7f
   	sta CIA1_TALO 
   	lda #$4
   	sta CIA1_TAHI 
   	    
   	// Load start value, and "Start" Timer 1 
   	// (probably already started but without interrupts)
   	lda #$11 
	sta CIA1_TAC
	rts
