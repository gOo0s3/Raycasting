.486	; omg trigo and stuff (80486 preprocessor)
IDEAL
MODEL compact
STACK 100h
jumps

SEGMENT data1
; --------------------------
; Your variables here
; --------------------------

SCREENWIDTH 		dw 320	; screen width constant
; SCREENHEIGHT 		dw 200	; screen height constant

HALFSCREENWIDTH		dw 160	; half of the screen width constant
; HALFSCREENHEIGHT	dw 100	; half of the screen height constant

HALFSCREENWIDTHd	dd 160	; half of the screen width constant
; HALFSCREENHEIGHTd	dd 100	; half of the screen height constant

playerX dd ?	; player X position on screen
playerY dd ?	; player Y position on screen

dirX dd ?		; player X direction vector 
dirY dd ?		; player Y direction vector

Vx	dd ?		; player X direction velocity
Vy	dd ?		; player Y direction velocity

mapEditorMode db 0	; 0 or 1- indicating if user is in map editing mode

; STRING db '0', '0', '0', '0', '$'	; DELETEEEEEEEEEEEEEEEEEEEEEEEE
playerColor db 5	; the player's color (originally 2)
dirColor 	db 6	; the player's direction color (originally 0Ch)
wallColor	db 1	; the wall's color in bmp file, for collision
backgroundColor db 0 ; the background's color in bmp file, for cheking for collision
playerWallColor	db 7	; player's placed walls color in bmp file, for collision
randomColor	db 42
; sizeOfDir 	dw 20

; ----------- IMAGE LOAD -----------
	filename db 'maze.bmp', 0		;
	filehandle dw ?					;
	Header db 54 dup (0)			;
	Palette db 256*4 dup (0)		;
	ScrLine db 320 dup (0)			;
	ErrorMsg db 'Error', 13, 10 ,'$';
; ----------- IMAGE LOAD -----------


; TRIGO

temp 	db ?
tempW 	dw ?
tempD 	dd ?
tempD2	dd ?

res		dd 4	; casting resolution (size of rects)
V		dd 1	; player velocity
FOV		dd 60	; player's field of view
alpha	dd ?	; current ray's angle
rayX	dd ?	; current ray's x direction
rayY	dd ?	; current ray's y direction
rayTipX dd ?	; current ray's x tip
rayTipY dd ?	; current ray's y tip
distance dd ?	; current ray's tip distance from player
height	dd ?	; current ray's rectangle's height
X		dd 0	; yuval's variable (POG)

R 		dd 10	; rotation radius
angle 	dd 0	; player direction angle	
rotSen	dd 1	; rotation sensitivity

SCREENWIDTHd 		dd 320	; screen width constant
SCREENHEIGHTd 		dd 200	; screen height constant

degrad dd ?		; degree to radian: pi / 180 (1 degree in radians)

__1  dd -1
_0 	 dd 0
_1 	 dd 1
_2 	 dd 2
_100 dd 100
_160 dd 160
_180 dd 180
_360 dd 360

ENDS data1

SEGMENT boardSeg

board db 64000 dup (?)

ENDS boardSeg

CODESEG

assume ds:data1


; ================================================================================
; =									 IMAGE LOAD									 =
; ================================================================================

proc OpenFile
    ; Open file
    mov ah, 3Dh
    xor al, al
    ; mov dx, offset filename
    int 21h
    jc openerror
    mov [filehandle], ax
    ret
openerror:
    mov dx, offset ErrorMsg
    mov ah, 9h
    int 21h
    ret
endp OpenFile

proc ReadHeader
    ; Read BMP file header, 54 bytes
    mov ah,3fh
    mov bx, [filehandle]
    mov cx,54
    mov dx,offset Header
    int 21h
    ret
endp ReadHeader

proc ReadPalette
    ; Read BMP file color palette, 256 colors * 4 bytes (400h)
    mov ah,3fh
    mov cx,400h
    mov dx,offset Palette
    int 21h
    ret
