; ============================================================
; FILE: src/ui.asm
; Module 8: Crisp Thin-Font HUD & State Banners
; ============================================================

hud_dirty       db 1
prev_hud_score  dw 0FFFFh
prev_hud_coins  db 0FFh
prev_hud_lives  db 0FFh

str_title       db "SUPER MARIO DOS", 0
str_start       db "PRESS ENTER TO START", 0
str_win         db "YOU WIN!", 0
str_gameover    db "GAME OVER", 0
str_restart     db "PRESS ENTER TO PLAY AGAIN", 0
str_hud_labels  db "SCORE       COINS   LIVES   TIME", 0

; ------------------------------------------------------------
; Thin 5x7 Bitmap Font (1-pixel strokes, ASCII 32..90)
; Each character is 7 bytes (rows 0..6), top 5 bits used
; ------------------------------------------------------------
font_5x7:
    db 00h,00h,00h,00h,00h,00h,00h ; 32 ' '
    db 20h,20h,20h,20h,20h,00h,20h ; 33 '!'
    times 13*7 db 00h              ; 34..46 (unused punctuation)
    db 08h,10h,10h,20h,40h,40h,80h ; 47 '/'
    db 70h,88h,98h,0A8h,0C8h,88h,70h ; 48 '0'
    db 20h,60h,20h,20h,20h,20h,70h ; 49 '1'
    db 70h,88h,08h,30h,40h,80h,0F8h ; 50 '2'
    db 70h,88h,08h,30h,08h,88h,70h ; 51 '3'
    db 10h,30h,50h,90h,0F8h,10h,10h ; 52 '4'
    db 0F8h,80h,0F0h,08h,08h,88h,70h ; 53 '5'
    db 30h,40h,80h,0F0h,88h,88h,70h ; 54 '6'
    db 0F8h,08h,10h,20h,40h,40h,40h ; 55 '7'
    db 70h,88h,88h,70h,88h,88h,70h ; 56 '8'
    db 70h,88h,88h,78h,08h,10h,60h ; 57 '9'
    times 7*7 db 00h               ; 58..64
    db 20h,50h,88h,88h,0F8h,88h,88h ; 65 'A'
    db 0F0h,88h,88h,0F0h,88h,88h,0F0h ; 66 'B'
    db 70h,88h,80h,80h,80h,88h,70h ; 67 'C'
    db 0E0h,90h,88h,88h,88h,90h,0E0h ; 68 'D'
    db 0F8h,80h,80h,0F0h,80h,80h,0F8h ; 69 'E'
    db 0F8h,80h,80h,0F0h,80h,80h,80h ; 70 'F'
    db 70h,88h,80h,0B8h,88h,88h,78h ; 71 'G'
    db 88h,88h,88h,0F8h,88h,88h,88h ; 72 'H'
    db 70h,20h,20h,20h,20h,20h,70h ; 73 'I'
    db 38h,10h,10h,10h,10h,90h,60h ; 74 'J'
    db 88h,90h,0A0h,0C0h,0A0h,90h,88h ; 75 'K'
    db 80h,80h,80h,80h,80h,80h,0F8h ; 76 'L'
    db 88h,0D8h,0A8h,0A8h,88h,88h,88h ; 77 'M'
    db 88h,0C8h,0A8h,98h,88h,88h,88h ; 78 'N'
    db 70h,88h,88h,88h,88h,88h,70h ; 79 'O'
    db 0F0h,88h,88h,0F0h,80h,80h,80h ; 80 'P'
    db 70h,88h,88h,88h,0A8h,90h,68h ; 81 'Q'
    db 0F0h,88h,88h,0F0h,0A0h,90h,88h ; 82 'R'
    db 70h,88h,80h,70h,08h,88h,70h ; 83 'S'
    db 0F8h,20h,20h,20h,20h,20h,20h ; 84 'T'
    db 88h,88h,88h,88h,88h,88h,70h ; 85 'U'
    db 88h,88h,88h,88h,88h,50h,20h ; 86 'V'
    db 88h,88h,88h,0A8h,0A8h,0D8h,88h ; 87 'W'
    db 88h,88h,50h,20h,50h,88h,88h ; 88 'X'
    db 88h,88h,50h,20h,20h,20h,20h ; 89 'Y'
    db 0F8h,08h,10h,20h,40h,80h,0F8h ; 90 'Z'

; ------------------------------------------------------------
; InitUI: resets HUD tracking flags
; ------------------------------------------------------------
InitUI:
    mov byte [hud_dirty], 1
    mov word [prev_hud_score], 0FFFFh
    mov byte [prev_hud_coins], 0FFh
    mov byte [prev_hud_lives], 0FFh
    ret

; ------------------------------------------------------------
; DrawChar8: draws thin 5x7 ASCII char AL at (BX=x, DX=y)
;            in color CL into [fb_seg]
; ------------------------------------------------------------
DrawChar8:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    sub al, 32
    jb .dc_done
    cmp al, 58
    ja .dc_done

    xor ah, ah
    mov si, ax
    shl si, 3
    sub si, ax                  ; SI = (AL - 32) * 7
    add si, font_5x7

    mov ch, 7                   ; 7 rows
