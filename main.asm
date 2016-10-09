;rom header
		org 0x4000
		db "AB"
		dw START,0,0,0,0,0,0
		
		INCLUDE "bios.asm"

SPRITEY: EQU 0
SPRITEX: EQU 1
SPRITEPAT: EQU 2
SPRITEC: EQU 3


START:
		CALL INITSCR
		CALL INITINT
		CALL INITCHARS
		CALL INITSPRITES
		
		LD A,0
		LD (COUNTER), A
		LD (OLDJIF), A
		LD HL, SINTAB32
MAIN:			
		CALL WAITVBL

		LD A, (HL)	; Get value from sintab
		AND  7		; Only use the first 3 bits
		
		LD C,A
		
		PUSH HL
		
		LD HL, TILEDATA.TILES
		LD DE, MOVINGCHAR
		LD A, (COUNTER)
		AND 7
		LD E,A
		
		LD B,8
CHARLOOP:
		LD A,C
		CP 0
		LD A, (HL)
		JP Z, NOXLOOP
		PUSH BC
		LD B,C
XLOOP:
		RRCA
		DJNZ XLOOP
		POP BC

NOXLOOP:		
		LD (DE), A
		INC HL
		INC E
		LD A,E
		AND 7
		LD E,A
		
		DJNZ CHARLOOP
			
		
		POP HL
		
NOCHANGE:
		INC HL
		; Did we reach the end of SINTAB32? Reset. TODO: Align sintab to 256 address boundary and only in L
		LD A,128
		CP (HL)
		JP NZ, ENDLOOP
		LD HL, SINTAB32

ENDLOOP:		
		LD A, (COUNTER)
		INC A
		LD (COUNTER), A
		JP MAIN

		
		
; Wait for Jiffy to change
; IN: 
; OUT:
; CHANGES: A
WAITVBL:
  		PUSH HL
		PUSH DE
WAITLOOP:
		LD HL,(JIFFY)	; Check if JIFFY is changed
		LD DE,(OLDJIF)
		LD A,L
		CP E
		JP Z, WAITLOOP	; Zero? JIFFY has not changed
		LD (OLDJIF), HL
		POP DE
		POP HL
		RET
		
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
		OR 1			; Set bit 0 (16x16 sprites, magnified)
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
		
		LD    DE,(GRPATR) ; Show the sprites
        LD    HL,SPRITEBUFFER
        LD    BC,4
        CALL  LDIRVM
		
		; For timing, set the border color to black
		ld a,0
		out (0x99),a
		ld a,7+128
		out (0x99),a
		
		RET
		
INITSPRITES:
		LD    DE,(GRPPAT) ; Fill Sprite attribute table
		LD    BC, 32
		LD    HL,CHARBUFFER+64*8
		CALL  LDIRVM	
		

		
		LD IX, SPRITEBUFFER
		LD (IX+SPRITEY), 50
		LD (IX+SPRITEX), 50
		LD (IX+SPRITEPAT), 1
		LD (IX+SPRITEC), 15
		INC IX
		INC IX
		INC IX
		INC IX
		
		RET
		
; Copy char definition from ROM to RAM in current slot		
INITCHARS:
		LD BC, 2048
		LD DE, CHARBUFFER
		LD HL, (CGPNT+1)
INITCHARLOOP:
		PUSH BC
		PUSH DE
		LD A,(CGPNT)
		CALL RDSLT
		EI
		POP DE
		POP BC
		LD (DE),A
		INC DE
		INC HL
		DEC BC
		LD A,B
		OR C
		JR NZ, INITCHARLOOP
		RET
		
		
		
MOVE:   DB 0,0,0,0,0,1,0,1,1,1,1,1,2,2,2,2,3,3,3,3,2,2,2,2,1,1,1,1,1,0,1,0
		DB 0,0,0,0,0,7,0,7,7,7,7,7,6,6,6,6,5,5,5,5,6,6,6,6,7,7,7,7,7,0,7,0,255
			
SPRITE:
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
		DB 10101010b
		DB 01010101b
	
SPRITEATTR:
		DB 10,0,0,15
		DB 10,32,0,15
		DB 10,64,0,15
		DB 10,96,0,15

SINTAB32:
		DB 0,1,2,2,3,4,5,5,6,7,8,9,9,10,11,12,12,13,14,14,15,16,16,17,18,18,19,20,20,21,21,22,23
		DB 23,24,24,25,25,26,26,27,27,27,28,28,29,29,29,30,30,30,30,31,31,31,31,31,32,32,32,32,32,32,32,32
		DB 32,32,32,32,32,32,32,31,31,31,31,31,30,30,30,30,29,29,29,28,28,27,27,27,26,26,25,25,24,24,23,23
		DB 22,21,21,20,20,19,18,18,17,16,16,15,14,14,13,12,12,11,10,9,9,8,7,6,5,5,4,3,2,2,1,0
		DB -1,-2,-2,-3,-4,-5,-5,-6,-7,-8,-9,-9,-10,-11,-12,-12,-13,-14,-14,-15,-16,-16,-17,-18,-18,-19,-20,-20,-21,-21,-22,-23
		DB -23,-24,-24,-25,-25,-26,-26,-27,-27,-27,-28,-28,-29,-29,-29,-30,-30,-30,-30,-31,-31,-31,-31,-31,-32,-32,-32,-32,-32,-32,-32,-32
		DB -32,-32,-32,-32,-32,-32,-32,-31,-31,-31,-31,-31,-30,-30,-30,-30,-29,-29,-29,-28,-28,-27,-27,-27,-26,-26,-25,-25,-24,-24,-23,-23
		DB -22,-21,-21,-20,-20,-19,-18,-18,-17,-16,-16,-15,-14,-14,-13,-12,-12,-11,-10,-9,-9,-8,-7,-6,-5,-5,-4,-3,-2,-2,-1
		DB 128
SINTAB8:
		DB 0,0,0,1,1,1,1,1,1,2,2,2,2,2,2,3,3,3,3,3,3,3,4,4,4,4,4,4,4,5,5,5,5
 		DB 5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
		DB 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,6,6,6,6,6,6,6,6,6,6,6,6,5,5,5,5,5
		DB 5,5,5,4,4,4,4,4,4,4,3,3,3,3,3,3,3,2,2,2,2,2,2,1,1,1,1,1,1,0,0,0
		DB 0,0,-1,-1,-1,-1,-1,-1,-2,-2,-2,-2,-2,-2,-3,-3,-3,-3,-3,-3,-3,-4,-4,-4,-4,-4,-4,-4,-5,-5,-5,-5
		DB -5,-5,-5,-5,-6,-6,-6,-6,-6,-6,-6,-6,-6,-6,-6,-6,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7
		DB -7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-7,-6,-6,-6,-6,-6,-6,-6,-6,-6,-6,-6,-6,-5,-5,-5,-5,-5
		DB -5,-5,-5,-4,-4,-4,-4,-4,-4,-4,-3,-3,-3,-3,-3,-3,-3,-2,-2,-2,-2,-2,-2,-1,-1,-1,-1,-1,-1,0,0
		DB 128
		
		INCLUDE "tiles.asm"		

		DS 0x8000-$
		org 0xC000
MOVINGCHAR: DS VIRTUAL 8	
OLDHK:	DS VIRTUAL 5
OLDJIF:	DS VIRTUAL 2
CHARPOSX: DS VIRTUAL 2
SPRITEBUFFER: DS VIRTUAL 256
COUNTER: DS VIRTUAL 1
CHARBUFFER: DS VIRTUAL 2048

