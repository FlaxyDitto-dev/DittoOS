[org 0x7c00]        ; Tell the assembler the bootloader is loaded at 0x7C00
bits 16             ; We start in 16-bit Real Mode

start:
    ; Set up segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; --- 1. SET VIDEO MODE & BACKGROUND ---
    ; BIOS Interrupt 0x10, AH=0x00 sets text mode (80x25 characters, 16 colors)
    mov ah, 0x00
    mov al, 0x03    ; Mode 3: standard color text mode
    int 0x10

    ; Clear screen / set background to Dark Blue (1) with White Text (F)
    ; Attribute byte: 0x1F (1 = Blue background, F = White text)
    mov ah, 0x06    ; Scroll up window function
    mov al, 0x00    ; Clear entire screen
    mov bh, 0x1F    ; White on Blue
    mov cx, 0x0000  ; Top-left corner (0,0)
    mov dx, 0x184F  ; Bottom-right corner (24,79)
    int 0x10

    ; --- 2. DRAW DITTOGUI TOP BAR ---
    ; Clear the top row to Light Gray (7) with Black Text (0) -> Attribute 0x70
    mov ah, 0x06
    mov al, 0x01    ; 1 row
    mov bh, 0x70    ; Black on Light Gray
    mov cx, 0x0000  ; (0,0)
    mov dx, 0x004F  ; (0,79)
    int 0x10

    ; Print Top Bar Text
    mov dx, 0x0002  ; Row 0, Column 2
    mov si, top_bar_text
    call print_string_at

    ; --- 3. DRAW THE DITTOGUI WINDOW ---
    ; We draw a window container using CP437 Box-Drawing codes
    ; Window box properties: Row 5 to 15, Col 15 to 65
    
    ; Top Border: ┌ (0xDA) then 48 ─ (0xC4) then ┐ (0xBF)
    mov dx, 0x050F  ; Row 5, Col 15
    call move_cursor
    mov al, 0xDA    ; ┌
    call print_char
    mov cx, 48
draw_top_line:
    mov al, 0xC4    ; ─
    call print_char
    loop draw_top_line
    mov al, 0xBF    ; ┐
    call print_char

    ; Sides and Inside Window Background (Black = 0x0F)
    ; We will loop through rows 6 to 14 to draw the window bounds
    mov bl, 0x06    ; Start at row 6
window_loop:
    mov dh, bl      ; Set row
    mov dl, 15      ; Column 15
    call move_cursor
    mov al, 0xB3    ; │ (Left border)
    call print_char

    ; Clear the inside space to Black (Attribute 0x0F)
    push bx
    mov ah, 0x06
    mov al, 0x01
    mov bh, 0x0F    ; White on Black
    mov cl, 16      ; Col 16
    mov ch, bl      ; Current Row
    mov dl, 63      ; Col 63
    mov dh, bl      ; Current Row
    int 0x10
    pop bx

    mov dh, bl
    mov dl, 64      ; Column 64
    call move_cursor
    mov al, 0xB3    ; │ (Right border)
    call print_char

    inc bl
    cmp bl, 15      ; Stop before row 15
    jne window_loop

    ; Bottom Border: └ (0xC0) then 48 ─ (0xC4) then ┘ (0xD9)
    mov dx, 0x0F0F  ; Row 15, Col 15
    call move_cursor
    mov al, 0xC0    ; └
    call print_char
    mov cx, 48
draw_bottom_line:
    mov al, 0xC4    ; ─
    call print_char
    loop draw_bottom_line
    mov al, 0xD9    ; ┘
    call print_char

    ; --- 4. PRINT DITTOGUI INTERFACE TEXT ---
    mov dx, 0x0611  ; Row 6, Col 17
    mov si, win_title
    call print_string_at

    mov dx, 0x0811  ; Row 8, Col 17
    mov si, welcome_msg
    call print_string_at

    mov dx, 0x0C11  ; Row 12, Col 17
    mov si, prompt_str
    call print_string_at

    ; --- 5. HANG & BLINK CURSOR ---
    ; Position blinking cursor right after "DittoOS>"
    mov dx, 0x0C1B  ; Row 12, Col 27
    call move_cursor

halt:
    jmp halt        ; Infinite loop keeping the OS alive

; --- HELPERS ---
move_cursor:
    ; Expects DX = (Row, Col)
    mov ah, 0x02
    mov bh, 0x00    ; Page 0
    int 0x10
    ret

print_char:
    ; Expects AL = character code
    mov ah, 0x0E    ; Teletype output
    mov bh, 0x00
    int 0x10
    ret

print_string_at:
    ; Expects DX = destination, SI = string pointer
    call move_cursor
.loop:
    lodsb           ; Load next byte from SI into AL
    or al, al       ; Check if null terminator (0)
    jz .done
    call print_char
    jmp .loop
.done:
    ret

; --- DATA SECTIONS ---
top_bar_text db " DittoOS    File    Edit    Options    About", 0
win_title    db "--- DittoGUI v0.1 Sandbox ---", 0
welcome_msg  db "Welcome to your scratch-built OS!", 0
prompt_str   db "DittoOS>", 0

; --- BOOT SECTOR PAD ---
times 510-($-$$) db 0   ; Pad rest of the sector with 0s
dw 0xAA55               ; Standard x86 Boot Signature (Magic numbers)
