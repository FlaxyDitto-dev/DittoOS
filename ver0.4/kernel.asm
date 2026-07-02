[org 0x7e00]
bits 16

start:
    ; --- 1. SET VIDEO MODE & BACKGROUND ---
    mov ah, 0x00
    mov al, 0x03    
    int 0x10

    mov ah, 0x06    
    mov al, 0x00    
    mov bh, 0x1F    ; White on Blue background
    mov cx, 0x0000  
    mov dx, 0x184F  
    int 0x10

    ; --- 2. INITIAL DRAWS ---
    call draw_top_bar
    call draw_window
    call draw_title_text
    call reset_prompt

; --- 3. MASTER INTERACTIVE LOOP ---
key_loop:
    mov ah, 0x00
    int 0x16        ; Wait for keypress (AH = Scan code, AL = ASCII)

    ; Check for Tab Key (Scan Code 0x0F) or F1 Key (Scan Code 0x3B) to switch modes
    cmp ah, 0x0F
    je toggle_mode
    cmp ah, 0x3B
    je toggle_mode

    ; Check current mode routing
    cmp byte [ui_mode], 1
    je menu_navigation_loop

    ; --- TERMINAL MODE LOGIC ---
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
    
    ; Echo character inside window
    mov ah, 0x09
    mov bh, 0x00
    mov bl, 0x0F    ; White text on Black
    mov cx, 1
    int 0x10
    
    call advance_cursor
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
    
    mov ah, 0x09
    mov al, ' '
    mov bl, 0x0F
    mov cx, 1
    int 0x10
    jmp key_loop

; --- MODE SWITCHING ---
toggle_mode:
    cmp byte [menu_open], 1
    je close_dropdown_and_toggle

    xor byte [ui_mode], 1  
    cmp byte [ui_mode], 1
    je enter_menu_mode

    ; Returning to Terminal Mode
    call draw_top_bar      
    mov dx, 0x0C1A
    add dx, [buffer_len]   
    call move_cursor
    jmp key_loop

close_dropdown_and_toggle:
    call remove_dropdown
    mov byte [ui_mode], 0
    call draw_top_bar
    call reset_prompt
    jmp key_loop

enter_menu_mode:
    mov byte [menu_index], 0
    call update_menu_highlights
    jmp key_loop

; --- MENU NAVIGATION LOGIC ---
menu_navigation_loop:
    cmp al, 0x0D    ; Enter Key?
    je handle_menu_enter

    cmp ah, 0x4D    ; Right Arrow?
    je menu_right

    cmp ah, 0x4B    ; Left Arrow?
    je menu_left

    cmp ah, 0x50    ; Down Arrow?
    je menu_down

    cmp ah, 0x48    ; Up Arrow?
    je menu_up

    jmp key_loop

menu_right:
    cmp byte [menu_open], 1
    je key_loop     
    cmp byte [menu_index], 3  
    jge key_loop
    inc byte [menu_index]
    call update_menu_highlights
    jmp key_loop

menu_left:
    cmp byte [menu_open], 1
    je key_loop     
    cmp byte [menu_index], 0  
    jle key_loop
    dec byte [menu_index]
    call update_menu_highlights
    jmp key_loop

menu_down:
    cmp byte [menu_open], 1
    jne key_loop
    cmp byte [sub_menu_index], 1
    jge key_loop
    inc byte [sub_menu_index]
    call draw_dropdown_contents
    jmp key_loop

menu_up:
    cmp byte [menu_open], 1
    jne key_loop
    cmp byte [sub_menu_index], 0
    jle key_loop
    dec byte [sub_menu_index]
    call draw_dropdown_contents
    jmp key_loop

handle_menu_enter:
    cmp byte [menu_open], 1
    je .execute_sub_option

    ; Otherwise, show the menu dropdown box
    mov byte [menu_open], 1
    mov byte [sub_menu_index], 0
    call draw_dropdown
    call draw_dropdown_contents  
    jmp key_loop

