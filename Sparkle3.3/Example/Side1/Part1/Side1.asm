//TAB=8
//--------------------------------------
//
//	Sparkle 3 Example Project 
//	Side 1
//
//--------------------------------------

.import source "../../../Source/6510/Sparkle.inc"	//Import loader functions

.const InitSID			= $2000			//Initialize SID
.const PlaySID			= $2003			//Play SID
.const HiScore			= $d000			//Hi-score file under I/O
.const Screen			= $0400			//Screen
.const Bitmap			= $6000
.const BmpScreen		= $4400
.const ColorRam			= $d800			//Color RAM
.const NextSideEntry		= $1006			//Skip first two JSR calls
.const Msg			= HiScore+$80		//Text within hi-score file
.const Suffix			= HiScore+$e0		//Ordinal number suffixes
.const Row			= 10
.const StartPos			= Row*40

.const ready			= $08
.const sendbyte			= $18

*=$1000

		//------------------------------
		//Load SID
		//------------------------------

Start:		jsr Sparkle_LoadNext	

		//------------------------------
		//Initialize IRQ
		//------------------------------

Init:		ldx #$7f				//Disable CIA interrupts, I=0 here
		stx $dc0d
		stx $dd0d
		lda $dd0d-$7f,x				//Acknowledge pending CIA interrupts

		lda #$1b
		sta $d011

		lda #$00				//Raster line
		ldx #>PlaySID				//Music player subroutine address high byte
		ldy #<PlaySID				//Music player subroutine address low byte

		sty Sparkle_IRQ_JSR+1
		stx Sparkle_IRQ_JSR+2

		sta $d012
		lda #<Sparkle_IRQ			//Fallback IRQ in Sparkle's C64 resident code
		sta $fffe
		lda #>Sparkle_IRQ
		sta $ffff
		
		lda #$00
		jsr InitSID				//Initialize music player
		
		lda #$01
		sta $d01a				//Enable raster IRQ
		sta $d019				//Acknowledge pending raster IRQ

		cli

		//------------------------------
		//Load "hi-score" file
		//------------------------------

		lda #$7f				//Load "hi-score" file to $d000 (under I/O)
		jsr Sparkle_LoadA			//Can only be accessed using an index-based loader call

		lda #$00
		sta $d021
		sta $d020
		lda #$16				//Second built-in char set
		sta $d018

		jsr DisplayMsg				//Display message

		//------------------------------
		//Save "hi-score" file
		//------------------------------

		lda #$7e				//Load Saver code
		jsr Sparkle_LoadA			//Can only be accessed using an index-based loader call

		lda #$01				//Save "hi-score" file
		jsr Sparkle_Save			//Save 1 page of data from $d000 (address is set in script) 
							//We are at the end of the disk, so need an index-based loader call after this!!!

		//------------------------------
		//Prepare for next file bundle
		//------------------------------

		lda #$02
		jsr Sparkle_SendCmd			//Reposition R/W head to next bundle while doing something else

		jsr Wait5				//5-second delay to emulate "doing something else"

		jsr ClearScreen

		ldx #$01
		stx $d020
		stx $d021

		//------------------------------
		//Load prefetched bundle
		//------------------------------

		jsr Sparkle_LoadFetched			//Load previously fetched bundle

		lda #$3d				//VIC bank: $4000-$7fff
		sta $dd02

		lda #$18
		sta $d018
		sta $d016
		lda #$3b
		sta $d011

		jsr Wait5				//5-second delay

		//------------------------------
		//Load next bundle in sequence
		//------------------------------

		lda #$00
		sta $d011
		sta $d020

		jsr Sparkle_LoadNext			//Load next bundle

		ldx #$01
		ldy #$01
		jsr Wait

		lda #$08
		sta $d016
		lda #$3b
		sta $d011

		jsr Wait5

		//------------------------------
		//Request next side and load
		//first bundle after disk flip
		//------------------------------

		//jsr Sparkle_LoadNext			//This call would request the next disk side and load the first bundle
							//But it would be a blocking call, and it would only return once the bundle finished loading
							//So let's do something else instead (see DISK FLIPPING USING NONBLOCKING CALLS in manual)...

		lda #$81				//Disk indices are 0-based (+$80) unless ThisSide and NextSide are used in script
		jsr Sparkle_SendCmd			//Use Sparkle_SendCmd here to avoid blocking calls

		lda #sendbyte				//Signal to drive we will want to request a bundle by sending a dir index
		sta $dd00
		
		ldy #$00