endp ReadPalette

proc CopyPal
    ; Copy the colors palette to the video memory
    ; The number of the first color should be sent to port 3C8h
    ; The palette is sent to port 3C9h
    mov si,offset Palette
    mov cx,256
    mov dx,3C8h
    mov al,0
    ; Copy starting color to port 3C8h
    out dx,al
    ; Copy palette itself to port 3C9h
    inc dx
PalLoop:
    ; Note: Colors in a BMP file are saved as BGR values rather than RGB .
    mov al,[si+2] ; Get red value .
    shr al,2 ; Max. is 255, but video palette maximal
    ; value is 63. Therefore dividing by 4.
    out dx,al ; Send it .
    mov al,[si+1] ; Get green value .
    shr al,2
    out dx,al ; Send it .
    mov al,[si] ; Get blue value .
    shr al,2
    out dx,al ; Send it .
    add si,4 ; Point to next color .
    ; (There is a null chr. after every color.)

    loop PalLoop
    ret
endp CopyPal

proc CopyBitmap
    ; BMP graphics are saved upside-down .
    ; Read the graphic line by line (200 lines in VGA format),
    ; displaying the lines from bottom to top.
    push ds
    mov ax, boardSeg
    mov ds, ax
    ; mov ax, ds
    mov es, ax
    mov cx, 199

	mov di, offset board
	add di, 200*320
    pop ds
PrintBMPLoop:
    push cx
    ; di = offset board + cx*320, point to the correct board line
	sub di, 320


    ; Read one line
    mov ah, 3fh
    mov cx, 320
    mov dx, offset ScrLine
    int 21h
    ; Copy one line into video memory
    cld ; Clear direction flag, for movsb

    mov cx, 320
    mov si, offset ScrLine

	push di
    rep movsb ; Copy line to the screen
    ;rep movsb is same as the following code :
    ;mov es:di, ds:si
    ;inc si
    ;inc di
    ;dec cx
    ;loop until cx=0
	pop di

    pop cx
    loop PrintBMPLoop

    ret
endp CopyBitmap


proc loadImage
    ; Process BMP file, load it into [board]

    ; ds:dx = filename pointer
    call OpenFile
    call ReadHeader
    call ReadPalette
    call CopyPal
    call CopyBitmap


    ret
endp loadImage

proc drawBoard
	pusha
	; draw [board]
	; copy [board] to video memory
    push ds
    mov ax, boardSeg
    mov ds, ax

	mov ax, 0A000h	; ex = video memory start
	mov es, ax

	mov di, 0
	mov si, offset board
	
	mov cx, 320*200
	cld
	rep movsb	; mov es:di, ds:si

    pop ds
	popa
	ret
endp drawBoard

; ================================================================================
; =									 IMAGE LOAD									 =
; ================================================================================


proc rayCast
	; omg literally raycasting in x86 assembly omg WOW.

	; initiallize alpha, alpha = angle + (fov / 2)
	fild [FOV]
	fidiv [_2]
	fiadd [angle]

	; convert alpha to radians (alpha = pi/180 * alpha)
	fmul [degrad]

	fstp [alpha]	; store in alpha

	; reset X (we spent about 6 hours figuring that out)

	xor [X], [X]

	; loop screenWidth / res times
	fild [SCREENWIDTHd]
	fidiv [res]
	fistp [tempD]

	; start ray casting loop! (omg so cool OwO)
	mov cx, [word ptr tempD]

rayLoop:
	push cx

	; init ray direction tips
	; rayTipX = playerX
	fld [playerX]
	fstp [rayTipX]

	; rayTipY = playerY
	fld [playerY]
	fstp [rayTipY]



	; init ray's direction
	; rayX = sin(alpha)
	fld [alpha]
	fsin
	fstp [rayX]

	; rayY = cos(alpha)
	fld [alpha]
	fcos
	fstp [rayY]


rayForwardLoop:
	; move ray forward until collision

	; move ray forward
	fld [rayTipX]
	fadd [rayX]
	fstp [rayTipX]

	fld [rayTipY]
	fadd [rayY]
	fstp [rayTipY]

	; draw pixel (only if editor mode is enabled)

	mov al, [mapEditorMode]	; if editor mode is disabled, dont draw pixels
	cmp al, 0
	je continueRayCast_


	mov al, [dirColor]		; color
	mov bh, 0
	fld [rayTipX]
	fistp [tempD]
	mov cx, [word ptr tempD]	; X
	fld [rayTipY]
	fistp [tempD]
	mov dx, [word ptr tempD]	; Y

	mov ah, 0Ch			; DRAW PIXEL
	int 10h
	
continueRayCast_:

	; CHECK FOR COLLISION

	fld [rayTipY]			; Y
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [rayTipX]			; X

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds

	cmp al, [backgroundColor]
	je rayForwardLoop

	; ray has hit wall!

	; if editor mode is disabled, draw rect. if not, skip next code
	mov al, [mapEditorMode]	; if editor mode is disabled, dont draw pixels
	cmp al, 0
	jne continueRayLoop


	; calculate distance
	; distance = sqrt((playerX - rayTipX)² + (playerY - PlayerTipY)²) * cos(alpha - angle)
	fld [rayTipX]
	fsub [playerX]
	fst [tempD]
	fmul [tempD]
	fstp [distance]	; TEMPORARILY! Distance is not complete yet.

	fld [rayTipY]
	fsub [playerY]
	fst [tempD]
	fmul [tempD]

	fadd [distance]
	fsqrt
	; fmul [rayY]	; rayY = cos(alpha)

	fstp [distance]


	fild [angle]
	fmul [degrad]
	fsub [alpha]
	fcos

	; fabs
	fmul [distance]
	fstp [distance]

	; calculate height
	; height = (some big num) / distance

	fild [_180]
	fimul [_2]
	fimul [_2]
	fimul [_2]

	fdiv [distance]
	fstp [height]

	; limit height to screenHeight)
	fld [height]
	fimul [_2]
	fistp [tempD]

	mov cx, [word ptr tempD]
	mov dx, [word ptr SCREENHEIGHTd]
	cmp cx, dx			; compare height*2 and screen height.
	jb continueRayCast	; if height*2 is lower, skip next code.

	; if height*2 is higher than screen height, set height to be screen height / 2
	
	fild [SCREENHEIGHTd]
	fidiv [_2]
	fstp [height]

continueRayCast:


	; draw the rect on the screen! omg so exciting
	call drawRect
	
continueRayLoop:
	; decrease alpha by fov * res / screenwidth (in radians)
	fild [fov]
	fimul [res]
	fidiv [SCREENWIDTHd]
	fmul [degrad]
	fimul [__1]
	fadd [alpha]
	fstp [alpha]

	; fild [_2]
	; fiadd [_2]
	; fiadd [_2]
	; fiadd [_2]
	; fiadd [_2]
	
	fild [res]
	fiadd [X]
	fistp [X]


	pop cx
	loop rayLoop
	
	ret
endp rayCast


proc drawRect
	; draws rect from (X, screenHeight / 2 - height) with width = [res] and height = [height]

	mov ax, 0A000h	; load directly to video memory
	mov es, ax
	
	; calculate "breakpoints" (when to change rect color)

	; bx = first index to draw rect color. (screenHeight / 2 - height ) * screenWidth + X
	fild [SCREENHEIGHTd]
	fidiv [_2]
	fsub [height]
	fistp [tempD]
	fild [tempD]
	fimul [SCREENWIDTHd]
	fiadd [X]
	fistp [tempD]
	mov bx, [word ptr tempD]
	
	; dx = first index to draw background color. bx + int(2 * height)
	fild [SCREENHEIGHTd]
	fidiv [_2]
	fadd [height]
	fistp [tempD]
	fild [tempD]
	fimul [SCREENWIDTHd]
	fiadd [X]
	fistp [tempD]
	mov dx, [word ptr tempD]

	mov al, 4		; initialize color as SKY COLOR

	mov di, [word ptr X]	; init index

	mov cx, [word ptr SCREENHEIGHTd]	; loop screen height times