.execute_sub_option:
    cmp byte [sub_menu_index], 1 ; Index 1 is "Exit Shell"
    je .trigger_exit
    
    ; Index 0 ("Open Action") closes dropdown and restores console prompt layout cleanly
    call remove_dropdown
    call reset_prompt
    mov byte [ui_mode], 0
    jmp key_loop

.trigger_exit:
    call remove_dropdown
    mov dx, 0x1011
    mov si, exit_msg
    call print_string_at
.halt_loop:
    jmp .halt_loop

update_menu_highlights:
    call draw_top_bar 

    mov al, [menu_index]
    cmp al, 0
    je .hi_file
    cmp al, 1
    je .hi_edit
    cmp al, 2
    je .hi_options
    cmp al, 3
    je .hi_about
    ret

.hi_file:
    mov dx, 0x0004  
    mov si, m_file
    mov bl, 0x2F    ; Green background highlight
    call print_string_with_color
    ret
.hi_edit:
    mov dx, 0x0010  
    mov si, m_edit
    mov bl, 0x2F
    call print_string_with_color
    ret
.hi_options:
    mov dx, 0x001C  
    mov si, m_options
    mov bl, 0x2F
    call print_string_with_color
    ret
.hi_about:
    mov dx, 0x002C  
    mov si, m_about
    mov bl, 0x2F
    call print_string_with_color
    ret

; --- DROP DOWN BOX MANAGER ---
get_dropdown_col:
    mov dl, 0x04    
    mov al, [menu_index]
    cmp al, 0
    je .done
    mov dl, 0x10
    cmp al, 1
    je .done
    mov dl, 0x1C
    cmp al, 2
    je .done
    mov dl, 0x2C
.done:
    ret

draw_dropdown:
    call get_dropdown_col
    mov ch, 1       
    mov cl, dl      
    mov dh, 4       
    
    push dx         
    mov dl, cl      
    add dl, 15      
    
    mov ah, 0x06    
    mov al, 4       
    mov bh, 0x70    ; Black on Light Gray
    int 0x10
    
    pop dx          
    push dx         
    
    ; Row 1: Border ┌───┐
    mov dh, 1
    call move_cursor
    mov al, 0xDA    
    call print_char
    mov cx, 14
.top_l: 
    mov al, 0xC4 
    call print_char 
    loop .top_l
    mov al, 0xBF    
    call print_char

    ; Row 4: Border └───┘
    pop dx 
    push dx
    mov dh, 4
    call move_cursor
    mov al, 0xC0    
    call print_char
    mov cx, 14
.bot_l: 
    mov al, 0xC4 
    call print_char 
    loop .bot_l
    mov al, 0xD9    
    pop dx
    ret

draw_dropdown_contents:
    call get_dropdown_col
    
    ; --- ITEM 1 ROW ---
    push dx
    mov dh, 2
    call move_cursor
    mov al, 0xB3    ; │
    call print_char
    
    mov bl, 0x70    
    cmp byte [sub_menu_index], 0
    jne .print_i1
    mov bl, 0x2F    ; Highlight if active
.print_i1:
    mov si, m_item1
    call print_string_with_color
    
    pop dx 
    push dx 
    add dl, 15 
    mov dh, 2 
    call move_cursor
    mov al, 0xB3 
    call print_char

    ; --- ITEM 2 ROW ---
    pop dx 
    push dx
    mov dh, 3
    call move_cursor
    mov al, 0xB3    ; │
    call print_char
    
    mov bl, 0x70    
    cmp byte [sub_menu_index], 1
    jne .print_i2
    mov bl, 0x2F    ; Highlight if active
.print_i2:
    mov si, m_item2
    call print_string_with_color
    
    pop dx 
    add dl, 15 
    mov dh, 3 
    call move_cursor
    mov al, 0xB3 
    call print_char
    ret

remove_dropdown:
    mov ah, 0x06
    mov al, 4       
    mov bh, 0x1F    
    mov cx, 0x0100  
    mov dx, 0x044F  
    int 0x10
    
    call draw_window
    call draw_title_text
    mov byte [menu_open], 0
    call update_menu_highlights
    ret

; --- COMMAND PROCESSING ---
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

    ; FIX: Check if the user typed "CALC"
    mov si, cmd_buffer
    mov di, cmd_calc
    call strcmp
    jc do_calc

    mov dx, 0x0D11
    mov si, unknown_msg
    call print_string_at
    jmp hold_and_reset


do_calc:
    call 0x7E00 + 0x0800  ; Jump right to the memory space where app_calc is loaded!
    jmp do_cls            ; When the app returns, automatically wipe and reset the prompt
    
do_cls:
    mov ah, 0x06
    mov al, 0x09    
    mov bh, 0x0F    
    mov cx, 0x0610  
    mov dx, 0x0E3F  
    int 0x10
    
    call draw_title_text
    call reset_prompt
    jmp key_loop    

do_ver:
    mov dx, 0x0D11
    mov si, version_msg
    call print_string_at

hold_and_reset:
    mov ah, 0x00
    int 0x16
    jmp do_cls      

newline_prompt:
    call reset_prompt
    jmp key_loop    

; --- SCREEN COMPONENT FUNCTIONS ---
draw_top_bar:
    mov ah, 0x06
    mov al, 0x01    
    mov bh, 0x70    
    mov cx, 0x0000  
    mov dx, 0x004F  
    int 0x10

    mov dx, 0x0004  
    mov si, m_file
    mov bl, 0x70
    call print_string_with_color

    mov dx, 0x0010  
    mov si, m_edit
    mov bl, 0x70
    call print_string_with_color

    mov dx, 0x001C  
    mov si, m_options
    mov bl, 0x70
    call print_string_with_color

    mov dx, 0x002C  
    mov si, m_about
    mov bl, 0x70
    call print_string_with_color
    ret

draw_window:
    mov dx, 0x050F  
    call move_cursor
    mov al, 0xDA    
    call print_char
    mov cx, 48
.top_line:
    mov al, 0xC4    
    call print_char
    loop .top_line
    mov al, 0xBF    
    call print_char

    mov bl, 0x06    
.loop:
    mov dh, bl      
    mov dl, 15      
    call move_cursor
    mov al, 0xB3    
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
    mov al, 0xB3    
    call print_char

    inc bl
    cmp bl, 15      
    jne .loop

    mov dx, 0x0F0F  
    call move_cursor
    mov al, 0xC0    
    call print_char
    mov cx, 48
.bottom_line:
    mov al, 0xC4    
    call print_char
    loop .bottom_line
    mov al, 0xD9    
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

; --- UTILITIES ---
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

advance_cursor:
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    inc dl
    call move_cursor
    ret

print_string_at:
    mov bl, 0x0F    
print_string_with_color:
    call move_cursor
.loop:
    lodsb           
    or al, al       
    jz .done
    
    push ax
    mov ah, 0x09
    mov bh, 0x00
    mov cx, 1
    int 0x10
    call advance_cursor
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

; --- DATA SECTIONS ---
m_file       db "File", 0
m_edit       db "Edit", 0
m_options    db "Options", 0
m_about      db "About", 0

m_item1      db " Open Action ", 0
m_item2      db " Exit Shell  ", 0

win_title    db "--- DittoGUI v0.3 Workspace ---", 0
welcome_msg  db "Press [TAB] or [F1] to open the top menu!", 0
prompt_str   db "DittoOS>", 0
unknown_msg  db "Bad command! Press key...", 0
version_msg  db "DittoOS v0.3 (Menu Complete)", 0
exit_msg     db "Shell closed successfully. System halted.", 0

cmd_cls      db "CLS", 0
cmd_ver      db "VER", 0
cmd_calc     db "CALC", 0

; --- STATE VARIABLES ---
ui_mode      db 0    
menu_index   db 0    
menu_open    db 0    
sub_menu_index db 0  

buffer_len   dw 0
cmd_buffer   times 16 db 0