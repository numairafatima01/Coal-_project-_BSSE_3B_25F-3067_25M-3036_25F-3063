; ============================================================
; FILE: src/video.asm
; VGA Mode 13h Setup & Double-Buffered Drawing
; ============================================================

; ------------------------------------------------------------
; SetVideoMode: switches screen to 320x200 256-color Mode 13h
; ------------------------------------------------------------
SetVideoMode:
    push ax
    mov ax, 0013h
    int 10h
    pop ax
    ret

; ------------------------------------------------------------
; SetTextMode: restores standard 80x25 text mode (03h) on exit
; ------------------------------------------------------------
SetTextMode:
    push ax
    mov ax, 0003h
    int 10h
    pop ax
    ret

; ------------------------------------------------------------
; PutPixel: draws a single pixel into [fb_seg]
; Stack args: [bp+8]=x, [bp+6]=y, [bp+4]=color, ret 6
; ------------------------------------------------------------
PutPixel:
    push bp
    mov bp, sp
    push ax
    push bx
    push dx
    push di
    push es

    mov bx, [bp + 8]            ; x
    mov dx, [bp + 6]            ; y
    mov al, [bp + 4]            ; color

    cmp bx, 0
    jl .pp_done
    cmp bx, SCREEN_W
    jge .pp_done
    cmp dx, 0
    jl .pp_done
    cmp dx, SCREEN_H
    jge .pp_done

    ; offset = y * 320 + x = (y * 256) + (y * 64) + x
    mov di, dx
    shl di, 8
    shl dx, 6
    add di, dx
    add di, bx

    mov es, [fb_seg]
    mov [es:di], al

.pp_done:
    pop es
    pop di
    pop dx
    pop bx
    pop ax
    pop bp
    ret 6

; ------------------------------------------------------------
; FillRect: draws a filled rectangle into [fb_seg]
; Stack args:
;   [bp+12] = x
;   [bp+10] = y
;   [bp+8]  = width
;   [bp+6]  = height
;   [bp+4]  = color
;   ret 10
; ------------------------------------------------------------
FillRect:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov bx, [bp + 12]           ; x
    mov dx, [bp + 10]           ; y
    mov si, [bp + 8]            ; width
    mov cx, [bp + 6]            ; height
    mov al, [bp + 4]            ; color

    ; Clip top/bottom
    cmp dx, SCREEN_H
    jge near .fr_done
    cmp dx, 0
    jge .fr_chk_bot
    add cx, dx
    xor dx, dx
.fr_chk_bot:
    cmp cx, 0
    jle near .fr_done
    mov di, dx
    add di, cx
    cmp di, SCREEN_H
    jle .fr_clip_x
    mov cx, SCREEN_H
    sub cx, dx

.fr_clip_x:
    ; Clip left/right
    cmp bx, SCREEN_W
    jge near .fr_done
    cmp bx, 0
    jge .fr_chk_right
    add si, bx
    xor bx, bx
.fr_chk_right:
    cmp si, 0
    jle near .fr_done
    mov di, bx
    add di, si
    cmp di, SCREEN_W
    jle .fr_draw
    mov si, SCREEN_W
    sub si, bx

.fr_draw:
    ; Compute starting offset = y * 320 + x
    mov di, dx
    shl di, 8
    shl dx, 6
    add di, dx
    add di, bx

    mov es, [fb_seg]
    cld

.fr_row:
    push cx
    push di
    mov cx, si
    rep stosb
    pop di
    pop cx
    add di, SCREEN_W
    loop .fr_row

.fr_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

; ------------------------------------------------------------
; FlipBackBuffer: copies game area (rows 16..191) from [fb_seg]
;                 to VGA screen (0A000h) in one burst
; ------------------------------------------------------------
FlipBackBuffer:
    push ax
    push cx
    push si
    push di
    push ds
    push es

    mov ax, VIDEO_SEG
    mov es, ax
    mov ax, [fb_seg]
    mov ds, ax

    mov si, HUD_HEIGHT * SCREEN_W       ; row 16 (offset 5120)
    mov di, si
    mov cx, (VISIBLE_H - HUD_HEIGHT) * SCREEN_W / 2 ; 176 * 160 words
    cld
    rep movsw

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret

; ------------------------------------------------------------
; FlipFullBuffer: copies entire 320x200 screen (including HUD)
;                 from [fb_seg] to VGA screen (0A000h)
; ------------------------------------------------------------
FlipFullBuffer:
    push ax
    push cx
    push si
    push di
    push ds
    push es

    mov ax, VIDEO_SEG
    mov es, ax
    mov ax, [fb_seg]
    mov ds, ax

    xor si, si
    xor di, di
    mov cx, SCREEN_W * SCREEN_H / 2     ; 32,000 words (64,000 bytes)
    cld
    rep movsw

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret