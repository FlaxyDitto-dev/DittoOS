bits 16

run_calculator:
    mov ah, 0x06
    mov al, 0x09    
    mov bh, 0x4F    ; Red background
    mov cx, 0x0610  
    mov dx, 0x0E3F  
    int 0x10

    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0715  
    int 0x10
    mov si, calc_title
    call app_print_str

    mov dx, 0x0915  
    int 0x10
    mov si, calc_math
    call app_print_str

    mov dx, 0x0B15  
    int 0x10
    mov si, calc_exit
    call app_print_str

    mov ah, 0x00
    int 0x16
    ret             

app_print_str:
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    ret

calc_title db "--- DittoCalc ---", 0
calc_math  db "Math Engine: 5 + 5 = 10", 0
calc_exit  db "Press any key to exit app...", 0