drawRectY:
	push cx

	cmp di, bx
	je changeToColor
	
	cmp di, dx
	je changeToBackground

	jmp continueYLoop


changeToColor:
	; calculate color
	; color index = 63 - distance * 63 / screenwidth + 10
	mov [tempD], 0
	mov [word ptr tempD], 63

	fld [distance]
	fimul [tempD]
	fidiv [SCREENWIDTHd]

	fimul [__1]
	fiadd [tempD]	

	mov [word ptr tempD], 10
	fiadd [tempD]
	fistp [tempD]
	mov al, [byte ptr tempD]
	
	jmp continueYLoop

changeToBackground:
	mov al, 5		; GROUND COLOR
	jmp continueYLoop

continueYLoop:
	mov cx, [word ptr res]
	drawRectX:
		push cx
		
		mov [byte ptr es:di], al

		inc di
		pop cx
		loop drawRectX


	; add Y to index (screenWidth - res)
	add di, [SCREENWIDTH]
	sub di, [word ptr res]

	pop cx
	loop drawRectY

	ret
endp drawRect


; proc drawRect
; 	; draws rect from (X, screenHeight / 2 - height) with width = [res] and height = [height]

; 	mov ax, 0A000h	; load directly to video memory
; 	mov es, ax
	
; 	; calculate color
; 	; color index = 63 - distance * 63 / screenwidth + 10
; 	mov [tempD], 0
; 	mov [word ptr tempD], 63

; 	fld [distance]
; 	fimul [tempD]
; 	fidiv [SCREENWIDTHd]

; 	fimul [__1]
; 	fiadd [tempD]
; 	; mov [tempD], 0
	

; 	mov [word ptr tempD], 10
; 	fiadd [tempD]
; 	fistp [tempD]
; 	mov al, [byte ptr tempD]

; 	; load initial index to bx (int(y) * screenWidth + x)

; 	fild [SCREENHEIGHTd]
; 	fidiv [_2]
; 	fsub [height]
; 	fistp [tempD]
; 	fild [tempD]

; 	fimul [SCREENWIDTHd]
; 	fiadd [X]
; 	fistp [tempD]
; 	mov bx, [word ptr tempD]

; 	fld [height]
; 	fimul [_2]
; 	fisub [_1]
; 	fistp [tempD]
; 	mov cx, [word ptr tempD]
; drawRectY:
; 	push cx

; 	mov cx, [word ptr res]
; 	drawRectX:
; 		push cx
		
; 		mov [byte ptr es:bx], al

; 		inc bx
; 		pop cx
; 		loop drawRectX


; 	; add Y to index (screenWidth - res)
; 	add bx, [SCREENWIDTH]
; 	sub bx, [word ptr res]
; 	pop cx
; 	loop drawRectY

; 	ret
; endp drawRect


; proc printAx
; 	push ax

; 	mov ax, 2h	; text mode
; 	int 10h

; 	pop ax

; 	; print ax
; 	mov di, offset STRING
; 	mov bx, 2
; 	mov cx, 3

; 	mov dl, 10
; fff:
; 	cmp ax, 0
; 	je printSTRING

; 	div dl		; al = ax / 10, ah = ax mod 10
; 	mov [byte ptr di+bx + 1], ah
; 	add [byte ptr di+bx + 1], '0'
; 	dec bx
; 	xor ah, ah
; 	loop fff



; printSTRING:
; 	lea dx, [STRING]
; 	mov ah, 9h
; 	int 21h

; 	mov [STRING + 1], ' '
; 	mov [STRING + 2], ' '
; 	mov [STRING + 3], '0'

