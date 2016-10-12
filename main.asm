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
		CALL INITSPRITES
		
		LD A,0
		LD (COUNTER), A
		LD (COUNTER2), A
		LD (OLDJIF), A
		LD HL, SINTAB32
MAIN:			
		CALL WAITVBL

		LD A, (HL)	; Get value from sintab
		AND  7		; Only use the first 3 bits
		
		LD C,A
		
		PUSH HL
		
		LD HL, BANK_PATTERN_0
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
		LD B,6
		LD IX, SPRITEBUFFER
		LD IY, SPRITEATTR
		
		PUSH HL
		PUSH BC
SPRITEMOVELOOP:
		LD A, (IY + SPRITEX)
		SUB (HL)
		LD (IX + SPRITEX), A

		PUSH BC
		EX DE, HL
		LD HL, SINTAB32
		LD A, (COUNTER2)
		LD C, A
		LD A, (IY + SPRITEY)
		LD B,0
		
		ADD HL, BC
		LD B, (HL)
		SRA B
		SUB B
		LD (IX + SPRITEY), A
		EX DE, HL
		POP BC
		
		
		PUSH DE
		LD DE, 4
		ADD IX, DE
		ADD IY, DE
		POP DE
		DJNZ SPRITEMOVELOOP

		POP BC
		POP HL


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
		
		LD A, (COUNTER2)
		INC A
		INC A
		LD (COUNTER2), A
		
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
		OR 3			; Set bit 0 (16x16 sprites, magnified)
		LD B,A		
		LD C,1			; Set VDP reg 1
		CALL WRTVDP
		
		LD DE,(GRPCGP) ; Fill tiles
		LD BC,6144
		LD HL, BANK_PATTERN_0
		CALL LDIRVM
		
		LD DE,(GRPCOL)	; Fill color table
		LD BC,6144
		LD HL, BANK_COLOR_0
		CALL LDIRVM

		; Copy moving char pattern to MOVINGCHAR
		LD HL, BANK_PATTERN_0
		LD DE, MOVINGCHAR
		LD BC,8
		LDIR

		LD HL, SCREEN 
		LD DE,(GRPNAM)		; Init the screen data
		LD BC, 768
		LD HL, SCREEN
		CALL LDIRVM
		
		
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
		;ld a,4
		;out (0x99),a
		;ld a,7+128
		;out (0x99),a
		
		; Copy "moving" background char to VDP
		LD DE,(GRPCGP) ; 
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		LD DE,(GRPCGP + 2048) ; Fill tiles part 1
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		LD HL, (GRPCGP)		; Fill tiles part 2
		LD DE, 2048
		ADD HL, DE
		EX DE,HL
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		LD HL, (GRPCGP)	;	Fill tiles part 2
		LD DE, 4096
		ADD HL, DE
		EX DE,HL
		LD BC,8
		LD HL, MOVINGCHAR
		CALL LDIRVM
		
		LD    DE,(GRPATR) ; Show the sprites
        LD    HL,SPRITEBUFFER
        LD    BC,24
        CALL  LDIRVM
		
		; For timing, set the border color to black
		;ld a,0
		;out (0x99),a
		;ld a,7+128
		;out (0x99),a
		
		RET
		
INITSPRITES:
		LD    DE,(GRPPAT) ; Fill Sprite attribute table
		LD    BC, 256
		LD    HL, SPRITES 
		CALL  LDIRVM	
		
		LD HL, SPRITEATTR
		LD DE, SPRITEBUFFER
		LD BC, 24
		LDIR
		
		RET
		
				
SPRITES:
		; 3
		DB 0xFF,0xFF,0xFF,0xFF,0x00,0x00,0xFF,0xFF
		DB 0xFF,0xFF,0x00,0x00,0xFF,0xFF,0xFF,0xFF
		DB 0xFC,0xFE,0xFF,0xFF,0x0F,0x0F,0xFF,0xFF
		DB 0xFF,0xFF,0x0F,0x0F,0xFF,0xFF,0xFE,0xFC
		; 0
		DB 0x3F,0x7F,0xFF,0xFF,0xF0,0xF0,0xF0,0xF0
		DB 0xF0,0xF0,0xF0,0xF0,0xFF,0xFF,0x7F,0x3F
		DB 0xFC,0xFE,0xFF,0xFF,0x0F,0x0F,0x0F,0x0F
		DB 0x0F,0x0F,0x0F,0x0F,0xFF,0xFF,0xFE,0xFC
		; J
		DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DB 0x0F,0x0F,0x0F,0x0F,0x0F,0x0F,0x0F,0x0F
		DB 0x0F,0x0F,0x0F,0x0F,0xFF,0xFF,0xFE,0xFC
		; A
		DB 0x3F,0x7F,0xFF,0xFF,0xF0,0xF0,0xF0,0xFF
		DB 0xFF,0xFF,0xFF,0xF0,0xF0,0xF0,0xF0,0xF0
		DB 0xFC,0xFE,0xFF,0xFF,0x0F,0x0F,0x0F,0xFF
		DB 0xFF,0xFF,0xFF,0x0F,0x0F,0x0F,0x0F,0x0F
		; A
		DB 0x3F,0x7F,0xFF,0xFF,0xF0,0xF0,0xF0,0xFF
		DB 0xFF,0xFF,0xFF,0xF0,0xF0,0xF0,0xF0,0xF0
		DB 0xFC,0xFE,0xFF,0xFF,0x0F,0x0F,0x0F,0xFF
		DB 0xFF,0xFF,0xFF,0x0F,0x0F,0x0F,0x0F,0x0F
		; R
		DB 0xFF,0xFF,0xFF,0xFF,0xF0,0xF0,0xF0,0xFF
		DB 0xFF,0xFF,0xFF,0xF0,0xF0,0xF0,0xF0,0xF0
		DB 0xFC,0xFE,0xFF,0xFF,0x0F,0x0F,0x0F,0xFF
		DB 0xFF,0xFE,0xFC,0x3E,0x1F,0x0F,0x0F,0x0F
		
	
SPRITEATTR:
		DB 90,92,0,15
		DB 90,128,4,15
		
		DB 130,48,8,15
		DB 130,84,12,15
		DB 130,120,16,15
		DB 130,156,20,15


		
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
		
		INCLUDE "tiles2.asm"
		INCLUDE "screen2.asm"
		
		DS 0xC000-$
		org 0xC000
MOVINGCHAR: DS VIRTUAL 8	
OLDHK:	DS VIRTUAL 5
OLDJIF:	DS VIRTUAL 2
CHARPOSX: DS VIRTUAL 2
SPRITEBUFFER: DS VIRTUAL 24
COUNTER: DS VIRTUAL 1
COUNTER2: DS VIRTUAL 1

