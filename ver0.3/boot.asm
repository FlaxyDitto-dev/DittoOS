[org 0x7c00]
bits 16

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; Reset floppy drive
    mov ah, 0x00
    mov dl, 0x00        ; Drive A:
    int 0x13

    ; Load DittoGUI Kernel from Sector 2 onwards
    mov ah, 0x02        ; BIOS Read Sectors function
    mov al, 4           ; Read 4 sectors
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Start reading from Sector 2
    mov dh, 0           ; Head 0
    mov dl, 0           ; Drive A:
    mov bx, 0x7E00      ; Load address in RAM
    int 0x13
    jc load_error       

    jmp 0x0000:0x7E00   ; Jump directly to the GUI kernel!

load_error:
    jmp load_error      

times 510-($-$$) db 0   
dw 0xAA55