; Bootloader Stage2

%define STAGE2_OFFSET 0x2200

%define CR0_PE_ON   0x1
%define CR0_PE_OFF	0x7FFFFFFE  ; Disable paging and 16bit mode bits
%define PROT_MODE_CSEG	0x8
%define PROT_MODE_DSEG  0x10
%define PSEUDO_RM_CSEG	0x18
%define PSEUDO_RM_DSEG	0x20

%define FSYS_BUF 0x68000
%define PROTSTACKINIT (FSYS_BUF - 0x10)
%define STACKOFF (0x2000 - 0x10)
%define VIDEO_MEMORY 0xb8000
%define WHITE_ON_BLACK 0x0f
; Kernel size is set during make, based on kernel.bin size
; %define KERNEL_SIZE 0x0b
%define KERNEL_SECTOR 0x03
%define KERNEL_OFFSET 0x8000

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
    ; save disk id and configuration first
    push dx
    mov [disk_configuration], bx

    MSG16(notification_string)

load_kernel:

    mov si, [disk_configuration]
    mov ax, [si]
    and ax, 0x1
    jz chs_mode

lba_mode:
    push dword 0x0                       ; padding
    push dword KERNEL_SECTOR             ; Location on disk
                                         ; Memory address to read data to: segment:offset
    push word 0x0                        ; segment
    push word KERNEL_OFFSET              ; offset
    push word KERNEL_SIZE                        ; Number of sectors to read (1)
    push word 0x10                       ; Reserved byte and Packet Size (16 bytes)

    ;   BIOS call "INT 0x13 Function 0x42" to read sectors from disk into memory
    ;	Call with	%ah = 0x42
    ;			%dl = drive number
    ;			%ds:%si = segment:offset of disk address packet
    ;	Return:
    ;			%al = 0x0 on success; err code on failure

    mov ah, 0x42                         ; Extended read function
    mov si, sp                           ; Point SI to stack
    int 0x13
    jc chs_mode
    jmp exec_kernel

chs_mode:
    xor edx, edx
    mov eax, KERNEL_SECTOR          ; load LBA kernel sector

    mov si, [disk_configuration]    ; set SI to disk configuration address
    mov ebx, [si + 1]               ; address where we put sectors number in stage1
    div ebx                         ; calculate sector start
    mov cl, dl                      ; put sector start in right register
    inc cl                          ; compensate for LBA index starting with 0
                                    ; and CHS index starting with 1

    xor edx, edx
    mov ebx, [si + 5]               ; address where we put heads number in stage1
    div ebx
    mov ch, al                      ; set cylinder start in right register

    mov al, dl                      ; save heads start
    pop dx                          ; restore disk id
    mov dh, al                      ; set heads start in right register

    ;   BIOS call "INT 0x13 Function 0x2" to read sectors from disk into memory
    ;	Call with
    ;           %ah = 0x2
    ;			%al = number of sectors
    ;			%ch = cylinder
    ;			%cl = sector (bits 6-7 are high bits of "cylinder")
    ;			%dh = head
    ;			%dl = drive (0x80 for hard disk, 0x0 for floppy disk)
    ;			%es:%bx = segment:offset of buffer
    ;	Return:
    ;			%al = 0x0 on success; err code on failure
    xor bx, bx
    mov es, bx
    mov bx, KERNEL_OFFSET
    mov ah, 0x02                    ; function
    mov al, KERNEL_SIZE             ; number of sectors to read
    int 0x13

exec_kernel:
    MSG16(kernel_load_string)

    call real_to_prot

    [bits 32]
;    MSG32(notification_string_32)
    call KERNEL_OFFSET
    ; jump to kernel code

    ; old test code of jump back to prot mode
    ; might be necessary for easy disk reads
    ; while there are no device drivers in kernel
    ; call prot_to_real
    ; [bits 16]
    ; MSG16(switch_to_prot_string)

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

[bits 32]
prot_to_real:
	; just in case, set GDT
	lgdt [gdt_descriptor]

	; save the protected mode stack
    mov eax, esp
    mov [protstack], eax

	; get the return address
    mov ax, sp
    mov ax, [eax]
    mov [STACKOFF], eax

	; set up new stack
    mov eax, STACKOFF
    mov esp, eax
    mov ebp, eax;

    ; pick up return address
    mov eax, [STACKOFF]
    mov [esp], eax
    xor eax, eax

	; set up segment limits
    mov ax, PSEUDO_RM_DSEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

	; this might be an extra step
    jmp PSEUDO_RM_CSEG:tmpcseg      ; jump to a 16 bit segment

[bits 16]
tmpcseg:
    cli ; interrupts should be turned off since last real-to-prot switch,
        ; but just in case, turn them off

    ; clear the PE bit of CR0 */
    mov eax, cr0
    and eax, CR0_PE_OFF
	mov cr0, eax

    ;* flush prefetch queue, reload %cs */
    jmp 0:realcseg

realcseg:
	; we are in real mode now
	; set up the real mode segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ; restore interrupts
	sti
	; return on new stack!
    ret


; message: write the string pointed to by %si
; WARNING: trashes %si, %ax, and %bx
; WARNING: works only in protected mode, since relies on BIOS interrupts
[bits 16]
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
hex:
    pusha
    mov cx, 0
_hex_loop:
    cmp cx, 4
    je _hex_end

    mov ax, dx
    and ax, 0x000f
    add al, 0x30
    cmp al, 0x39 ; if > 9, add extra 7 to represent 'A' to 'F'
    jle _hex_2
    add al, 7 ; 'A' is ASCII 65(0x41) instead of 58(0x3a), so 65-58=7

_hex_2:
    mov bx, HEX_OUT + 5 ; base + length
    sub bx, cx  ; our index variable
    mov [bx], al ; copy the ASCII char on 'al' to the position pointed by 'bx'
    shr dx, 4

    add cx, 1
    jmp _hex_loop

_hex_end:
    mov si, HEX_OUT
    call message16
    jmp _end_print

_end_print:
    popa
    ret

HEX_OUT: db '0x0000', 0

notification_string: db "Loading stage2", 0
kernel_load_string: db "Kernel loaded into memory", 0
notification_string_32: db "In 32bit mode", 0
switch_to_prot_string: db "Protected mode", 0

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

disk_configuration:
    dw 0

protstack:
    dd PROTSTACKINIT

video_memory:
    dd VIDEO_MEMORY

message: db 'yep', 0
times 1024-($-$$) db 0