.dc_row:
    lodsb
    mov ah, al
    push bx
    mov di, 5                   ; 5 columns
.dc_col:
    shl ah, 1
    jnc .dc_skip
    xor al, al
    mov al, cl
    push bx
    push dx
    push ax
    call PutPixel
.dc_skip:
    inc bx
    dec di
    jnz .dc_col
    pop bx
    inc dx
    dec ch
    jnz .dc_row

.dc_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; DrawString: draws null-terminated string DS:SI at (BX=x, DX=y)
;             with 6px character spacing (5px glyph + 1px gap)
; ------------------------------------------------------------
DrawString:
    push ax
    push bx
    push si
.ds_loop:
    lodsb
    cmp al, 0
    je .ds_done
    call DrawChar8
    add bx, 6
    jmp .ds_loop
.ds_done:
    pop si
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; DrawNumber: draws unsigned 16-bit AX padded to CH digits
;             at (BX=x, DX=8) in white
; ------------------------------------------------------------
DrawNumber:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov cl, ch
    xor ch, ch
    mov di, cx                  ; DI = target digit count
    xor si, si                  ; SI = digits pushed so far
    mov cx, 10
.dn_div:
    xor dx, dx
    div cx
    add dl, '0'
    push dx
    inc si
    cmp si, di
    jb .dn_div

    mov cl, COL_TEXT
    mov dx, 8
.dn_print:
    pop ax
    call DrawChar8
    add bx, 6
    dec si
    jnz .dn_print

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; UpdateTimerAndHUD: updates 1-second timer and redraws HUD
;                    immediately whenever score, coins, lives,
;                    or time changes, setting hud_dirty = 1
; ------------------------------------------------------------
UpdateTimerAndHUD:
    push ax
    push bx
    push cx
    push dx
    push si

    cmp byte [game_state], STATE_PLAYING
    jne .chk_values

    inc byte [sec_ticks]
    cmp byte [sec_ticks], TICKS_PER_SEC
    jb .chk_values
    mov byte [sec_ticks], 0

    cmp word [time_left], 0
    je .time_up
    dec word [time_left]
    mov byte [hud_dirty], 1
    jmp .chk_values

.time_up:
    call KillMario

.chk_values:
    mov ax, [score_lo]
    cmp ax, [prev_hud_score]
    jne .mark_dirty
    mov al, [coins]
    cmp al, [prev_hud_coins]
    jne .mark_dirty
    mov al, [lives]
    cmp al, [prev_hud_lives]
    jne .mark_dirty
    cmp byte [hud_dirty], 1
    jne near .uth_done

.mark_dirty:
    mov byte [hud_dirty], 1     ; tell mario.asm to copy top HUD strip to VGA!
    mov ax, [score_lo]
    mov [prev_hud_score], ax
    mov al, [coins]
    mov [prev_hud_coins], al
    mov al, [lives]
    mov [prev_hud_lives], al

    ; Clear HUD bar (0, 0, 320, 16) in [fb_seg]
    push 0
    push 0
    push SCREEN_W
    push HUD_HEIGHT
    push COL_HUD
    call FillRect

    ; Row 1 (Y=1): Crisp thin labels
    mov si, str_hud_labels
    mov bx, 16
    mov dx, 1
    mov cl, COL_TEXT
    call DrawString

    ; Row 2 (Y=8): Values aligned under labels
    mov ax, [score_lo]
    mov bx, 16
    mov ch, 6
    call DrawNumber

    mov al, [coins]
    xor ah, ah
    mov bx, 96
    mov ch, 2
    call DrawNumber

    mov al, [lives]
    xor ah, ah
    mov bx, 144
    mov ch, 2
    call DrawNumber

    mov ax, [time_left]
    mov bx, 186
    mov ch, 3
    call DrawNumber

.uth_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; DrawStateBanner: draws centered Title / Win / Game Over box
; ------------------------------------------------------------
DrawStateBanner:
    push ax
    push bx
    push cx
    push dx
    push si

    mov al, [game_state]
    cmp al, STATE_PLAYING
    je near .dsb_done

    push 64
    push 72
    push 192
    push 46
    push COL_TEXT
    call FillRect

    push 66
    push 74
    push 188
    push 42
    push 0
    call FillRect

    mov cl, COL_TEXT
    cmp byte [game_state], STATE_TITLE
    je .banner_title
    cmp byte [game_state], STATE_WIN
    je .banner_win

    ; --- GAME OVER ---
    mov si, str_gameover
    mov bx, 133
    mov dx, 84
    call DrawString
    mov si, str_restart
    mov bx, 85
    mov dx, 100
    call DrawString
    jmp .dsb_done

.banner_title:
    mov si, str_title
    mov bx, 115
    mov dx, 84
    call DrawString
    mov si, str_start
    mov bx, 100
    mov dx, 100
    call DrawString
    jmp .dsb_done

.banner_win:
    mov si, str_win
    mov bx, 136
    mov dx, 84
    call DrawString
    mov si, str_restart
    mov bx, 85
    mov dx, 100
    call DrawString

.dsb_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret