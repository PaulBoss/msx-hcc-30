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
		CALL INITSPRITES
		CALL INITINT
		
		; Initialize variables
		LD A,0
		LD (COUNTER), A
		LD (COUNTER2), A
		LD (OLDJIF), A
		LD HL, SINTAB32
MAIN:			
		CALL WAITVBL

		LD A, (HL)	; Get value from sintab
		AND  7		; Only use the first 3 bits
		
		LD C,A		; Save sinus value in C
		
		PUSH HL
		
		LD HL, BANK_PATTERN_0
		LD DE, MOVINGCHAR
		LD A, (COUNTER)		;Set Y pos for copying to the moving BG Char
		AND 7
		LD E,A				; Y position in DE
		
		LD B,8
CHARLOOP:
		LD A,C				; Get sinus value
		CP 0				; 0? No change in X position
		LD A, (HL)
		JP Z, NOXLOOP
		PUSH BC
		LD B,C				; Rotate the bits X times
XLOOP:
		RRCA
		DJNZ XLOOP
		POP BC

NOXLOOP:		
		LD (DE), A			; Set the current line in the moving BG char
		INC HL				; Read from next line
		INC E				; Write to next line
		LD A,E				; Wrap Y value within the moving BG char definition
		AND 7
		LD E,A
		
		DJNZ CHARLOOP
			
		
		POP HL
		
NOCHANGE:
		LD B,5				; Change 5 sprites (30 jaar)
		LD IX, SPRITEBUFFER	 
		LD IY, SPRITEATTR	
		
		PUSH BC
		PUSH HL
SPRITEMOVELOOP:
		LD A, (IY + SPRITEX)	; Get current X value
		SUB (HL)				; Subtract sinus value
		LD (IX + SPRITEX), A	; Set current X value

		PUSH BC
		EX DE, HL
		LD HL, SINTAB32			
		LD A, (COUNTER2)		; Get counter
		LD C, A
		LD A, (IY + SPRITEY)	; Get current Y value
		LD B,0
		
		ADD HL, BC				; Add counter to HL to get a second 
		LD B, (HL)				; sinus value from the sintab
		SRA B					; sinus value / 2
		SUB B					; subtract the value from the Y position
		LD (IX + SPRITEY), A	; set y position
		EX DE, HL
		POP BC
		
		
		PUSH DE
		LD DE, 4				; Jump to next sprite in memory
		ADD IX, DE
		ADD IY, DE
		POP DE
		DJNZ SPRITEMOVELOOP

		
		POP HL

		
		LD IX, SPRITEBUFFER + 20 ; Jump to balloon sprite definitions
		LD B, 5
		
BALLOOP:
		LD A, (IX)				; get balloon Y position
		DEC A					; Y = Y - 2
		DEC A
		CP 208					; Skip 208 to prevent sprites being disables
		JP NZ, NOEXTRADEC
		
		DEC A
NOEXTRADEC:
		LD (IX), A				; Set balloon Y position
		INC IX					; IX = IX + 4 : Jump to next balloon
		INC IX
		INC IX
		INC IX
		DJNZ BALLOOP
		
		POP BC
		INC HL
		; Did we reach the end of SINTAB32? Reset. TODO: Align sintab to 256 address boundary and only in L
		LD A,128
		CP (HL)
		JP NZ, ENDLOOP
		LD HL, SINTAB32

ENDLOOP:		
		LD A, (COUNTER)		; counter = counter + 1
		INC A
		LD (COUNTER), A
		
		LD A, (COUNTER2)	; counter2 = counter2 + 2
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
		
; Initialize the screen
; IN:
; OUT:
; CHANGES: All
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

; Install the the interupt hook
; IN:
; OUT:
; Changes: All
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

; Initialize the sprites
; IN: 
; OUT:
; Changes: All
INITSPRITES:
		LD    DE,(GRPPAT) ; Fill Sprite pattern table
		LD    BC, 256
		LD    HL, SPRITES 
		CALL  LDIRVM	
		
		LD HL, SPRITEATTR ; Create copy of sptire attribtue table in RAM
		LD DE, SPRITEBUFFER
		LD BC, 40
		LDIR
		
		RET
		
NEWHK:
		JP MYINT
		RET
		RET
		
; Code called from H.TIMI hook
MYINT:	
		; Copy "moving" background char to VDP
		LD DE,(GRPCGP) ; 
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
        LD    BC,40
        CALL  LDIRVM
				
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
		
		; Jaar
		DB 0x0C,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E
		DB 0x1E,0x1E,0x1E,0x1E,0x7E,0xFE,0xFC,0x78
		DB 0x1F,0x3F,0x7F,0x7F,0x78,0x78,0x7F,0x7F
		DB 0x7F,0x7F,0x78,0x78,0x78,0x78,0x78,0x78
		; 
		DB 0xC0,0xE1,0xF3,0xF3,0xF3,0xF3,0xF3,0xF3
		DB 0xF3,0xF3,0xF3,0xF3,0xF3,0xF3,0xF3,0xF3
		DB 0xFE,0xFF,0xFF,0xFF,0xC7,0xC7,0xFF,0xFF
		DB 0xFF,0xFF,0xC7,0xC7,0xC7,0xC7,0xC7,0xC7
		; 
		DB 0x03,0x87,0xCF,0xCF,0xCF,0xCF,0xCF,0xCF
		DB 0xCF,0xCF,0xCF,0xCF,0xCF,0xCF,0xCF,0xCF
		DB 0xF8,0xFC,0xFE,0xFE,0x1E,0x1E,0xFE,0xFE
		DB 0xFC,0xF8,0x78,0x3C,0x3C,0x1E,0x1E,0x1E
		
		; Balloon
		DB 0x03,0x0F,0x1F,0x3F,0x3F,0x7F,0x7F,0x7F
		DB 0x3F,0x3F,0x1F,0x0F,0x03,0x01,0x00,0x00
		DB 0xF0,0xC8,0xF4,0xF6,0xFE,0xFF,0xFF,0xFF
		DB 0xFE,0xFE,0xFC,0xF8,0xE0,0xC0,0x80,0xC0
		
; Initial sprite attributes
SPRITEATTR:
		DB 90,92,0,15
		DB 90,128,4,15
		
		DB 130,80,8,15
		DB 130,112,12,15
		DB 130,144,16,15
		
		DB 120, 10, 20, 6
		DB 10, 214, 20, 6
		DB 50, 90, 20, 6
		
		DB 85, 50, 20, 6
		DB 150, 140, 20, 6
		
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
		
		; Create a 16K ROM
		DS 0xC000-$
		; RAM
		org 0xC000
MOVINGCHAR: DS VIRTUAL 8	
OLDHK:	DS VIRTUAL 5
OLDJIF:	DS VIRTUAL 2
CHARPOSX: DS VIRTUAL 2
SPRITEBUFFER: DS VIRTUAL 256
COUNTER: DS VIRTUAL 1
COUNTER2: DS VIRTUAL 1

