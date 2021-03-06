; Bootloader Stage 1

%define STAGE1_STACKSEG         0x2000
%define STAGE1_BPBEND           0x3e
%define STAGE1_BIOS_HD_FLAG     0x80
%define STAGE1_SIGNATURE        0xaa55
%define STAGE1_WINDOWS_NT_MAGIC	0x1b8
%define STAGE1_PARTSTART	    0x1be
%define STAGE1_PARTEND		    0x1fe
%define STAGE1_DISK_BUFFER      0x7000

%define STAGE2_SECTOR           0x01
%define STAGE2_SEGMENT          0x220
%define STAGE2_ADDRESS          0x2200

%define ABS(x) (x-_start+0x7c00)
%macro MSG 1
    mov si, %1
    call message
%endmacro

[org 0x7c00] ; BIOS loads bootsector into 0x7c00
[bits 16]

_start: jmp after_BPB
nop

; This space is for the BIOS parameter block!!!!
; Don't change the first jump,
; nor start the code anywhere but right after this area.
times _start+4-$ db 0
disk_configuration:
mode: db	0
sectors: dd 0
heads: dd 0
cylinders: dw 0
sector_start: db 0
head_start: db 0
cylinder_start: dw 0
times _start+STAGE1_BPBEND-$ db 0
; End of BIOS parameter block.

after_BPB:
    cli ; turn interrupts off

	; long jmp to the next instruction because some bogus BIOSes
	; jump to 07C0:0000 instead of 0000:7C00.
    jmp 0x0:ABS(_loader)

_loader:
    ; Reset segment registers
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax

    ; Set stack
    mov ax, STAGE1_STACKSEG
    mov sp, ax
    mov bp, ax

    sti ; turn interrupts back

main:
    ; save device id
    push dx

    MSG(notification_string)

    ; do not probe LBA if the drive is a floppy
    test dl, STAGE1_BIOS_HD_FLAG
    jz	chs_mode

    ; check if LBA is supported
    mov ah, 0x41
    mov bx, 0x55aa
    int	0x13
    ; %dl may have been clobbered by INT 13, AH=41H.
    pop	dx
    push dx
    jc chs_mode

    cmp bx, 0xaa55  ; check that 0x13 raised no exceptions
    jne chs_mode

    ; check that device access using the packet structure is available
    and cx, 0x1
    jz chs_mode

lba_mode:
    mov [mode], byte 0x1
    ; store DAP in stack in reverse order
    push dword 0x0                       ; padding
    push dword STAGE2_SECTOR             ; Location on disk
                                         ; Memory address to read data to: segment:offset
    push word STAGE2_SEGMENT             ; segment
    push word 0x0                        ; offset
    push word 0x3                        ; Number of sectors to read (1)
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
	jc	chs_mode

    jmp stage2_entry

chs_mode:
    mov ah, 0x08
    int 0x13
	jnc	floppy_init

    test dl, STAGE1_BIOS_HD_FLAG
	jz	floppy_probe

	; Nope, we definitely have a hard disk, and we're screwed.
	jmp	hd_probe_error

    floppy_init:

    ; get number of heads
    xor eax, eax
    mov al, dh      ;   logical last index of heads = number_of - 1
    inc ax          ;   (because index starts with 0)
    mov [heads], ax ; save number of heads

    ; get number of cylinders
    xor dx, dx
    mov dl, cl           ; logical last index of cylinders
    shl dx, 2            ; stored in dh + 2 high bits of dl
    mov al, ch
    mov ah, dh
    inc ax               ; (because index starts with 0)
    mov [cylinders], ax  ; save number of cylinders

    xor ax, ax
    mov al, dl          ; number of sectors is
    shr al, 2           ; first 6 bits of dl
    mov [sectors], ax   ; save number of sectors

    .setup:
    xor edx, edx
    mov eax, STAGE2_SECTOR  ; load LBA sector

    mov ebx, [sectors]
    div ebx                 ; divide by number of sectors

    mov [sector_start], dl  ; save sector start

    xor edx, edx
    mov ebx, [heads]
    div ebx                 ; divide by number of heads

    mov [head_start], dl    ; save head start
    mov [cylinder_start], ax; save cylinder start

	; check that we have that many cylinders
    cmp ax, [cylinders]
	jge	geometry_error

    ; This is where we taking care of BIOS geometry translation

    mov dl, [cylinder_start]
    and dl, 0xf0                ; get high bits of cylinder
    shl dl, 6                   ; shift left by 6 bits
    mov cl, [sector_start]      ; get sector
    inc cl                      ; normalize sector (sectors go from 1-N, not 0-(N-1) )
    or cl, dl                   ; composite together
    mov ch, [cylinder_start]    ; sector+hcyl in cl, cylinder in ch

    pop dx                      ; restore disk id in dl
    mov dh, [head_start]        ; head number

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
    mov bx, STAGE2_SEGMENT
    mov es, bx
    xor bx, bx

    mov ax, 0x0202  ; function + number of sectors to read
    int 0x13
    jc read_error

stage2_entry:
    ; pass disk configuration address,
    ; so we wont need to probe disk in stage2 for it
    mov bx, ABS(mode)

    ;jump to stage 2 (which is stage1.5 actually)
    jmp 0x0:STAGE2_ADDRESS

hd_probe_error:
	MSG(hd_probe_error_string)
	jmp	general_error

geometry_error:
    MSG(geometry_error_string)
    jmp general_error

read_error:
    MSG(read_error_string)

general_error:
	MSG(general_error_string)

stop: jmp stop

notification_string:	db "Booting OS...", 0
geometry_error_string:	db "Geom", 0
hd_probe_error_string:	db "Hard Disk", 0
read_error_string:	db "Read", 0
general_error_string:	db " Error", 0

; message: write the string pointed to by %si
;   WARNING: trashes %si, %ax, and %bx
_message:
    mov ah, 0x0e
    int 0x10
message:
    lodsb
    cmp al, 0
    jne _message
    call _newline
    call _creturn
    ret
; _newline: write newline
;   WARNING: trashes %ax
_newline:
    mov ah, 0x0e
    mov al, 0x0a
    int 0x10
    ret
; _newline: write carriage return
;   WARNING: trashes %ax
_creturn:
    mov ah, 0x0e
    mov al, 0x0d
    int 0x10
    ret


times STAGE1_WINDOWS_NT_MAGIC-($-$$) db 0
nt_magic:
	dd 0
    dw 0

part_start:
    times STAGE1_PARTSTART-($-$$) db 0
probe_values:
	db	36, 18, 15, 9, 0

floppy_probe:
    ; Perform floppy probe.
    mov si, (probe_values - 1)

probe_loop:
    ; reset floppy controller INT 13h AH=0
    xor ax, ax
    int 0x13

    inc si
    mov cl, [si]

; 	/* if number of sectors is 0, display error and die */
    cmp cl, 0
    jne probe_read

    ; Floppy disk probe failure.
 	MSG(fd_probe_error_string)
 	jmp	general_error

fd_probe_error_string:	db "Floppy", 0

probe_read:
    ; perform read
    mov bx, STAGE2_SEGMENT
    mov ax, 0x0201
    mov ch, 0x0
    mov dh, 0x0
    int 0x13
    ; if error, jump to "probe_loop"
 	jc	probe_loop

    ; %cl is already the correct value!
    mov dh, 1
    mov ch, 79
 	jmp	floppy_init

times STAGE1_PARTEND-($-$$) db 0
dw STAGE1_SIGNATURE