; 	mov ah, 1h
; 	int 21h

; 	jmp exit
; 	ret
; endp printAx

; proc drawBackground
; 	; draw background
	
; 	mov ax, 0013h	; enter graphic mode
; 	int 10h
	
; 	ret
; endp drawBackground


proc drawPlayer
	pusha

	; draw player
	mov al, [playerColor]		; color

	mov bh, 0

	fld [playerX]
	fistp [tempD]
	mov cx, [word ptr tempD]	; X

	fld [playerY]
	fistp [tempD]
	mov dx, [word ptr tempD]	; Y

	mov ah, 0Ch			; DRAW PIXEL
	int 10h

	popa
	ret
endp drawPlayer

; proc drawDir
; 	; draw direction
	
; 	pusha
; 	; store player color and position
; 	mov bl, [playerColor]
	
; 	fld [playerX]	; save player position in stack
; 	fld [playerY]

; 	; replace player color with direction color
; 	mov al, [dirColor]
; 	mov [playerColor], al

; 	; move player [sizeOfDir] times and draw
; 	mov cx, [sizeOfDir]
; drawDirLoop:
; 	fld [playerX]
; 	fadd [vX]
; 	fstp [playerX]

; 	fld [playerY]
; 	fadd [vY]
; 	fstp [playerY]

; 	call drawPlayer

; 	loop drawDirLoop
	
; 	; restore player color
; 	mov [playerColor], bl


; 	; restore player position
; 	fstp [playerY]
; 	fstp [playerX]

; 	popa
; 	ret
; endp drawDir

proc deleteTrail
	; DELETE trail

; 	mov ax, 0A000h
; 	mov es, ax
; 	mov bx, 0
; 	mov cx, 320*200
; deleteTrailLoop:
; 	mov [byte ptr es:bx], 1	; clear pixel
; 	inc bx
; 	loop deleteTrailLoop



	call drawBoard

	; mov bl, [playerColor]
	; mov bh, [dirColor]
	; mov [playerColor], 0
	; mov [dirColor], 0
	; call drawPlayer
	; call drawDir
	; mov [playerColor], bl
	; mov [dirColor], bh
	ret
endp deleteTrail

proc toggleEditorMode
	; toggle editor mode
	cmp [mapEditorMode], 0
	jne disableEditorMode

enableEditorMode:
	mov [mapEditorMode], 1
	
	; show mouse cursor
	mov ax, 1h
	int 33h

	jmp exitToggleEditorMode

disableEditorMode:
	mov [mapEditorMode], 0

	; hide mouse cursor (mouse reset)
	mov ax, 0h
	int 33h

	jmp exitToggleEditorMode

exitToggleEditorMode:
	call updateScreen

	ret
endp toggleEditorMode

proc rotate
	; update player rotation based on [angle]
	call updateScreen

	; if angle is bigger than 180, sub 360 
	mov ax, [word ptr angle]
	cmp ax, 180
	jge above180

	; if angle is less than 180, add 360 
	cmp ax, -180
	jle below180

	jmp continueRot

above180:
	fild [angle]
	fisub [_360]
	fistp [angle]

	; sub [word ptr angle], 360
	jmp continueRot

below180:
	fild [angle]
	fiadd [_360]
	fistp [angle]

	; add [word ptr angle], 360
	jmp continueRot

continueRot:
	fld [degrad]
	fimul [angle]
	fsin
	fst [vX]
	fimul [R]
	fstp [dirX]


	fld [degrad]
	fimul [angle]
	fcos
	fst [vY]
	fimul [R]
	fstp [dirY]

	ret
endp rotate

