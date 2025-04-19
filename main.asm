[org 0x0100]
	jmp start

mapfilename:
	db "map.bmp", 0

infobuffer:
	times 140 db 0

mappixels:
	times 500 db 0

colors:
	times 4*256 db 0		; each color is 4 bytes
					; in (B, G, R, 0x00) format
	; 53 here is the result of (200 - 94) / 2
ghostpositions:
	dw 20*320+193+53*320, 37*320+182+53*320
	dw 37*320+193+53*320, 37*320+204+53*320

pacmanposition:
	dw 75*320+193+53*320		; this should have been 74*320+193+53*320, but it was one pixel too close to the dots

ghostcolors:
	dw 0x28, 0x35, 0x58, 0xe

ghostfigure:
;             v-----image stops here, from the 12th column onwards
dw 0000000000000000b
dw 0001111100000000b
dw 0011111110000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0110111011000000b
dw 0100010001000000b
dw 0000000000000000b

chasepacman:
; logic should go something like this
; def chasepacman(ghost num):
;     if pacman is below ghost:
;         if ghost can move down:
;             move down
;         elif pacman is to the left and there is space to the left:
;             move left
;         elif there is space to the right:
;             move right
;         elif there is space above:
;             move up
;         elif there is space to the left:
;             move left
;     elif pacman is above ghost:
;         if ghost can move up:
;             move up
;         elif pacman is to the left and there is space to the left:
;             move left
;         elif there is space to the right:
;             move right
;         elif there is space below:
;             move down
;         elif there is space to the left:
;             move left
;     elif pacman is directly to the left:
;         if ghost can move left:
;             move left
;         elif pacman is above the ghost and there is space above:
;             move up
;         elif there is space below:
;             move down
;         elif there is a space to the right:
;             move down
;         elif there is space above:
;             move up
;     else:
;         if ghost can move right:
;             move right
;         elif pacman is above the ghost and there is space above:
;             move up
;         elif there is space below:
;             move down
;         elif there is a space to the left:
;             move left
;         elif there is space above:
;             move up


	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push di
	push si

	push 0xa000
	pop es

	push word[bp+4]
	call eraseghost

	mov bx, [bp+4]
	add bx, ghostpositions
	mov di, [bx]
	sub di, 53*320			; di now stores the position of the
					; selected ghost relative to the top 
					; left corner of the map, not 0xa0000

	mov si, [pacmanposition]
	sub si, 53*320			; si now stores the position of Pac-Man
					; , the same as above

	mov bx, 320
	mov ax, di
	mov dx, 0
	div bx
	mov cx, dx			; cx -> ghost.x
	mov dx, ax			; dx -> ghost.y

	push dx

	mov ax, si
	mov dx, 0
	div bx
	push ax
	push dx
	pop ax				; ax -> pacman.x
	pop bx				; bx -> pacman.y

	pop dx				; dx -> ghost.y again
					; we no longer need si to store
					; Pac-Man's position

	add di, 53*320

	; compare pacman and ghost positions here
	cmp bx, dx
	jb pacmanisbelow
	ja pacmanisabove

	cmp ax, cx
	jb pacmanistotheleft
	ja pacmanistotheright

	push word[bp+4]
	call eraseghost

pacmanisabove:
	push di
	add di, 320
	push 0				; [bp-16]
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchaseup
	pop di
	pop di

	cmp ax, cx
	jb pacmanistotheleft
	jmp pacmanistotheright

pacmanisbelow:
	push di
	sub di, 320
	push 0				; [bp-16]
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchasedown
	pop di
	pop di

	cmp ax, cx
	jb pacmanistotheleft
	jmp pacmanistotheright

pacmanistotheleft:
	push di
	push 0				; [bp-16]
	sub di, 1
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchaseleft
	pop di
	pop di

	push di
	sub di, 320
	push 0				; [bp-16]
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchasedown
	pop di
	pop di

	push di
	add di, 320
	push 0				; [bp-16]
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchaseup
	pop di
	pop di

	jmp ghostchaseright


pacmanistotheright:
	push di
	push 0				; [bp-16]
	add di, 1
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchaseleft
	pop di
	pop di

	push di
	sub di, 320
	push 0				; [bp-16]
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchasedown
	pop di
	pop di

	push di
	add di, 320
	push 0				; [bp-16]
	push di
	call ghostcollision
	cmp word[bp-16], 0
	je ghostchaseup
	pop di
	pop di

	jmp ghostchaseleft



ghostchaseleft:
	pop di
	pop di
	push 0
	push word[bp+4]
	call moveghost
	jmp exitchasepacman
ghostchaseright:
	pop di
	pop di
	push 1
	push word[bp+4]
	call moveghost
	jmp exitchasepacman
ghostchaseup:
	pop di
	pop di
	push 3
	push word[bp+4]
	call moveghost
	jmp exitchasepacman
ghostchasedown:
	pop di
	pop di
	push 2
	push word[bp+4]
	call moveghost
	jmp exitchasepacman

exitchasepacman:
	pop si
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 2

drawghost:
	; takes two arguments, top-left pixel location, and color
	push bp
	mov bp, sp
	push ax
	push es
	push ds
	push si
	push di

	push 0xa000
	pop es
	mov di, [bp+6]
	push cs
	pop ds
	mov si, ghostfigure

glo:					; ghost loop (outer)
	push 1000000000000000b		; [bp - 12]

gli:					; ghost loop (inner)
	mov ax, [si]
	test ax, [bp-12]
	jz skipwrite

	cmp byte[es:di], 0
	jne skipwrite

	mov al, [bp+4]
	mov [es:di], al

skipwrite:
	inc di
	shr word[bp-12], 1
	cmp word[bp-12], 10000b
	jne gli

	pop ax
	add si, 2
	add di, 320-11
	cmp si, ghostfigure+20
	jng glo

	pop di
	pop si
	pop ds
	pop es
	pop ax
	pop bp
	ret 4

ghostcollision:
; takes two arguments, the return value, and the position
; it assumes the ghost has been erased first
; returns 0 when there is no collision
; returns 1 when there is a collision
	push bp
	mov bp, sp
	push cx
	push es
	push di

	push 0xa000
	pop es
	
	mov di, [bp+4]
	mov cx, 11
gclo:					; ghost collision loop (outer)
	push cx
	mov cx, 11
gcli:					; ghost collision loop (inner)
	cmp byte[es:di], 0
	je continuegcli
	cmp byte[es:di], 2
	je continuegcli
	cmp byte[es:di], 4
	jne gc
continuegcli:
	inc di
	loop gcli
	pop cx
	add di, 320-11
	loop gclo
	jmp gnc

gc:					; ghost collides
	mov word[bp+6], 1
	jmp exitgc
gnc:					; ghost does not collide
	mov word[bp+6], 0
	jmp exitgc

exitgc:
	pop di
	pop es
	pop cx
	pop bp
	ret 2

moveghost:
	; takes two arguments, the direction, and the ghost number
	; (0: left, 1: right, 2: down, 3: up)
	push bp
	mov bp, sp
	push cx
	push es
	push di

	push word[bp+4]
	call eraseghost

	mov di, ghostpositions
	add di, [bp+4]

	cmp word[bp+6], 0
	je ghostleft
	cmp word[bp+6], 1
	je ghostright
	cmp word[bp+6], 2
	je ghostdown
	; assuming default case here (3) (up)
	jmp ghostup

ghostleft:
	sub word[di], 1
	jmp redrawghost

ghostright:
	add word[di], 1
	jmp redrawghost

ghostdown:
	add word[di], 320
	jmp redrawghost

ghostup:
	sub word[di], 320
	jmp redrawghost

redrawghost:
	push word[di]
	mov di, ghostcolors
	add di, [bp+4]
	push word[di]
	call drawghost

	pop di
	pop es
	pop cx
	pop bp
	ret 4

eraseghost:
	push bp
	mov bp, sp
	push bx
	push cx
	push es
	push di

	push 0xa000
	pop es
	mov di, ghostpositions
	add di, [bp+4]
	mov di, [di]

	mov cx, 11
eglo:					; erase ghost loop (outer)
	push cx
	mov cx, 11
egli:					; erase ghost loop (inner)
	mov bx, [bp+4]
	add bx, ghostcolors
	mov bl, byte[bx]
	cmp [es:di], bl
	jne skiperase

	mov byte[es:di], 0

skiperase:
	inc di
	loop egli

	add di, 320-11
	pop cx
	loop eglo
	
	pop di
	pop es
	pop cx
	pop bx
	pop bp
	ret 2

drawghosts:
	push bp
	mov bp, sp
	push si

	mov si, 0

ghostsloop:
	cmp si, 8
	jge exitdrawghostsloop
	push word[ghostpositions+si]
	push word[ghostcolors+si]
	call drawghost
	add si, 2
	jmp ghostsloop

exitdrawghostsloop:
	pop si
	pop bp
	ret

