[bits 32]

print_hex_32:
    pusha
    mov ecx, 0

_hex_loop_32:
    cmp ecx, 8
    je _hex_end_32

    mov eax, edx
    and eax, 0x0000000f
    add al, 0x30
    cmp al, 0x39 ; if > 9, add extra 7 to represent 'A' to 'F'
    jle _hex_32_2
    add al, 7 ; 'A' is ASCII 65(0x41) instead of 58(0x3a), so 65-58=7

_hex_32_2:
    mov ebx, HEX_OUT_32 + 9 ; base + length
    sub ebx, ecx  ; our index variable
    mov [bx], al ; copy he ASCII char on 'al' to the position pointed by 'bx'
    ror edx, 4

    add ecx, 1
    jmp _hex_loop_32

_hex_end_32:
    mov si, HEX_OUT_32
    call print_32
    popa
    ret


HEX_OUT_32: db '0x00000000', 0