proc createShades
; changes the color pallete
; change colors 10-73 to be shades of grey (black to white)
	mov ax, 1010h ; Video BIOS function to change palette color
	mov bx, 10 ; color number 5
	mov dh, 0 ; red color value (0-63, not 0-255!)
	mov ch, 0 ; green color component (0-63)
	mov cl, 0 ; blue color component (0-63)

	loopColors:
		int 10h ; Video BIOS interrupt
		inc bx ; color number 5
		inc dh ; red color value (0-63, not 0-255!)
		inc ch ; green color component (0-63)
		inc cl ; blue color component (0-63)

		cmp cl, 64
		jne loopColors

	ret
endp createShades



proc handleMouse
	mov ax, 03h		; GET MOUSE INFO
	int 33h			; CX = X (0-639), DX = Y (0-199)

	shr cx, 1		; div cx by 2 so it is in range of (0-319)

	; if map editor mode is enabled
	cmp [mapEditorMode], 0
	jne handleMouseMapEditor

	; if map editor mode is disabled
	jmp handleMouseRayCast
handleMouseMapEditor:
	test bx, 1			      ; check left mouse click
	jz continueHandleMouse    ; if not skip next code

	; if left clicked, place a wall
	push cx
	push dx
	call placeWall
	; update screen
	call updateScreen
	; skip rotation
	jmp exitHandleMouse

continueHandleMouse:
	test bx, 2			      ; check right mouse click
	jz exitHandleMouse   ; if not skip next code

	; if right clicked, remove a wall
	push cx
	push dx
	call removeWall
	
	; update screen
	call updateScreen
	; skip rotation
	jmp exitHandleMouse



handleMouseRayCast:
	; if x is in the middle of the screen, return.
	cmp cx, [HALFSCREENWIDTH]
	je exitHandleMouse

	; if x is not in the middle, rotate accordingly.

	; load mouse pos to stack
	mov [tempD], 0
	mov [word ptr tempD], cx
	fild [tempD]

	; sub the half screen width to get the difference of mouse position
	fisub [HALFSCREENWIDTHd]

	; rotate by difference

	; multiply by [rotSen]
	fimul [rotSen]
	

	; sub to angle and store
	fimul [__1]
	fiadd [angle]
	fistp [angle]

	; rotate
	call rotate



	; SET X to half of screen width
	mov cx, [SCREENWIDTH]
	mov ax, 4		; SET MOUSE POSITION
	int 33h

exitHandleMouse:
	ret
endp handleMouse

proc handleInput
	; check if a key is being pressed, if not, return.
	mov ah, 1h
	int 16h
	jz exitHandleInput
	

	; check which key is being pressed, put ascii value in al
	mov ah, 0h
	int 16h


	; TESTING
	cmp al, ' '
	je space

	; MOVE PLAYER
	cmp al, 'w'
	je forward

	cmp al, 's'
	je backward

	cmp al, 'a'
	je left

	cmp al, 'd'
	je right

	cmp al, 'l'		; rotate right
	je rotateRight

	cmp al, 'j'		; rotate left
	je rotateLeft


	; if the key is ESC, exit
	cmp al, 27  ; 27 = ESC
	je exit

	; if none of the above, return.
	jmp exitHandleInput

space:
	; toggle map editor mode
	call toggleEditorMode
	jmp exitHandleInput

forward:
	; update player position and check for collision (SUPER COOL COLISION OMG YUVAL OMG)

	; change X
	fld [vX]
	fimul [V]
	fadd [playerX]
	fstp [playerX]	


	; check for collision
	fld [playerY]			; Y
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je forwardY	; if player position is not inside wall, skip next code

	; if is in wall, sub X.
	fld [vX]
	fimul [__1]
	fimul [V]
	fadd [playerX]
	fstp [playerX]

forwardY:
	fld [vY]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

	; check for collision
	fld [playerY]
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je continueForward	; if player not in wall exit

	; if is in wall, sub Y.
	fld [vY]
	fimul [__1]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

continueForward:
	; call deleteTrail
	; call rayCast
	call updateScreen
	jmp exitHandleInput


