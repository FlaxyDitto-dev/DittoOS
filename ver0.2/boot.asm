[org 0x7c00]
bits 16

start:
    ; Set up segment registers
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
    mov al, 4           ; Number of sectors to read (2KB space)
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Start reading from Sector 2
    mov dh, 0           ; Head 0
    mov dl, 0           ; Drive A:
    mov bx, 0x7E00      ; Load it right after the bootloader in RAM
    int 0x13
    jc load_error       ; Loop if read failed

    jmp 0x0000:0x7E00   ; Jump directly to the loaded GUI code!

load_error:
    jmp load_error      ; Infinite hang if disk fails

times 510-($-$$) db 0   
dw 0xAA55               ; Boot signature