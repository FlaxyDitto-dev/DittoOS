[org 0x7e00]
bits 16

start:
    ; --- 1. SET VIDEO MODE & BACKGROUND ---
    mov ah, 0x00
    mov al, 0x03    
    int 0x10

    call refresh_desktop

; --- 2. MASTER INTERACTIVE LOOP ---
key_loop:
    mov ah, 0x00
    int 0x16        

    cmp ah, 0x0F    ; Tab
    je toggle_mode
    cmp ah, 0x3B    ; F1
    je toggle_mode

    cmp byte [ui_mode], 1
    je menu_navigation_loop

    ; --- TERMINAL MODE LOGIC ---
    cmp al, 0x0D    
    je execute_command

    cmp al, 0x08    
    je handle_backspace

    cmp al, 0x20    
    jl key_loop     

    mov si, cmd_buffer
    add si, [buffer_len]
    cmp byte [buffer_len], 15
    jge key_loop

    mov [si], al
    inc word [buffer_len]
    
    mov ah, 0x09
    mov bh, 0x00
    mov bl, 0x0F    
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

    call draw_top_bar      
    call update_cursor_position
    jmp key_loop

close_dropdown_and_toggle:
    call remove_dropdown
    mov byte [ui_mode], 0
    call draw_top_bar
    call update_cursor_position
    jmp key_loop

enter_menu_mode:
    mov byte [menu_index], 0
    call update_menu_highlights
    jmp key_loop

; --- MENU NAVIGATION LOGIC & DRAGGING ---
menu_navigation_loop:
    cmp al, 0x0D    
    je handle_menu_enter

    cmp byte [menu_open], 1
    je .dropdown_nav

    ; NEW FEATURE: Press 'c' to Close Window completely
    cmp al, 'c'
    je close_window_action

    cmp al, 'w'
    je drag_up
    cmp al, 's'
    je drag_down
    cmp al, 'a'
    je drag_left
    cmp al, 'd'
    je drag_right

    cmp ah, 0x4D    
    je menu_right
    cmp ah, 0x4B    
    je menu_left
    jmp key_loop

.dropdown_nav:
    cmp ah, 0x50    
    je menu_down
    cmp ah, 0x48    
    je menu_up
    jmp key_loop

close_window_action:
    mov byte [win_visible], 0
    call remove_dropdown
    call refresh_desktop
    mov byte [ui_mode], 0
    jmp key_loop

drag_up:
    cmp byte [win_row], 2
    jle key_loop
    dec byte [win_row]
    call perform_window_move
    jmp key_loop

drag_down:
    cmp byte [win_row], 14
    jge key_loop
    inc byte [win_row]
    call perform_window_move
    jmp key_loop

drag_left:
    cmp byte [win_col], 1
    jle key_loop
    dec byte [win_col]
    call perform_window_move
    jmp key_loop

drag_right:
    cmp byte [win_col], 30
    jge key_loop
    inc byte [win_col]
    call perform_window_move
    jmp key_loop

perform_window_move:
    cmp byte [win_visible], 0
    je key_loop    ; Can't drag what isn't visible!
    call refresh_desktop
    call update_menu_highlights
    ret

menu_right:
    cmp byte [menu_index], 3  
    jge key_loop
    inc byte [menu_index]
    call update_menu_highlights
    jmp key_loop

menu_left:
    cmp byte [menu_index], 0  
    jle key_loop
    dec byte [menu_index]
    call update_menu_highlights
    jmp key_loop

menu_down:
    cmp byte [sub_menu_index], 1
    jge key_loop
    inc byte [sub_menu_index]
    call draw_dropdown_contents
    jmp key_loop

menu_up:
    cmp byte [sub_menu_index], 0
    jle key_loop
    dec byte [sub_menu_index]
    call draw_dropdown_contents
    jmp key_loop

handle_menu_enter:
    cmp byte [menu_open], 1
    je .execute_sub_option

    mov byte [menu_open], 1
    mov byte [sub_menu_index], 0
    call draw_dropdown
    call draw_dropdown_contents  
    jmp key_loop

.execute_sub_option:
    cmp byte [sub_menu_index], 1 
    je .trigger_exit
    
    call remove_dropdown
    call refresh_desktop
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
    mov bl, 0x2F    
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

; --- REFRESH DESKTOP ---
refresh_desktop:
    mov ah, 0x06    
    mov al, 0x00    
    mov bh, 0x1F    
    mov cx, 0x0100  
    mov dx, 0x184F  
    int 0x10

    call draw_top_bar
    
    cmp byte [win_visible], 1
    jne .skip_win
    call draw_window
    call draw_title_text
    call draw_prompt_text
    ret
.skip_win:
    ; If window hidden, cursor rests safely at top-left corner
    mov dx, 0x0202
    call move_cursor
    ret

update_cursor_position:
    cmp byte [win_visible], 0
    je .rest
    mov dh, [win_row]
    add dh, 7       
    mov dl, [win_col]
    add dl, 11      
    add dl, [buffer_len]
    call move_cursor
    ret