backward:
	; call deleteTrail
	; call rayCast
	call updateScreen


	fld [vX]
	fimul [__1]
	fimul [V]
	fadd [playerX]
	fstp [playerX]
	
	; check for collision
	fld [playerY]			; Y
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je backwardY	; if player position is not inside wall, skip next code

	; if is in wall, sub X.
	fld [vX]
	fimul [V]
	fadd [playerX]
	fstp [playerX]	

backwardY:
	; change Y
	fld [vY]
	fimul [__1]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

	; check for collision
	fld [playerY]
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je continueBackward	; if player not in wall exit

	; if is in wall, sub Y.
	fld [vY]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

continueBackward:
	; call deleteTrail
	; call rayCast
	call updateScreen

	jmp exitHandleInput

left:
	; change X
	fld [vY]
	fimul [V]
	fadd [playerX]
	fstp [playerX]

	; check for collision
	fld [playerY]			; Y
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je leftY	; if player position is not inside wall, skip next code

	; if is in wall, sub X.
	fld [vY]
	fimul [__1]
	fimul [V]
	fadd [playerX]
	fstp [playerX]

leftY:
	; change Y
	fld [vX]
	fimul [__1]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

	; check for collision
	fld [playerY]
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je continueLeft	; if player not in wall exit

	; if is in wall, sub Y.
	fld [vX]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

continueLeft:
	; call deleteTrail
	; call rayCast
	call updateScreen

	jmp exitHandleInput

right:
	; change X
	fld [vY]
	fimul [__1]
	fimul [V]
	fadd [playerX]
	fstp [playerX]

	; check for collision
	fld [playerY]			; Y
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je rightY	; if player position is not inside wall, skip next code

	; if is in wall, sub X.
	fld [vY]
	fimul [V]
	fadd [playerX]
	fstp [playerX]

rightY:
	; change Y
	fld [vX]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

	; check for collision
	fld [playerY]
	fistp [tempD]
	fild [tempD]

	fimul [SCREENWIDTHd]
	fadd [playerX]

	fistp [tempD]
	mov bx, [word ptr tempD]

    push ds
    mov ax, boardSeg
    mov ds, ax
	mov di, offset board
	mov al, [di + bx]	; al = color in board, in player's position
    pop ds


	cmp al, [backgroundColor]
	je continueRight	; if player not in wall exit

	; if is in wall, sub Y.
	fld [vX]
	fimul [__1]
	fimul [V]
	fadd [playerY]
	fstp [playerY]

continueRight:
	; call deleteTrail
	; call rayCast
	call updateScreen

	jmp exitHandleInput

rotateRight:
	fild [angle]
	fisub [rotSen]
	fistp [angle]

	jmp rotate

rotateLeft:
	fild [angle]
	fiadd [rotSen]
	fistp [angle]
	
	jmp rotate

continueRotate:
	call rotate

	jmp exitHandleInput

exitHandleInput:
	ret
endp handleInput

proc updateScreen
	; draw board- depending if editor mode is enabled or not.


	mov al, [mapEditorMode]
	cmp al, 0
	jne editorModeEnabled

editorModeDisabled:
	; if editor mode is disabled, call raycast
	call rayCast
	jmp exitUpdateScreen

editorModeEnabled:
	; if editor mode is enabled, draw the board, draw the player, and ray cast (draw the rays)
	call deleteTrail
	call rayCast
	call drawPlayer
	jmp exitUpdateScreen

exitUpdateScreen:

	ret
endp updateScreen

mouseX equ [word ptr bp+6]
mouseY equ [word ptr bp+4]
proc placeWall
	; args: mouse X, mouse Y (through stack)
	; place a wall in mouse position (used in editor mode!)
	push bp
	mov bp, sp

	; calc index: screenwidth * mouseY + mouseX
	mov ax, mouseY		; ax = mouseY
	mov bx, [SCREENWIDTH]
	mul bx	; dx:ax = mouseY * screenwidth (lower bits will be in ax, which is what we need)
	add ax, mouseX
	
	mov bx, ax

	mov al, [playerWallColor]

	push ds
	mov cx, boardSeg
	mov ds, cx
	mov di, offset board
	
	mov cl, [byte ptr di+bx]	; move color to bl, check for collision

	pop ds
	
	cmp cl, [wallColor]
	je exitPlaceWall

	push ds
	mov cx, boardSeg
	mov ds, cx
	mov [byte ptr di+bx], al
	pop ds

	; ; place a wall in front of player

	; ; check player's forward location in board
	; ; index = int(y + dirY) * width + (x + dirX)
	; fld [playerY]
	; fadd [dirY]
	; fistp [tempD]
	; fild [tempD]
	; fimul [SCREENWIDTHd]
	; fadd [playerX]
	; fadd [dirX]
	; fistp [tempD]
	; mov bx, [word ptr tempD]

	; mov di, offset board
	; mov al, [byte ptr di + bx]	; al = color in board, in front of player's position

	; mov dl, [wallColor]
	; mov [byte ptr di+bx], dl

exitPlaceWall:
	pop bp
	ret 4
endp placeWall

proc removeWall
	; args: mouse X, mouse Y (through stack)
	; removes a wall in mouse position (used in editor mode!)
	push bp
	mov bp, sp

	mov ah, 1h
	int 16h

	; save wall color, change it to background color, place a block, and restore wall color
	xor ax, ax
	mov al, [playerWallColor]
	push ax

	mov al, [backgroundColor]
	mov [playerWallColor], al

	push mouseX
	push mouseY
	call placeWall

	pop ax
	mov [playerWallColor], al

	pop bp
	ret 4
endp removeWall

start:

	mov ax, data1
	mov ds, ax

	finit	; initialize the FPU
	
	; set starting player position
	fild [_160]
	fstp [playerX]
	fild [_100]
	fstp [playerY]

	; init degrad (pi / 180)
	fldpi
	fidiv [_180]
	fstp [degrad]

	mov ax, 0013h	; enter graphic mode
	int 10h

	; load image
    mov dx, offset filename
    call loadImage

	call drawBoard


	; change color pallete

	mov ax, 1010h ; Video BIOS function to change palette color
	mov bx, 7 ; playerWallColor - purple
	mov dh, 63 ; red color value (0-63, not 0-255!)
	mov ch, 0 ; green color component (0-63)
	mov cl, 63 ; blue color component (0-63)
	int 10h ; Video BIOS interrupt

	mov ax, 1010h ; Video BIOS function to change palette color
	mov bx, 4 ; color number 4 - sky color
	mov dh, 1 ; red color value (0-63, not 0-255!)
	mov ch, 42 ; green color component (0-63)
	mov cl, 49 ; blue color component (0-63)
	int 10h ; Video BIOS interrupt

	mov bx, 5 ; color number 5 - green
	mov dh, 0 ; red color value (0-63, not 0-255!)
	mov ch, 40 ; green color component (0-63)
	mov cl, 0 ; blue color component (0-63)
	int 10h ; Video BIOS interrupt

	mov bx, 6 ; color number 6 - pink
	mov dh, 60 ; red color value (0-63, not 0-255!)
	mov ch, 0 ; green color component (0-63)
	mov cl, 30 ; blue color component (0-63)
	int 10h ; Video BIOS interrupt

	mov bx, 8 ; color number 8 - white
	mov dh, 63 ; red color value (0-63, not 0-255!)
	mov ch, 63 ; green color component (0-63)
	mov cl, 63 ; blue color component (0-63)
	int 10h ; Video BIOS interrupt

	call createShades

	mov ax, 0		; reset mouse (thank you lior sharon)
	int 33h


	; set starting direction
	call rotate

mainloop:

	call handleInput
	call handleMouse

	jmp mainloop
	
	
exit:
	mov ax, 0002h	; exit graphic mode (enter text mode)
	int 10h
	
	mov ax, 4c00h
	int 21h
END start
