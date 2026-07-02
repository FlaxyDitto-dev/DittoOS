[org 0x7e00]
bits 16

start:
    ; --- 1. SET VIDEO MODE & BACKGROUND ---
    mov ah, 0x00
    mov al, 0x03    
    int 0x10

    mov ah, 0x06    
    mov al, 0x00    
    mov bh, 0x1F    ; White on Blue
    mov cx, 0x0000  
    mov dx, 0x184F  
    int 0x10

    ; --- 2. DRAW DITTOGUI TOP BAR ---
    mov ah, 0x06
    mov al, 0x01    
    mov bh, 0x70    ; Black on Light Gray
    mov cx, 0x0000  
    mov dx, 0x004F  
    int 0x10

    mov dx, 0x0002  
    mov si, top_bar_text
    call print_string_at

    ; --- 3. DRAW DITTOGUI WINDOW ---
    call draw_window
    call draw_title_text

    ; --- 5. INITIALIZE THE PROMPT ---
    call reset_prompt

; --- 6. KEYBOARD INTERACTIVE LOOP ---
key_loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D    ; Enter Key?
    je execute_command

    cmp al, 0x08    ; Backspace Key?
    je handle_backspace

    cmp al, 0x20    ; Printable char?
    jl key_loop     

    mov si, cmd_buffer
    add si, [buffer_len]
    cmp byte [buffer_len], 15
    jge key_loop

    mov [si], al
    inc word [buffer_len]
    
    ; Echo character explicitly ensuring White-on-Black text inside window
    mov ah, 0x09    ; Write character and attribute
    mov bh, 0x00    ; Page 0
    mov bl, 0x0F    ; White text (0xF) on Black background (0x0)
    mov cx, 1       ; Print 1 character
    int 0x10
    
    ; Advance the cursor forward 1 position manually
    mov ah, 0x03    ; Get cursor position
    mov bh, 0x00
    int 0x10
    inc dl          ; Advance column
    call move_cursor
    
    jmp key_loop

handle_backspace:
    cmp byte [buffer_len], 0
    je key_loop     
    
    dec word [buffer_len]
    mov si, cmd_buffer
    add si, [buffer_len]
    mov byte [si], 0 

    mov ah, 0x03    
    mov bh, 0x00
    int 0x10        
    dec dl          
    call move_cursor
    
    ; Erase character with black background attribute
    mov ah, 0x09
    mov al, ' '
    mov bl, 0x0F
    mov cx, 1
    int 0x10
    jmp key_loop

execute_command:
    mov si, cmd_buffer
    add si, [buffer_len]
    mov byte [si], 0

    cmp byte [buffer_len], 0
    je newline_prompt 

    mov si, cmd_buffer
    mov di, cmd_cls
    call strcmp
    jc do_cls

    mov si, cmd_buffer
    mov di, cmd_ver
    call strcmp
    jc do_ver

    mov dx, 0x0D11
    mov si, unknown_msg
    call print_string_at
    jmp hold_and_reset

do_cls:
    ; Clear inside the window box cleanly
    mov ah, 0x06
    mov al, 0x09    ; Clear 9 rows inside window
    mov bh, 0x0F    ; White on Black
    mov cx, 0x0610  
    mov dx, 0x0E3F  
    int 0x10
    
    call draw_title_text
    call reset_prompt
    jmp key_loop    ; Re-entry back into keyboard engine safely

do_ver:
    mov dx, 0x0D11
    mov si, version_msg
    call print_string_at

hold_and_reset:
    ; Pause so the user can actually read the output text
    mov ah, 0x00
    int 0x16
    jmp do_cls      ; Wipes screen and routes back to loop cleanly

newline_prompt:
    call reset_prompt
    jmp key_loop    ; Cycles back empty enters safely

draw_window:
    mov dx, 0x050F  
    call move_cursor
    mov al, 0xDA    ; ┌
    call print_char
    mov cx, 48
.top_line:
    mov al, 0xC4    ; ─
    call print_char
    loop .top_line
    mov al, 0xBF    ; ┐
    call print_char

    mov bl, 0x06    
.loop:
    mov dh, bl      
    mov dl, 15      
    call move_cursor
    mov al, 0xB3    ; │
    call print_char

    push bx
    mov ah, 0x06
    mov al, 0x01
    mov bh, 0x0F    
    mov cl, 16      
    mov ch, bl      
    mov dl, 63      
    mov dh, bl      
    int 0x10
    pop bx

    mov dh, bl
    mov dl, 64      
    call move_cursor
    mov al, 0xB3    ; │
    call print_char

    inc bl
    cmp bl, 15      
    jne .loop

    mov dx, 0x0F0F  
    call move_cursor
    mov al, 0xC0    ; └
    call print_char
    mov cx, 48
.bottom_line:
    mov al, 0xC4    ; ─
    call print_char
    loop .bottom_line
    mov al, 0xD9    ; ┘
    call print_char
    ret

draw_title_text:
    mov dx, 0x0611  
    mov si, win_title
    call print_string_at

    mov dx, 0x0811  
    mov si, welcome_msg
    call print_string_at
    ret

reset_prompt:
    mov word [buffer_len], 0
    mov cx, 16
    mov di, cmd_buffer
.clear_buf:
    mov byte [di], 0
    inc di
    loop .clear_buf

    mov dx, 0x0C11  
    mov si, prompt_str
    call print_string_at
    mov dx, 0x0C1A  
    call move_cursor
    ret

move_cursor:
    mov ah, 0x02
    mov bh, 0x00    
    int 0x10
    ret

print_char:
    mov ah, 0x0E    
    mov bh, 0x00
    int 0x10
    ret

print_string_at:
    call move_cursor
.loop:
    lodsb           
    or al, al       
    jz .done
    
    push ax
    mov ah, 0x09
    mov bh, 0x00
    mov bl, 0x0F    
    mov cx, 1
    int 0x10
    
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    inc dl
    call move_cursor
    pop ax
    
    jmp .loop
.done:
    ret

strcmp:
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    or al, al
    jz .equal
    inc si
    inc di
    jmp .loop
.not_equal:
    clc
    ret
.equal:
    stc
    ret

top_bar_text db " DittoOS    File    Edit    Options    About", 0
win_title    db "--- DittoGUI v0.2 Workspace ---", 0
welcome_msg  db "Interactive engine loaded successfully.", 0
prompt_str   db "DittoOS>", 0
unknown_msg  db "Bad command! Press key...", 0
version_msg  db "DittoOS v0.2 (Interactive)", 0

cmd_cls      db "CLS", 0
cmd_ver      db "VER", 0

buffer_len   dw 0
cmd_buffer   times 16 db 0