[org 0x0100]
	jmp start

score:
	dw 0

isgameover:
	db 0

time:
	db 0

scorestring:
	db 'Score:'
	times 5 db 0

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

four:
	dd 4				; this is needed for the modulo

oldkbisr:
	dd 0

oldtimerisr:
	dd 0

pacmanposition:
	dw 75*320+193+53*320		; this should have been 74*320+193+53*320, but it was one pixel too close to the dots

pacmandirection:
	db 0

pacmanclosedmouth:
	db 0

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

pacmanclosedmouthfigure:
dw 0000000000000000b
dw 0001111100000000b
dw 0011111110000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0011111110000000b
dw 0001111100000000b
dw 0000000000000000b

pacmanfigure:
dw 0000000000000000b
dw 0011111100000000b
dw 0111111110000000b
dw 0011111111000000b
dw 0000111111000000b
dw 0000001111000000b
dw 0000111111000000b
dw 0011111111000000b
dw 0111111110000000b
dw 0011111100000000b
dw 0000000000000000b

dw 0000000000000000b
dw 0001111100000000b
dw 0011111110000000b
dw 0111111100000000b
dw 0111111000000000b
dw 0111100000000000b
dw 0111111000000000b
dw 0111111100000000b
dw 0011111110000000b
dw 0001111100000000b
dw 0000000000000000b

dw 0000000000000000b
dw 0001111100000000b
dw 0011111110000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0111101111000000b
dw 0111101111000000b
dw 0111000111000000b
dw 0011000110000000b
dw 0001000100000000b
dw 0000000000000000b

dw 0000000000000000b
dw 0001000100000000b
dw 0011000110000000b
dw 0111000111000000b
dw 0111101111000000b
dw 0111101111000000b
dw 0111111111000000b
dw 0111111111000000b
dw 0011111110000000b
dw 0001111100000000b
dw 0000000000000000b


xorshift_state:
	dd 2527132011			; taken from the output of
					; https://github.com/umireon/my-random-stuff/blob/master/xorshift/splitmix32.c

newkbisr:
	push bp
	mov bp, sp
	push ax

	in al, 0x60

	cmp al, 0x56
	je cmpleft
	cmp al, 0x1e
	je cmpleft
	cmp al, 0x4b
	je cmpleft

	cmp al, 0x7d
	je cmpright
	cmp al, 0x20
	je cmpright
	cmp al, 0x4d
	je cmpright

	cmp al, 0x55
	je cmpdown
	cmp al, 0x1f
	je cmpdown
	cmp al, 0x78
	je cmpdown
	cmp al, 0x50
	je cmpdown

	cmp al, 0x78
	je cmpup
	cmp al, 0x11
	je cmpup
	cmp al, 0x48
	je cmpup

	jmp exitnewkbisr

cmpleft:
	mov byte[pacmandirection], 0
	jmp exitnewkbisr
cmpright:
	mov byte[pacmandirection], 1
	jmp exitnewkbisr
cmpdown:
	mov byte[pacmandirection], 2
	jmp exitnewkbisr
cmpup:
	mov byte[pacmandirection], 3

exitnewkbisr:
	pop ax
	pop bp
	jmp far [cs:oldkbisr]

newtimerisr:
	push bp
	mov bp, sp
	push ax
	inc byte[time]
	cmp byte[isgameover], 0
	jne waitaftergameisover

	push 0
	call checkforgameover
	cmp byte[bp-4], 0
	jne endgame
	pop ax
	
	call ghostschasepacman
	cmp byte[time], 2
	jnge exitnewtimerisr

	call trymovepacman
	call displayscore
	mov byte[time], 0
	jmp exitnewtimerisr

endgame:
	pop ax
	mov byte[isgameover], 1
	jmp exitnewtimerisr

waitaftergameisover:
	cmp byte[time], 18*5
	jl exitnewtimerisr
	jg screencleared
	call clearscr
	jmp exitnewtimerisr

screencleared:
	mov byte[time], 201

exitnewtimerisr:
	pop ax
	pop bp
	jmp far [cs:oldtimerisr]

trymovepacman:
	; takes no arguments
	push bp
	mov bp, sp
	push di
	
	call erasepacman

	mov di, [pacmanposition]

	cmp byte[pacmandirection], 0
	je trymovepacmanleft
	cmp byte[pacmandirection], 1
	je trymovepacmanright
	cmp byte[pacmandirection], 2
	je trymovepacmandown
	jmp trymovepacmanup