.rest:
    mov dx, 0x0202
    call move_cursor
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

    mov si, cmd_buffer
    mov di, cmd_calc
    call strcmp
    jc do_calc

    ; NEW v0.6 DittoFS COMMANDS
    mov si, cmd_buffer
    mov di, cmd_dir
    call strcmp
    jc do_dir

    mov si, cmd_buffer
    mov di, cmd_open
    call strcmp
    jc do_open

    ; If window hidden, prevent console printing errors inside a hidden box
    cmp byte [win_visible], 0
    je do_cls

    mov dh, [win_row]
    add dh, 8
    mov dl, [win_col]
    add dl, 2
    mov si, unknown_msg
    call print_string_at
    jmp hold_and_reset

do_calc:
    cmp byte [win_visible], 0
    je do_cls
    call 0x7E00 + 0x0800  ; Load segment of app_calc
    jmp do_cls            

do_dir:
    cmp byte [win_visible], 0
    je do_cls
    call 0x7E00 + 0x0A00  ; Jump to sector of NEW app_files
    jmp do_cls

do_open:
    mov byte [win_visible], 1
    call refresh_desktop
    jmp key_loop

do_cls:
    mov word [buffer_len], 0
    call refresh_desktop
    jmp key_loop    

do_ver:
    cmp byte [win_visible], 0
    je do_cls
    mov dh, [win_row]
    add dh, 8
    mov dl, [win_col]
    add dl, 2
    mov si, version_msg
    call print_string_at

hold_and_reset:
    mov ah, 0x00
    int 0x16
    jmp do_cls      

newline_prompt:
    mov word [buffer_len], 0
    call refresh_desktop
    jmp key_loop    

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
    mov bh, 0x70    
    int 0x10
    pop dx          
    push dx         
    
    mov dh, 1
    call move_cursor
    mov al, 0xDA    
    call print_char
    mov cx, 14
.top_l: mov al, 0xC4 \ call print_char \ loop .top_l
    mov al, 0xBF    
    call print_char

    pop dx \ push dx
    mov dh, 4
    call move_cursor
    mov al, 0xC0    
    call print_char
    mov cx, 14
.bot_l: mov al, 0xC4 \ call print_char \ loop .bot_l
    mov al, 0xD9    
    pop dx
    ret

draw_dropdown_contents:
    call get_dropdown_col
    push dx
    mov dh, 2
    call move_cursor
    mov al, 0xB3    
    call print_char
    mov bl, 0x70    
    cmp byte [sub_menu_index], 0
    jne .print_i1
    mov bl, 0x2F    
.print_i1:
    mov si, m_item1
    call print_string_with_color
    pop dx \ push dx \ add dl, 15 \ mov dh, 2 \ call move_cursor
    mov al, 0xB3 \ call print_char

    pop dx \ push dx
    mov dh, 3
    call move_cursor
    mov al, 0xB3    
    call print_char
    mov bl, 0x70    
    cmp byte [sub_menu_index], 1
    jne .print_i2
    mov bl, 0x2F    
.print_i2:
    mov si, m_item2
    call print_string_with_color
    pop dx \ add dl, 15 \ mov dh, 3 \ call move_cursor
    mov al, 0xB3 \ call print_char
    ret

remove_dropdown:
    mov byte [menu_open], 0
    ret

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
    mov dh, [win_row]
    mov dl, [win_col]
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

    mov al, [win_row]
    inc al
    mov bl, al       
.loop:
    mov dh, bl      
    mov dl, [win_col]      
    call move_cursor
    mov al, 0xB3    
    call print_char

    push bx
    mov ah, 0x06
    mov al, 0x01
    mov bh, 0x0F    
    mov cl, [win_col]      
    inc cl
    mov ch, bl      
    mov dl, [win_col]      
    add dl, 48
    mov dh, bl      
    int 0x10
    pop bx

    mov dh, bl
    mov dl, [win_col]      
    add dl, 49
    call move_cursor
    mov al, 0xB3    
    call print_char

    inc bl
    mov al, [win_row]
    add al, 10      
    cmp bl, al      
    jne .loop

    mov dh, bl
    mov dl, [win_col]
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
    mov dh, [win_row]
    add dh, 1
    mov dl, [win_col]
    add dl, 2
    mov si, win_title
    call print_string_at

    mov dh, [win_row]
    add dh, 3
    mov dl, [win_col]
    add dl, 2
    mov si, welcome_msg
    call print_string_at
    ret

draw_prompt_text:
    mov dh, [win_row]
    add dh, 7
    mov dl, [win_col]
    add dl, 2
    mov si, prompt_str
    call print_string_at
    
    mov cx, 16
    mov di, cmd_buffer
.clear_buf:
    mov byte [di], 0
    inc di
    loop .clear_buf

    call update_cursor_position
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

win_title    db "--- DittoGUI v0.6 Workspace ---", 0
welcome_msg  db "Hotkeys active. Press [C] in Menu to close window!", 0
prompt_str   db "DittoOS>", 0
unknown_msg  db "Bad command! Press key...", 0
version_msg  db "DittoOS v0.6 (DittoFS Edition)", 0
exit_msg     db "Shell closed successfully. System halted.", 0

cmd_cls      db "CLS", 0
cmd_ver      db "VER", 0
cmd_calc     db "CALC", 0
cmd_dir      db "DIR", 0
cmd_open     db "OPEN", 0

; --- POSITION AND STATE VARIABLES ---
win_row      db 5    
win_col      db 15   
win_visible  db 1    ; 1 = Drawn, 0 = Hidden

ui_mode      db 0    
menu_index   db 0    
menu_open    db 0    
sub_menu_index db 0  

buffer_len   dw 0
cmd_buffer   times 16 db 0