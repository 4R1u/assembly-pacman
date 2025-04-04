[org 0x0100]
	jmp start

mapfilename:
	db "map.bmp", 0

infobuffer:
	times 140 db 0

mappixels:
	times 500 db 0

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
	cmp cx, 0
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

start:
	mov ax, 0x13
	int 0x10

	call drawmap

exit:
;	mov ax, 3
;	int 0x10
	mov ax, 0x4c00
	int 0x21