trymovepacmanleft:
	push di
	sub di, 1
	push 0				; [bp-6]
	push di
	call pacmancollision
	cmp word[bp-6], 0
	je canmovepacman
	cmp word[bp-6], 2
	je pointfound
	pop di
	pop di
	jmp cantmovepacman

trymovepacmanright:
	push di
	add di, 1
	push 0				; [bp-6]
	push di
	call pacmancollision
	cmp word[bp-6], 0
	je canmovepacman
	cmp word[bp-6], 2
	je pointfound
	pop di
	pop di
	jmp cantmovepacman

trymovepacmandown:
	push di
	add di, 320
	push 0				; [bp-6]
	push di
	call pacmancollision
	cmp word[bp-6], 0
	je canmovepacman
	cmp word[bp-6], 2
	je pointfound
	pop di
	pop di
	jmp cantmovepacman

trymovepacmanup:
	push di
	sub di, 320
	push 0				; [bp-6]
	push di
	call pacmancollision
	cmp word[bp-6], 0
	je canmovepacman
	cmp word[bp-6], 2
	je pointfound
	pop di
	pop di
	jmp cantmovepacman

jmp cantmovepacman

pointfound:
	inc word[score]
canmovepacman:
	pop di
	pop di
	call movepacman
	jmp exittrymovepacman

cantmovepacman:
	call drawpacman

exittrymovepacman:
	pop di
	pop bp
	ret

checkforgameover:
; takes one argument, the return value
; returns 1 if game is over
; 0 if not
	push bp
	mov bp, sp
	push ax
	push cx

	mov cx, 0
cfgol:
	cmp cx, 8
	jnl noghostscollide
	
	push 0
	push cx
	call checkghostcollisionwithpacman
	cmp word[bp-6], 0
	jne gameisover

	pop ax

	add cx, 2
	jmp cfgol
	
gameisover:
	pop ax
	mov word[bp+4], 1
	jmp exitcheckforgameover

noghostscollide:
	mov word[bp+4], 0
	cmp word[score], 251
	jge gameisover
;	jmp exitcheckforgameover

exitcheckforgameover:
	pop cx
	pop ax
	pop bp
	ret

checkghostcollisionwithpacman:
; takes two arguments (ghost number and return value)
; returns 0 if there is no collision, 1 if there is
	push bp
	mov bp, sp
	push ax
	push si


	mov ax, [pacmanposition]
	mov si, [bp+4]
	mov si, [ghostpositions+si]
	sub ax, si
	
	cmp ax, -320*11-11
	je pdcwg
	cmp ax, -320*11
	je pdcwg
	cmp ax, -320*11+11
	je pdcwg
	cmp ax, -11
	je pdcwg
	cmp ax, 11
	je pdcwg
	cmp ax, 320*11-11
	je pdcwg
	cmp ax, 320*11
	je pdcwg
	cmp ax, 320*11+11
	je pdcwg
	jmp pdncwg

pdcwg:
	mov word[bp+6], 1
	jmp exitcheckghostcollisionwithpacman

pdncwg:
	mov word[bp+6], 0

exitcheckghostcollisionwithpacman:
	pop si
	pop ax
	pop bp
	ret 2


pacmancollision:
; takes two arguments, the return value, and the position of pacman
; it assumes Pac-Man has been erased first
; returns 0 when there is no collision
; returns 1 when there is a collision
; returns 2 when there is a dot that pacman can eat
	push bp
	mov bp, sp
	push cx
	push es
	push di

	push 0xa000
	pop es
	
	mov di, [bp+4]
	mov cx, 11
pclo:					; pacman collision loop (outer)
	push cx
	mov cx, 11
pcli:					; pacman collision loop (inner)
	cmp byte[es:di], 0
	je continuepcli
	cmp byte[es:di], 4
	jne pc

	mov word[bp+6], 2

continuepcli:
	inc di
	loop pcli
	pop cx
	add di, 320-11
	loop pclo
	jmp pnc

pc:					; pacman collides
	pop cx
	mov word[bp+6], 1
	jmp exitpc
pnc:					; pacman does not collide
	cmp word[bp+6], 2
	je exitpc
	mov word[bp+6], 0
;	jmp exitpc

exitpc:
	pop di
	pop es
	pop cx
	pop bp
	ret 2

movepacman:
	; takes one argument, the direction
	; (0: left, 1: right, 2: down, 3: up)
	push bp
	mov bp, sp
	push cx
	push es
	push di

	call erasepacman

	mov di, pacmanposition

	cmp byte[pacmandirection], 0
	je pacmanleft
	cmp byte[pacmandirection], 1
	je pacmanright
	cmp byte[pacmandirection], 2
	je pacmandown
	; assuming default case here (3) (up)
	jmp pacmanup

pacmanleft:
	sub word[di], 1
	jmp redrawpacman

pacmanright:
	add word[di], 1
	jmp redrawpacman

pacmandown:
	add word[di], 320
	jmp redrawpacman

pacmanup:
	sub word[di], 320
	jmp redrawpacman

redrawpacman:
	xor byte[pacmanclosedmouth], 1
	call drawpacman

	pop di
	pop es
	pop cx
	pop bp
	ret

drawpacman:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push es
	push ds
	push si
	push di

	push 0xa000
	pop es
	mov di, word[pacmanposition]
	push cs
	pop ds
	mov cx, 0

	cmp byte[pacmanclosedmouth], 0
	jne drawcircle

	mov dx, 0
	mov ah, 0
	mov al, byte[pacmandirection]
	; 22 is twice 11
	mov si, 22
	mul si
	mov si, ax
	add si, pacmanfigure
	jmp plo

drawcircle:
	mov si, pacmanclosedmouthfigure

plo:					; pacman loop (outer)
	push 1000000000000000b		; [bp - 18]

pli:					; pacman loop (inner)
	mov ax, [si]
	test ax, [bp-18]
	jz pacmanskipwrite

	cmp byte[es:di], 0
	jne pacmanskipwrite

	mov al, 0x2c			; pacman's color is yellowish 0x2c
	mov [es:di], al

pacmanskipwrite:
	inc di
	shr word[bp-18], 1
	cmp word[bp-18], 10000b
	jne pli

	pop ax
	add si, 2
	add di, 320-11
	add cx, 1
	cmp cx, 10
	jng plo

	pop di
	pop si
	pop ds
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

erasepacman:
	push bp
	mov bp, sp
	push bx
	push cx
	push es
	push di

	push 0xa000
	pop es
	mov di, [pacmanposition]

	mov cx, 11
eplo:					; erase pacman loop (outer)
	push cx
	mov cx, 11
epli:					; erase pacman loop (inner)
	mov byte[es:di], 0
	inc di
	loop epli

	add di, 320-11
	pop cx
	loop eplo
	
	pop di
	pop es
	pop cx
	pop bx
	pop bp
	ret

xorshift:
	; NOTE: if your assembler does not compile this function properly,
	; uncommenting all the db 0x66 lines should make it work

	; takes no arguments
	; returns a random number
	; its logic should go somethimg like this, taken from wikipedia

;#include <stdint.h>
;
;struct xorshift32_state {
;    uint32_t a;
;};
;
;/* The state must be initialized to non-zero */
;uint32_t xorshift32(struct xorshift32_state *state)
;{
;	/* Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs" */
;	uint32_t x = state->a;
;	x ^= x << 13;
;	x ^= x >> 17;
;	x ^= x << 5;
;	return state->a = x;
;}

	push bp
	mov bp, sp
	; db 0x66
	push eax

	; db 0x66
	cmp dword[xorshift_state], 0
	; db 0x66
	jne skipresetxorshiftstate

	; db 0x66
	mov dword[xorshift_state], 2527132011

skipresetxorshiftstate:
	; db 0x66
	mov eax, [xorshift_state]

	; db 0x66
	mov dword[bp+4], eax
	; db 0x66
	shr eax, 13
	; db 0x66
	xor [bp+4], eax

	; db 0x66
	mov eax, [bp+4]
	; db 0x66
	shl eax, 17
	; db 0x66
	xor [bp+4], eax
	
	; db 0x66
	mov eax, [bp+4]
	; db 0x66
	shr eax, 5
	; db 0x66
	xor [bp+4], eax
	
	; db 0x66
	mov eax, [bp+4]
	; db 0x66
	mov [xorshift_state], eax

	; db 0x66
	pop eax
	pop bp
	ret

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

trymoveghost:
	; takes two arguments, the direction and ghost and ghost number
	push bp
	mov bp, sp
	push di
	
	push word[bp+4]
	call eraseghost

	mov di, ghostpositions
	add di, word[bp+4]
	mov di, [di]

	cmp word[bp+6], 0
	je trymoveghostleft
	cmp word[bp+6], 1
	je trymoveghostright
	cmp word[bp+6], 2
	je trymoveghostdown
	jmp trymoveghostup

