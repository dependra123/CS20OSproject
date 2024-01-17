org 0
bits 16

%define ENDL 0x0D, 0x0A


start:


    ;print hello world
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

;
; Prints string to screen
; Parmas:
;   ds:si - pointer to string
;

puts:
    ;save modifed regesters
    push si
    push ax

.loop:
    lodsb           ;load byte from ds:si into al and increment si
    or al, al       ;oring a value will modify the zero flag if the value is null
    jz .done        ;if the value is null then jump to done
    mov ah, 0x0e    ;calls bios inturept
    mov bh,0
    int 0x10        ;print the character in al
    jmp .loop       ;else jump back to loop

.done:
    ;restore regesters
    pop ax
    pop si
    ret

msg_hello: db 'HELLO WORLD from the KERNEL!!!!!',ENDL, 0
