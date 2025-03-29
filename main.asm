[org 0x0100]
	jmp start

font:
	times 256*16 db 0		; space for font

modeblock:
	times 256 db 0
;	.signature db "VBE2"
;	.table_data: resb 512-4
; taken from https://forum.osdev.org/viewtopic.php?t=30186

gdt:
	dd 0x00000000, 0x00000000	; null descriptor
	dd 0x0000ffff, 0x00cf9a00	; 32bit code descriptor (base(0..15 and 16..23) will be filled later)
	dd 0x0000ffff, 0x00cf9200	; data

gdtreg:
	dw 0x17				; 16bit limit
	dd 0				; 32bit base (filled later)
stack: times 256 dd 0			; 1k stack stacktop: start:
stacktop:

start:
	mov ax, cs
	mov es, ax			; point es to cs, just in case
	mov bp, font			; point di to font block
	mov ax, 0x1130			; service 11/30, get font info
	mov bx, 0x0600			; ROM 8x16 font
	int 0x10

	mov si, bp			; point si to rom font data
	mov di, font			; point di to font block
	mov cx, 256*16			; size of 4k font block
	push ds
	push es 
	pop ds				; ds:si to rom font data
	pop es				; es:di to font block
	cld				; auto-increment mode
	rep movsb			; copy font

	push cs
	pop ds				; restore ds to data segment

	mov ax, 0x4f01			; get vesa mode information
	mov cx, 0x4117			; 1024*768*64k linear framebuffer
	mov di, modeblock
	int 0x10
	mov esi, [modeblock+0x28]	; store address of the first character of the framebuffer
	; esi now stores the framebuffer mode's equivalent of absolute address 0xB8000

	mov ax, 0x4f02
	mov bx, 0x4117
	; 0x0107 is another good option
	int 0x10			; set vesa mode
	; the screen should now have a resolution of 1024*768

	mov ax, 0x2401
	int 0x15			; enable a20
	; Gate A20 is a workaround for some bug the book does not detail
	; this enables it to open the whole memory for us

	xor eax, eax
	mov ax, cs
	shl eax, 4
	mov [gdt+0x08+2], ax		; base(0..15)
	shr eax, 16
	mov [gdt+0x08+4], al		; base(16..23)
	; this should fill in the base of the code descriptor
	; I think this sets it to the old CS stack register

	xor edx, edx
	mov dx, cs
	shl edx, 4
	add edx, stacktop		; stacktop for protected mode
	; stacktop points just beyond the 256 dwords of "stack"

	xor ebx, ebx
	mov bx, cs
	shl ebx, 4
	add ebx, font

	xor eax, eax
	mov ax, cs
	shl eax, 4
	add eax, gdt
	mov [gdtreg+2], eax		; set base of gdt
	lgdt [gdtreg]			; load gdtr
	; this should load the global descriptor table required for protected mode
	; its location is cs:gdt

	mov eax, cr0
	or eax, 1

	cli				; disable interrupts for now
	mov cr0, eax			; enable protected mode
	jmp 0x08:pstart			; load cs
	; protected mode handles interrupts differently

;					;
;	START OF PROTECTED MODE		;
;					;
[bits 32]


;//this is the bitmap font you've loaded
;unsigned char *font;
;
;void drawchar_transparent(unsigned char c, int x, int y, int fgcolor)
;{
;	int cx,cy;
;	int mask[8]={1,2,4,8,16,32,64,128};
;	unsigned char *glyph=font+(int)c*16;
;
;	for(cy=0;cy<16;cy++){
;		for(cx=0;cx<8;cx++){
;			if(glyph[cy]&mask[cx]) putpixel(fgcolor,x+cx,y+cy-12);
;		}
;	}
;}
; from https://wiki.osdev.org/VGA_Fonts#Displaying_a_character
; this takes 5 arguments, the font area, the character to draw, x, y, and the color
drawchar:
	push ebp
	mov ebp, esp
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi
	
	mov edx, 0
	mov eax, 1024 * 2
	mul dword[bp+12]		; y
	mov edi, eax
	add edi, esi
	mov eax, [bp+16]		; x
	shl eax, 1
	add edi, eax

	mov esi, [bp+24]		; 4096 byte font array
	mov edx, 0
	mov eax, 16			; each character map is 4 bytes
	mul dword[bp+20]		; character
	add esi, eax

	mov ecx, 0
dclo:					; drawchar loop (outer)
	mov bl, 10000000b		; functions as a mask
	push ecx
	mov ecx, 0

dcli:					; drawchar loop (inner)
	test bl, [esi]
	jz skipwrite

	mov eax, [bp+8]			; color
	mov [edi], eax

skipwrite:
	shr bl, 1
	add edi, 2
	inc ecx
	cmp ecx, 8
	jl dcli

	add esi, 1
	add edi, 1024*2-16

	pop ecx
	inc ecx
	cmp ecx, 16
	jl dclo

	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	pop ebp
	ret 20

pstart:
	mov ax, 0x10			; load all seg regs to 0x10
	mov ds, ax			; flat memory model
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov esp, edx
	
	push ebx
	push 'H'
	push 1024/2-8
	push 768/2-16
	push 0000011111100000b
	call drawchar

	push ebx
	push 'e'
	push 1024/2
	push 768/2-16
	push 0000011100100000b
	call drawchar

	push ebx
	push 'l'
	push 1024/2+8
	push 768/2-16
	push 0000011001100000b
	call drawchar

	push ebx
	push 'l'
	push 1024/2+16
	push 768/2-16
	push 0000010110100000b
	call drawchar

	push ebx
	push 'o'
	push 1024/2+24
	push 768/2-16
	push 0000010011100000b
	call drawchar

	push ebx
	push 'W'
	push 1024/2+40
	push 768/2-16
	push 0000010000100000b
	call drawchar

	push ebx
	push 'o'
	push 1024/2+48
	push 768/2-16
	push 0000001101100000b
	call drawchar

	push ebx
	push 'r'
	push 1024/2+56
	push 768/2-16
	push 0000001010100000b
	call drawchar

	push ebx
	push 'l'
	push 1024/2+64
	push 768/2-16
	push 0000000111100000b
	call drawchar

	push ebx
	push 'd'
	push 1024/2+72
	push 768/2-16
	push 0000000100100000b
	call drawchar


	jmp $
