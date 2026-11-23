; ============================================================
; FILE: src/camera.asm
; Module 6: Fast Horizontal Screen Scroll & Edge Column Draw
; ============================================================

; ------------------------------------------------------------
; ScrollScreenLeft: shifts [fb_seg] rows 16..191 left by CX pixels
;                   and draws only the newly revealed right strip
; Inputs : CX = pixels scrolled right (1..4), [camera_x] = new camera X
; ------------------------------------------------------------
ScrollScreenLeft:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    ; 1. Fast RAM shift of rows 16..191 (176 scanlines) left by CX pixels in [fb_seg]
    mov ax, [fb_seg]
    mov ds, ax
    mov es, ax

    mov di, HUD_HEIGHT * SCREEN_W       ; start at row 16, col 0
    mov bx, VISIBLE_H - HUD_HEIGHT      ; 176 rows to shift
.shift_row:
    mov si, di
    add si, cx                          ; source = dest + scroll_delta
    push cx
    mov dx, SCREEN_W
    sub dx, cx                          ; bytes to copy = 320 - scroll_delta
    mov cx, dx
    cld
    rep movsb
    pop cx
    add di, cx
    dec bx
    jnz .shift_row

    pop es
    pop ds

    ; 2. Redraw only the 2 rightmost visible tile columns (cols 19 & 20)
    mov ax, [camera_x]
    mov cx, ax
    shr cx, 4
    and ax, 0Fh
    neg ax

    add cx, VISIBLE_COLS - 1
    add ax, (VISIBLE_COLS - 1) * TILE_SIZE
    mov [rl_start_x], ax
    mov [rl_start_col], cx

    mov di, 1
.edge_row_loop:
    cmp di, MAP_ROWS
    jge .ssl_done

    mov si, di
    shl si, 6
    mov ax, di
    shl ax, 2
    sub si, ax
    add si, [rl_start_col]

    mov dx, di
    shl dx, 4
    mov bx, [rl_start_x]

    mov al, [map_working + si]
    call DrawTile
    inc si
    add bx, TILE_SIZE
    mov al, [map_working + si]
    call DrawTile

    inc di
    jmp .edge_row_loop

.ssl_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret