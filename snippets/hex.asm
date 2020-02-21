; print hex in protected mode snippet
; copy it into stage1/stage2 for debugging
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
