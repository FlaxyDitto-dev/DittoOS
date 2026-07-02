; This app will be packed into the disk image and called by the kernel
bits 16

%define SCREEN_CLEAR_REG 0x0609

run_calculator:
    ; Clear the workspace window area
    mov ah, 0x06
    mov al, 0x09    
    mov bh, 0x4F    ; Red background (4) with White text (F) for the app!
    mov cx, 0x0610  
    mov dx, 0x0E3F  
    int 0x10

    ; Print App Title
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0715  ; Row 7, Col 21
    int 0x10
    mov si, calc_title
    call app_print_str

    ; Print Math Problem
    mov dx, 0x0915  ; Row 9, Col 21
    int 0x10
    mov si, calc_math
    call app_print_str

    ; Wait for user keypress to exit back to the OS shell
    mov dx, 0x0B15  ; Row 11, Col 21
    int 0x10
    mov si, calc_exit
    call app_print_str

    mov ah, 0x00
    int 0x16

    ret             ; Return control back to the kernel!

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