trymoveghostleft:
	push di
	sub di, 1
	push 0				; [bp-6]
	push di
	call ghostcollision
	cmp word[bp-6], 0
	je canmoveghost
	pop di
	pop di
	jmp cantmoveghost

trymoveghostright:
	push di
	add di, 1
	push 0				; [bp-6]
	push di
	call ghostcollision
	cmp word[bp-6], 0
	je canmoveghost
	pop di
	pop di
	jmp cantmoveghost

trymoveghostdown:
	push di
	add di, 320
	push 0				; [bp-6]
	push di
	call ghostcollision
	cmp word[bp-6], 0
	je canmoveghost
	pop di
	pop di
	jmp cantmoveghost

trymoveghostup:
	push di
	sub di, 320
	push 0				; [bp-6]
	push di
	call ghostcollision
	cmp word[bp-6], 0
	je canmoveghost
	pop di
	pop di
	jmp cantmoveghost

jmp cantmoveghost


canmoveghost:
	pop di
	pop di
	push word[bp+6]
	push word[bp+4]
	call moveghost
	jmp exittrymoveghostloop

cantmoveghost:
	mov di, ghostpositions
	add di, [bp+4]
	mov di, [di]
	push di
	mov di, ghostcolors
	add di, [bp+4]
	mov di, [di]
	push di
	call drawghost

exittrymoveghostloop:
	pop di
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
	pop cx
	mov word[bp+6], 1
	jmp exitgc
gnc:					; ghost does not collide
	mov word[bp+6], 0
;	jmp exitgc

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

printscoretext:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push es
	push bp

	mov ax, 0x1380
	mov bx, 0x000f
	mov cx, 6
	mov dx, 0x0500
	push cs
	pop es
	mov bp, scorestring
	int 0x10

	pop bp
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

displayscore:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx
	push dx
	push es
	push bp
	push di
	
	; first printnum sequence from the book
	push cs
	pop es
	mov ax, [score]
	mov bx, 10
	mov cx, 0

nextdigit:
	mov dx, 0
	div bx
	add dl, 0x30
	push dx
	inc cx
	cmp ax, 0
	jnz nextdigit
	
	mov di, scorestring+6
nextpos:
	pop dx
	mov [cs:di], dl
	inc di
	loop nextpos

clearotherdigitspaces:
	cmp di, scorestring+10
	ja printscore
	mov byte[cs:di], ' '
	inc di
	jmp clearotherdigitspaces

printscore:
	mov ax, 0x1380
	mov bx, 0x000f
	mov cx, 5
	mov dx, 0x0507
	push bp
	mov bp, scorestring+6
	int 0x10
	pop bp

	pop di
	pop bp
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

ghostschasepacman:
	; NOTE: if your assembler does not compile this function properly,
	; uncommenting all the db 0x66 lines should make it work
	push bp
	mov bp, sp
	push ax
	push cx
	push dx

	mov cx, 0
chaseloop:
	cmp cx, 8
	je exitghostschasepacman
	; db 0x66
	push dword 0			; [bp-10]
	call xorshift
	; db 0x66
	mov eax, [bp-10]
	; db 0x66
	mov edx, 0
	; db 0x66
	div dword [four]
	; db 0x66
	mov [bp-10], edx		; rand() % 4
	push cx
	call trymoveghost
	add cx, 2
	pop ax
	jmp chaseloop

exitghostschasepacman:
	pop dx
	pop cx
	pop ax
	pop bp
	ret

start:

	mov eax, 0
	mov al, 0x00
	out 0x70, al
	jmp D1
	
	mov [xorshift_state], eax

D1:
	in al, 0x71

	push 0
	pop es

	mov eax, [es:4*8]
	mov [oldtimerisr], eax

	mov eax, [es:4*9]
	mov [oldkbisr], eax

	cli
	mov word[es:4*8], newtimerisr
	mov word[es:4*8+2], cs
	
	mov word[es:4*9], newkbisr
	mov word[es:4*9+2], cs
	sti

	mov ax, 0x13
	int 0x10
	mov bp, sp

	call loadpalette
	call drawmap
	call drawghosts
	call drawpacman
	call printscoretext

;	push ax

;moveloop:
;	pop ax
;	mov cx, 10

;moveloopghosts:
;	call ghostschasepacman
;	call displayscore
;	loop moveloopghosts
;
;	call trymovepacman
;	push 0
;	call checkforgameover
;	cmp word[bp-2], 0
;	je moveloop

;	pop ax

	jmp $

exit:
	mov ax, 3
	int 0x10
	mov ax, 0x4c00
	int 0x21
