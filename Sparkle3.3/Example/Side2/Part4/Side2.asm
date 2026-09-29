//TAB=8
//--------------------------------------
//
//	Sparkle 3 Example Project 
//	Side 2
//
//--------------------------------------

.import source "../../../Source/6510/Sparkle.inc"	//Import loader calls

.const InitSID			= $2000			//Initialize SID
.const PlaySID			= $2003			//Play SID
.const HiScore			= $d000			//Hi-score file under I/O
.const Screen			= $0400			//Screen
.const ColorRam			= $d800			//Color RAM
.const Part5_DirIndex		= $01			//We have assigned DirIndex = $01 in the script to bundle #2 (Part 5)

*=$1000
		//------------------------------
		//Load SID and init IRQ
		//------------------------------

		jsr Sparkle_LoadNext			//These are skipped after disk change
		jsr IRQInit

		//------------------------------
		//Entry after disk change
		//------------------------------

NextSideEntry:	
		lda #$00				//We continue here after flipping the disk
		sta $d011
		sta $d021
		sta $d020

		jsr ClearScreen

		//------------------------------
		//Load bundle #02 (DirIndex = 01 as specified in the script)
		//------------------------------

		lda #<Part5_DirIndex			//We need to use directory index-based loading here to make sure
		jsr Sparkle_LoadA			//we load the proper bundle even after disk change
							//A sequential loader call after disk change would load bundle #01 (SID) here

		lda #$3c				//VIC bank: $0000-$3fff
		sta $dd02
		lda #$16
		sta $d018
		lda #$08
		sta $d016
		lda #$1b
		bit $d011
		bpl *-3
		sta $d011

		jsr Wait10				//10-second delay, can be aborted by pressing space

		//------------------------------
		//Load next bundle
		//------------------------------

		jsr Sparkle_LoadNext			//Sequential loader call

		lda #$01
		sta $d020
		sta $d021

		lda #$3d				//VIC bank: $4000-$7fff
		sta $dd02
		lda #$18
		sta $d018
		lda #$3b
		bit $d011
		bpl *-3
		sta $d011

		jmp *

//----------------------------------------------

		//------------------------------
		//Initialize IRQ
		//------------------------------

IRQInit:	
		ldx #$7f				//Disable CIA interrupts, I=0 here
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
		rts

//----------------------------------------------

Wait10:	ldx #$0a
		ldy #$32
WaitP:		lda $dc01
		and #$10
		beq WaitDone
		lda $d011
		bpl WaitP
WaitM:		lda $dc01
		and #$10
		beq WaitDone
		lda $d011
		bmi WaitM
		dey
		bne WaitP
		dex
		bne Wait10+2
WaitDone:
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
		lda #$0d
		sta ColorRam,x
		sta ColorRam+$100,x
		sta ColorRam+$200,x
		sta ColorRam+$2e8,x
		inx
		bne ClearLoop
		rts
