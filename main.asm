;rom header
		org 0x4000
		db "AB"
		dw START,0,0,0,0,0,0

		INCLUDE "BIOS.ASM"

START:
		CALL INITSCR
		CALL INITINT
		
		LD DE, MOVE
		LD HL, 256
		LD (CHARPOSX), HL
MAIN:
		LD A,0
		LD (OLDJIF), A
		
AGAIN:
		PUSH DE
JIFFYLOOP:
		LD HL,(JIFFY)	; Check if JIFFY is changed
		LD DE,(OLDJIF)
		LD (OLDJIF), HL
		LD A,L
		CP E
		JP Z, JIFFYLOOP	; Zero? JIFFY has not changed

		POP DE		
		
		LD HL, MOVINGCHAR
		LD B,8
HANDLECHAR:
		LD A, (DE)
		CP 0
		JP Z, SKIPCHANGE

		PUSH BC
		LD B, A
		LD A, (HL)
LOOPLOOP:
		RRCA
		DJNZ LOOPLOOP
		
		POP BC
		LD (HL), A

SKIPCHANGE:		
		INC HL
		DJNZ HANDLECHAR
		
		INC DE
		LD A, (DE)
		CP 255
		JP NZ, AGAIN
		
		LD DE, MOVE
		JP AGAIN

INITSCR:
		; Set color 15,1,1
		LD A,15			
		LD (FORCLR),A
		LD A,1
		LD (BAKCLR),A
		LD (BRDCLR),A
		CALL CHGCLR

		; Change to screen 2
		LD A,2
		CALL CHMOD
		
		LD A,(RG0SAV + 1)	; Load VDP reg 1 FROM BIOS mirror
		AND %11111100	; Reset bits 1 (SIZE) and 0 (MAG)
		OR 2			; Set bit 2 (SIZE, 16x16 sprites)
		LD B,A		
		LD C,1			; Set VDP reg 1
		CALL WRTVDP
		
		LD DE,(GRPCGP) ; Fill tiles
		LD BC,16
		LD HL, TILEDATA.TILES
		CALL LDIRVM
		
		LD HL, (GRPCGP)
		LD DE, 2048
		ADD HL, DE
		EX DE,HL
		LD BC,16
		LD HL, TILEDATA.TILES
		CALL LDIRVM
		
		LD HL, (GRPCGP)
		LD DE, 4096
		ADD HL, DE
		EX DE,HL
		LD BC,16
		LD HL, TILEDATA.TILES
		CALL  LDIRVM
		
		LD DE,(GRPCOL)	; Fill color table
		LD BC,16
		LD HL, TILEDATA.COLORS
		CALL LDIRVM

		LD HL,(GRPCOL)	; Fill color table
		LD DE, 2048
		ADD HL, DE
		EX DE, HL
		LD BC,16
		LD HL, TILEDATA.COLORS
		CALL LDIRVM
		
		LD HL,(GRPCOL)	; Fill color table
		LD DE, 4096
		ADD HL, DE
		EX DE, HL
		LD BC,16
		LD HL, TILEDATA.COLORS
		CALL LDIRVM
		
		LD HL,(GRPNAM)		; Clear the screen
		LD A,0
		LD BC,786
		CALL FILVRM
	
		; Copy moving char pattern to MOVINGCHAR
		LD HL, TILEDATA.TILES
		LD DE, MOVINGCHAR
		LD BC,8
		LDIR
	
		RET
	
INITINT:
		; Backup H.TIMI hook (VDP vblank interrupt)
		LD HL, 0xFD9F	
		LD DE, OLDHK
		LD BC,5
		LDIR
		; Set own hook
		DI				
		LD HL, NEWHK
		LD DE, 0xFD9F
		LD BC,5
		LDIR
		EI
		RET
		
NEWHK:
		JP MYINT
		RET
		RET
		
MYINT:	; Code called from H.TIMI hook

		; For timing, set the border color to blue
		ld a,4
		out (0x99),a
		ld a,7+128
		out (0x99),a
		
		; Copy "moving" background char to VDP
		LD DE,(GRPCGP) ; Fill tiles
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		LD DE,(GRPCGP + 2048) ; Fill tiles
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		LD HL, (GRPCGP)
		LD DE, 2048
		ADD HL, DE
		EX DE,HL
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		LD HL, (GRPCGP)
		LD DE, 4096
		ADD HL, DE
		EX DE,HL
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		
		
		; For timing, set the border color to black
		ld a,0
		out (0x99),a
		ld a,7+128
		out (0x99),a
		
		RET
		
MOVE:   DB 0,0,0,0,0,1,0,1,1,1,1,1,2,2,2,2,3,3,3,3,2,2,2,2,1,1,1,1,1,0,1,0
		DB 0,0,0,0,0,7,0,7,7,7,7,7,6,6,6,6,5,5,5,5,6,6,6,6,7,7,7,7,7,0,7,0,255
			

	
		INCLUDE "TILES.ASM"		

		DS 0x8000-$
		org 0xC000

BUFFER: DS VIRTUAL 768
OLDHK:	DS VIRTUAL 5
OLDJIF:	DS VIRTUAL 2
MOVINGCHAR: DS VIRTUAL 8	
CHARPOSX: DS VIRTUAL 2