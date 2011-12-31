[BITS 16] ;tell the assembler we're using 16bit
[ORG 0x7C00] ;tell assembler where our code will be once loaded

%define BOARD_SIZE 150
%define BOARD_COLOUR 0x05
%define START_X 1
%define START_Y 1
%define PIECE_SIZE 50
%define SIZE 13

;set video mode to VGA
mov AX,13 ;set video mode to 13
INT 0x10 ;call bios service

;CALL ClearScreen
;CALL DrawBoard
CALL GAME
JMP $ ;loop infinitely here

GAME: ;play game
;CALL ClearScreen
CALL DrawBoard
CALL GetInput
JMP GAME

RestartGame:
MOV SI,BOARD
CALL ClearScreen
RESET_LOOP:
MOV BL,0
MOV [SI],BL
INC SI
MOV BL,[SI]
CMP BL,9
JNE RESET_LOOP
RET

GetInput: 
mov AH,0x00 ;get keyboard input
INT 0x16 ;call BIOS service
;check if input is to restart game
CMP AH,0x01
JE RestartGame
CMP AL,57 ;make sure our keyboard input is correct
JG GI_QUIT ;if it's not in range 0-8, we want to quit
SUB AL,48 ;remove '0' from AL
;otherwise continue on
MOV SI,BOARD
CALL SetAL
GI_QUIT:
RET

SetAL:
CMP AL,1
JE SET
INC SI
DEC AL
JMP SetAL

SET:
MOV BL,[CUR_TURN]
MOV AL,[SI]
CMP AL,0
JNE EX_EXIT
MOV [SI],BL ;set piece to current
;if CUR_TURN is 2, we'll make it one, not this, get 0, and then add one
;if CUR_TURN is 1, we'll make it 0, not this, get 1, and then add one
;DEC BX
;NOT BX
;INC BX
CALL change_turn
MOV [CUR_TURN],BL ;update next turn
EX_EXIT:
RET

change_turn:
CMP BX,1
JE ct1
JMP ct2

ct1:
MOV BX,2
RET

ct2:
MOV BX,1
RET

DrawBoard:
MOV AH,0x0C ;set interrupt mode
MOV AL,BOARD_COLOUR ;set board colour
MOV BH, 0 ;page number NB: we are using BX as a general use register
;it shouldn't matter though, if it does, we'll have to set this specifically everytime
MOV CX, START_X ;start coords
MOV DX, START_Y

;set limits for line lengths
MOV BX,BOARD_SIZE

;draw first vertical lines
ADD CX,PIECE_SIZE ;set x to place we want to draw first line
CALL DrawVertLine

;draw next one
MOV DX,START_Y ;reset y position
ADD CX,PIECE_SIZE ;set x to next place we want to draw a line
CALL DrawVertLine

;draw first horiz line
MOV DX,START_Y ;reset y position
ADD DX,PIECE_SIZE ;set y to place we want to draw first horiz line
MOV CX,START_X ;reset x position
CALL DrawHorizLine

MOV CX,START_X ;reset x position
ADD DX,PIECE_SIZE ;set y to next place to draw a line
CALL DrawHorizLine

;draw pieces

MOV AL,0x03 ;set colour of pieces

MOV WORD [TEMP_S],AX

;draw every piece on the board
MOV SI,BOARD ;move pointer to board into SI register
;Initialize X and Y positions
MOV CX,START_X+5
MOV DX,START_Y+5
DRAW_LOOP:
MOVZX BX, [SI] ; get piece at current position
CMP BX,9 ;make sure we aren't at the end
JE DB_QUIT ;if we are, then quit -- we are done
INC SI ;move SI across one
CALL DrawIf
ADD CX,PIECE_SIZE ;if we are at the end of the first row, we'll need to increment DX too...
;if we're at 3 or 6 of the BOARD, we want to increment DX
MOV AX,SI ;use AX as a comparison register (easier)
SUB AX,BOARD ;get difference between start and current pos (start-end)
CMP AX,3 ;check if we are at the 3rd 
JE INC_DX
CMP AX,6 ;or the sixth
JE INC_DX
MOV AX,[TEMP_S] ;AX is needed internally it seems, so make sure we leave it untouched
JMP DRAW_LOOP