drawmap:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push ds
	push es
	push si
	push di

	mov ax, cs
	mov ds, ax			; set DS
	mov ah, 0x3d			; open existing file
	mov al, 0x00			; read-only
	mov dx, mapfilename		; set DS:DX
	int 0x21
	mov bx, ax			; bx now has file handle

	mov ah, 0x3f			; read from opened file
	mov cx, 138			; read 138 bytes
	mov dx, infobuffer		; into infobuffer
	int 0x21

; drawing loop
; in pseudocode
; func drawmap() {
; 	for (x = no_of_rows; x; --x) {
; 		read file[x] into file_buffer;
; 		for (y = 0; y < no_of_cols; ++y)
; 			es:di = file_bufer[y]
; 		di += no_of_cols;
; 	}
; }

	mov cx, [infobuffer+0x16]	; number of rows
	mov di, 200			; ((window height
	sub di, cx			;  - map height)
	shr di, 1			; / 2)
	mov ax, 320			; window height
	mov dx, 0
	mul di
	mov di, ax
rowloop:
	cmp cx, -1
	je finisheddrawing

	mov ax, [infobuffer+0x12]	; number of columns
	mov dx, 0
	mul cx
	add ax, [infobuffer+0x0a]	; set pointer to start of row
	mov dx, ax			; set DS:DX
	push cx

	mov cx, 0			; CX is MSB
	mov ax, 0x4200			; set current file position, from origin
	int 0x21

	mov cx, [infobuffer+0x12]	; number of columns
	mov ah, 0x3f			; read file
	mov dx, mappixels		; into "mappixels"
	int 0x21
	pop cx

	mov ax, 0xa000
	mov es, ax			; es points to VRAM
	mov si, mappixels		; ds:si points to mappixels' start

	push cx
	mov cx, [infobuffer+0x12]	; repeat for <width> times
	rep movsb
	pop cx

	dec cx
	jmp rowloop
finisheddrawing:
	mov ah, 0x3e			; close map file
	int 0x21

	pop di
	pop si
	pop es
	pop ds
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

loadpalette:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push ds
	push es
	push si
	push di

	mov ax, cs
	mov ds, ax			; set DS
	mov ah, 0x3d			; open existing file
	mov al, 0x00			; read-only
	mov dx, mapfilename		; set DS:DX
	int 0x21
	mov bx, ax			; bx now has file handle

	mov ah, 0x3f			; read from opened file
	mov cx, 138			; read 138 bytes
	mov dx, infobuffer		; into infobuffer
	int 0x21

; loading palette

	mov ax, 0x4200			; set cursor position (offset from origin)
	mov cx, 0			; CX:DX is offset, so CX has to be zero
	mov dx, 14			; cursor to 14 (number of bytes in the header)
	add dx, [infobuffer+0x0e]	; plus the size of the header, in bytes
	int 0x21			; cursor set to palette data in the BMP

	mov ax, 0x3f00			; read
	mov cx, 1024			; the 1 KiB palette from map.bmp
	mov dx, colors			; into "colors"
	int 0x21

	mov si, 0
	mov cx, 7			; number of colors
	push bx
	mov ax, 0x1010			; BIOS function, for INT 10h for changing palette data
paletteloop:
	push cx
	mov bx, si
	mov bh, bl
	shr bl, 2
	mov dh, [colors+si+2]
	shr dh, 2
	mov ch, [colors+si+1]
	shr ch, 2
	mov cl, [colors+si]
	shr cl, 2			; these shr operations exist because color values range between 0-63, not 0-255
	int 0x10
	pop cx
	add si, 4
	loop paletteloop

	pop bx

	mov ah, 0x3e			; close map file
	int 0x21

	pop di
	pop si
	pop es
	pop ds
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

clearscr:
	push bp
	mov bp, sp
	push ax
	push es
	push di

	mov ax, 0xa000
	mov es, ax
	mov di, 0
	mov cx, 320*200
	mov ax, 0
	rep stosb

	pop di
	pop es
	pop ax
	pop bp
	ret


start:
	mov ax, 0x13
	int 0x10

	call loadpalette
	call drawmap
	call drawghosts

moveloop:
	push 0
	call chasepacman
	push 2
	call chasepacman
	push 4
	call chasepacman
	push 6
	call chasepacman
	mov cx, 0xffff
	loop $
	jmp moveloop

	jmp $

exit:
	mov ax, 3
	int 0x10
	mov ax, 0x4c00
	int 0x21
