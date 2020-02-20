; Bootloader Stage2

%define STAGE2_OFFSET 0x8000

%define CR0_PE_ON   0x1
%define CR0_PE_OFF	0xfffffffe
%define PROT_MODE_CSEG	0x8
%define PROT_MODE_DSEG  0x10
%define PSEUDO_RM_CSEG	0x18
%define PSEUDO_RM_DSEG	0x20

%define FSYS_BUF 0x68000
%define PROTSTACKINIT (FSYS_BUF - 0x10)
%define STACKOFF (0x2000 - 0x10)
%define VIDEO_MEMORY 0xb8000
%define WHITE_ON_BLACK 0x0f

%define ABS(x) (x-_start+STAGE2_OFFSET)
%macro MSG16 1
    mov si, %1
    call message16
%endmacro
%macro MSG32 1
    mov si, %1
    call message32
%endmacro
%macro HEX32 1
    mov edx, %1
    call hex32
%endmacro

[org STAGE2_OFFSET]
[bits 16]

_start:

    cli
    ; reset stacks
    xor ax, ax
    mov ss, ax
    mov es, ax
    mov ds, ax

    mov ebp, STACKOFF
    mov esp, ebp

    sti

main:
    MSG16(notification_string)

    call real_to_prot

    [bits 32]
    MSG32(notification_string_32)
    MSG32(notification_string_32)

halt:
    jmp $

[bits 16]
real_to_prot:
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, CR0_PE_ON
    mov cr0, eax
    jmp PROT_MODE_CSEG:protcseg


[bits 32]
protcseg:

    ; set segment registers
    mov ax, PROT_MODE_DSEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ;save previos stack to memory
    mov ax, sp ; there could be garbage in esp high bits,
               ; so copy only four lower bits that are used in real mode
    mov ax, [eax]
    mov [STACKOFF], eax

    ;set 32bit stack
    mov eax, [protstack]
    mov ebp, eax
    mov esp, eax

    ;return to previous stack position
    mov eax, [STACKOFF]
    mov [esp], eax
    xor eax, eax

    ret

;prot_to_real:
;	;just in case, set GDT
;	lgdt [gdt_descriptor]
;    cli
;
;	;save the protected mode stack
;    mov eax, esp
;    mov [protstack], eax
;
;	; get the return address
;    mov ax, sp
;    mov ax, [eax]
;    mov [STACKOFF], eax
;
;	; set up new stack
;    mov eax, STACKOFF
;    mov esp, eax
;    mov ebp, eax
;
;    mov eax, [STACKOFF]
;    mov [esp], eax
;    xor eax, eax
;
;	; set up segment limits
;    mov ax, PSEUDO_RM_DSEG
;    mov ds, ax
;    mov es, ax
;    mov fs, ax
;    mov gs, ax
;    mov ss, ax
;
;    jmp PSEUDO_RM_CSEG:tmpcseg
;
;[bits 16]
;tmpcseg:
;
;    ; clear the PE bit of CR0
;    mov eax, cr0
;    and eax, CR0_PE_OFF
;    mov cr0, eax
;
;    ; flush prefetch queue, reload %cs
;    jmp 0x0:realcseg
;
;realcseg:
;	; we are in real mode now
;	; set up the real mode segment registers
;    xor ax, ax
;    mov ds, ax
;    mov es, ax
;    mov fs, ax
;    mov gs, ax
;    mov ss, ax
;
;	; restore interrupts
;	sti
;	; return on new stack!
;    ret

[bits 16]
notification_string: db "Loading stage1.5", 0
notification_string_32: db "In 32bit mode", 0
switch_to_prot_string: db "Protected mode", 0

; message: write the string pointed to by %si
; WARNING: trashes %si, %ax, and %bx
; WARNING: works only in protected mode, since relies on BIOS interrupts
_message16:
    mov ah, 0x0e
    int 0x10
message16:
    lodsb
    cmp al, 0
    jne _message16
    call _newline16
    call _creturn16
    ret
; _newline: write newline
;   WARNING: trashes %ax
_newline16:
    mov ah, 0x0e
    mov al, 0x0a
    int 0x10
    ret
; _newline: write carriage return
;   WARNING: trashes %ax
_creturn16:
    mov ah, 0x0e
    mov al, 0x0d
    int 0x10
    ret

[bits 32]
_message32:
    mov ah, WHITE_ON_BLACK
    mov [edx], ax           ; DMA print
    add edx, 2              ; set next char position
    mov [video_memory], edx ; save next free position
message32:
    mov edx, [video_memory]
    lodsb
    cmp al, 0
    jne _message32
    call _newline32
    call _creturn32
    ret
_newline32:
    mov edx, [video_memory]
    mov ah, WHITE_ON_BLACK
    mov al, ' ' ; fix this
    mov [edx], ax
    add edx, 2
    mov [video_memory], edx
    ret
_creturn32:
    mov edx, [video_memory]
    mov ah, WHITE_ON_BLACK
    mov al, ' '
    mov [edx], ax
    add edx, 2
    mov [video_memory], edx
    ret


[bits 16]
gdt_start:
; Scheme:
; Limit (bits 0-15), Base (bits 0-15)
; Base (bits 16-23), Flags (present, privilege, descriptor type) + type flags (code/data, conforming, readable, accessed),
; second Flags (granularity, 32bit?, 64bit?, AVL) + Limit (bits 16-19), Base (bits 24-31)
gdt_null: ; the mandatory null descriptor
dw 0, 0
db 0, 0, 0, 0

gdt_code_segment: ; the code segment descriptor
; (present)1 (privilege)00 (descriptor type)1
; (code)1 (conforming)0 (readable)1 (accessed)0
; (granularity)1 (32-bit default)1 (64-bit seg)0 (AVL)0
dw 0xffff, 0x0
db 0, 0x9A, 0xCF, 0

gdt_data_segment: ;the data segment descriptor
; mostly same as code, except
; (code)0 (expand down)0 (writable)1 (accessed)0
dw 0xffff, 0x0
db 0x0, 0x92, 0xCF, 0

gdt_code_16bit_segment: ; 16bit real mode code segment
; same as gdt_code_segment, but
; conforming(1)
; granularity(0), 32bit 0, 64bit 0, AVL 0
dw 0xffff, 0x0
db 0x0, 0x9C, 0x0, 0

gdt_data_16bit_segment: ; 16bit real mode data segment
dw 0xffff, 0x0
db 0x0, 0x92, 0x0, 0
gdt_end:

; GDT descriptior
gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

protstack:
    dd PROTSTACKINIT
video_memory:
    dd VIDEO_MEMORY