INC_DX:
MOV CX,START_X+5
ADD DX,PIECE_SIZE
MOV AX,[TEMP_S]
JMP DRAW_LOOP

DB_QUIT:
MOV AX,[TEMP_S]
RET

DrawIf: ;draws cross, X, or nothing depending on value in BX
CMP BX,0
JE __QUIT
CMP BX,1
JE __DRAWX
CMP BX,2
JE __DRAWCROSS
;JMP __DRAWCROSS
RET

__DRAWX:
CALL DrawX
RET

__DRAWCROSS:
Call DrawCross
RET

DrawVertLine: ;draws vertical line
;assumes everything is set, but it's not a unlinked subroutine
INT 0x10 ;call BIOS service
INC DX
CMP DX,BX
JE __QUIT
JMP DrawVertLine

DrawHorizLine: ;draws horiz line
;assumes errything is set
INT 0x10
INC CX
CMP CX,BX
JE __QUIT
JMP DrawHorizLine

DrawX: ;draws an X
;make max dist for first diagonal
;relative to where we start
MOV [STARTY__],DX
MOV [STARTX__],CX
MOV BX, CX
ADD BX, PIECE_SIZE-10
DRAW_FIRST_DIAG:
INT 0x10 ;draw
ADD CX, 1
ADD DX, 1
CMP CX,BX
JE DRAW_NEXT_DIAG_S
JMP DRAW_FIRST_DIAG

DRAW_NEXT_DIAG_S:
MOV DX,[STARTY__]
MOV BX,DX
ADD BX,PIECE_SIZE-10
DRAW_NEXT_DIAG:
INT 0x10 ;draw
SUB CX,1
ADD DX,1
CMP DX,BX
JE CR_QUIT
JMP DRAW_NEXT_DIAG

CR_QUIT: ;put DX and CX back to original positions
MOV DX,[STARTY__]
MOV CX,[STARTX__]
RET


DrawCross: ;draws a cross
MOV [STARTX__],CX
MOV [STARTY__],DX
ADD DX,(PIECE_SIZE/2)-5 ;set position to draw in middle of piece
MOV BX,CX ;ensure we quit correctly by making quit position relative to beginning
ADD BX,PIECE_SIZE-10
CALL DrawHorizLine
SUB DX,(PIECE_SIZE/2)-5
MOV CX,[STARTX__] ;move x position back to start again
MOV BX,DX ;make end position relative to beginning
ADD BX,PIECE_SIZE-10
ADD CX,(PIECE_SIZE/2)-5
CALL DrawVertLine

;put CX and DX back to original positions
MOV CX,[STARTX__]
MOV DX,[STARTY__]

__QUIT:
RET

ClearScreen: ;clears the whole screen
MOV AH,0x07 ;scroll down window
MOV AL,0x00 ;clear the screen
MOV BH,0x10 ;background colour
MOV BL,0x02 ;foreground colour
MOV CH,0 ;upper row number
MOV CL,0 ;left column number
MOV DH,200 ;lower row number
MOV DL,200 ;rightmost column number
INT 0x10 ;call BIOS service
RET

PrintString: ;procedure to print a screen to screen
;using interrupt 10h and the string printing function of it.
MOV AH, 0x13 ;tell bios we want to print a string
MOV AL, 0x00 ;write mode
MOV BH, 0x00 ;page number
MOV BL, 0x07 ;Text attribute 0x07, grey font, black background
MOV CX, SIZE ;CX, size of string to print
MOV DH, 0 ;row
MOV DL, 0 ;column
MOV BP, StrToPrint
INT 0x10
RET

;Data
StrToPrint db 'Hello, World', 0 ;HelloWorld string ending with 0 (null byte)
STARTX__ dw 0
STARTY__ dw 0
TEMP_S dw 0
CUR_TURN db 1
BOARD TIMES 9 db 0 ;reserve 9 bytes for board
db 9 ;end point for BOARD (???)

TIMES 510 - ($ - $$) db 0 ;Fill the rest of the sector with 0
DW 0xAA55 ;add boot signature at the end of the boot sector