!:		bit $d011				//Code in main loop
		bmi *-3
		bit $d011
		bpl *-3
		lda ColorCycle,y
		ldx #$05
!:		sta BmpScreen+$3e8-6,x
		dex
		bpl !-
		iny
		tya
		and #$0f
		tay
		bit $dd00				//Wait until drive detects new disk side and is ready to send 1st bundle
		bmi !--					//N=1 -> drive is not ready; N=0 -> drive is ready

		lda #>NextSideEntry-1			//First bundle of next side will overwrite this code, so we push the start address to the stack
		pha					//To ensure the RTS in the loader code returns to the correct address
		lda #<NextSideEntry-1
		pha

		lda #$00
		jmp Sparkle_LoadA			//Load first bundle and then return to address of first bundle in stack

//----------------------------------------------

		//------------------------------
		//Display message
		//------------------------------

DisplayMsg:	lda #$34				//Hi-score file is in RAM under I/O
		sta $01					//Sparkle's Fallback IRQ can handle this

		ldx #$03				//Advance counter
		sec
NextDigit:	lda #$0a
		isc HiScore,x				//Increment digit and check if it has reached 10
		bne CounterDone
		sta HiScore,x				//Reset digit to 0
		dex					//And increment next digit
		bpl NextDigit
		inc HiScore+3				//This is needed only when the counter wraps 9999->0000->0001

CounterDone:	
		jsr ClearScreen

		ldx #$00
MsgLoop:
		lda Msg,x
		beq MsgDone1
		sta Screen+StartPos,x
		inx
		bne MsgLoop

MsgDone1:
		stx XPos+1

		ldy #$ff
FindFirstNon0:
		iny
		lda HiScore,y				//Find first non-0 digit
		beq FindFirstNon0
DisplayLoop:
		ora #$30
		sta Screen+StartPos,x
		lda #$0d
		inc $01
		sta ColorRam+StartPos,x			//Updating color RAM
		dec $01
		inx
		iny
		lda HiScore,y				//Reading from RAM under I/O
		cpy #$04
		bne DisplayLoop

		lda HiScore+2				//Select ordinal number suffix
		cmp #$01
		beq TakeTh				//Skip 10s - suffix is always 'th'
		ldy #$00
		lda HiScore+3				//Last digit
		cmp #$01				//1st
		beq DisplaySfx
		ldy #$02
		cmp #$02				//2nd
		beq DisplaySfx
		ldy #$04
		cmp #$03				//3rd
		beq DisplaySfx
TakeTh:		ldy #$06				//Nth
DisplaySfx:
		lda Suffix,y
		sta Screen+StartPos,x
		lda #$0d
		inc $01					//Updating color RAM
		sta ColorRam+StartPos,x
		inx
		iny
		sta ColorRam+StartPos,x
		dec $01
		lda Suffix,y				//Reading from RAM under I/O
		sta Screen+StartPos,x
		inx
XPos:		ldy #$00
		iny
DisplayLoop2:
		lda Msg,y
		beq MsgDone2
		sta Screen+StartPos,x
		inx
		iny
		bne DisplayLoop2

MsgDone2:
		lda #$35
		sta $01
		rts

//----------------------------------------------

Wait5:		ldx #$05		
		ldy #$32
Wait:		lda $d011
		bpl *-3
		lda $d011
		bmi *-3
		dey
		bne Wait
		dex
		bne Wait-2
		rts

//----------------------------------------------

ClearScreen:
		ldx #$00
ClearLoop:
		lda #$20
		sta Screen,x
		sta Screen+$100,x
		sta Screen+$200,x
		sta Screen+$2e8,x
		lda #$0e
		sta ColorRam,x
		sta ColorRam+$100,x
		sta ColorRam+$200,x
		sta ColorRam+$2e8,x
		inx
		bne ClearLoop
		rts

ColorCycle:
.byte $00,$60,$b0,$40,$e0,$30,$d0,$70
.byte $10,$70,$f0,$a0,$80,$20,$b0,$90