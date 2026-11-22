; =============================================================================
; SPRITE PALETTE LEGEND (VGA Mode 13h Default 256-Colour Palette)
; =============================================================================
;  0  = Transparent (skipped by DrawSprite so background sky/tiles show through)
;  4  = Red (Mario cap & shirt)
;  6  = Brown (Mario hair, boots, Goomba cap, Koopa shell trim)
;  14 = Yellow (Overall buttons, Koopa skin/beak, Mushroom spots)
;  15 = White (Gloves, eyes, Mushroom spots/stem)
;  43 = Peach / Skin tone (Mario face & hands)
;  1  = Blue (Mario overalls)
;  2  = Green (Koopa shell)
;  8  = Dark Grey / Black outline (eyes & shoes)
; =============================================================================

; ------------------------------------------------------------
; Name     : DrawSprite16
; Purpose  : draws a 16x16 bitmap sprite at screen (BX, DX) with transparency
;            and optional horizontal mirroring (flip = 0 right, 1 left)
; Inputs   : SI = pointer to 256-byte (16x16) sprite bitmap
;            BX = screen left X (signed), DX = screen top Y (signed)
;            AL = flip flag (0 = normal right-facing, 1 = mirrored left-facing)
; Outputs  : draws non-zero pixels via PutPixel (clips automatically)
; Changes  : none (all registers saved and restored)
; ------------------------------------------------------------
DrawSprite16:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Quick horizontal culling if completely off-screen
    cmp bx, -16
    jle near .ds_done
    cmp bx, SCREEN_W
    jge near .ds_done

    mov [ds_flip], al           ; save flip flag (0 or 1)
    mov [ds_base_x], bx         ; save starting left X
    mov [ds_curr_y], dx         ; save current Y

    mov cx, 16                  ; 16 rows tall
.row_loop:
    push cx                     ; save outer row counter

    mov bx, [ds_base_x]         ; reset screen X to left edge of sprite
    xor di, di                  ; DI = column index (0..15)

.col_loop:
    push bx                     ; temporarily save screen X
    mov bx, si                  ; BX = base pointer to current sprite row

    cmp byte [ds_flip], 0
    je .no_flip
    mov ax, 15
    sub ax, di                  ; AX = 15 - DI (mirrored column)
    add bx, ax
    mov al, [bx]                ; read mirrored pixel colour
    jmp .got_pixel

.no_flip:
    mov al, [bx + di]           ; read normal pixel colour

.got_pixel:
    pop bx                      ; restore screen X

    cmp al, 0                   ; 0 = transparent pixel -> skip
    je .next_col

    ; Call stack-based PutPixel(x = BX, y = [ds_curr_y], colour = AL)
    xor ah, ah
    push bx                     ; [bp+8] = x
    push word [ds_curr_y]       ; [bp+6] = y
    push ax                     ; [bp+4] = colour
    call PutPixel               ; PutPixel clips x>=320 / y>=200 and cleans stack

.next_col:
    inc bx                      ; advance screen X by 1 pixel
    inc di                      ; advance sprite column (0..15)
    cmp di, 16
    jb .col_loop

    add si, 16                  ; advance bitmap pointer to next row (16 bytes)
    inc word [ds_curr_y]        ; advance screen Y by 1 pixel
    pop cx                      ; restore outer row counter
    loop .row_loop

.ds_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ds_flip         db 0
ds_base_x       dw 0
ds_curr_y       dw 0

; =============================================================================
; 16x16 BITMAP DATA TABLES (256 bytes each)
; =============================================================================

; --- SMALL MARIO: STANDING (pose = 0) ---
spr_mario_small_stand:
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,0,0,0
    db 0,0,0,0,6,6,6,43,43,8,43,0,0,0,0,0
    db 0,0,0,6,43,6,43,43,43,8,43,43,43,0,0,0
    db 0,0,0,6,43,6,6,43,43,43,6,43,43,43,0,0
    db 0,0,0,6,6,43,43,43,43,6,6,6,6,0,0,0
    db 0,0,0,0,0,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,0,4,4,1,4,4,4,0,0,0,0,0,0
    db 0,0,0,4,4,4,1,4,4,1,4,4,4,0,0,0
    db 0,0,4,4,4,4,1,1,1,1,4,4,4,4,0,0
    db 0,0,43,43,4,1,14,1,1,14,1,4,43,43,0,0
    db 0,0,43,43,43,1,1,1,1,1,1,43,43,43,0,0
    db 0,0,43,43,1,1,1,1,1,1,1,1,43,43,0,0
    db 0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0
    db 0,0,0,6,6,6,0,0,0,0,6,6,6,0,0,0
    db 0,0,6,6,6,6,0,0,0,0,6,6,6,6,0,0

; --- SMALL MARIO: RUNNING STRIDE (pose = 1) ---
spr_mario_small_run:
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,0,0,0
    db 0,0,0,0,6,6,6,43,43,8,43,0,0,0,0,0
    db 0,0,0,6,43,6,43,43,43,8,43,43,43,0,0,0
    db 0,0,0,6,43,6,6,43,43,43,6,43,43,43,0,0
    db 0,0,0,6,6,43,43,43,43,6,6,6,6,0,0,0
    db 0,0,0,0,0,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,4,4,4,1,4,4,1,4,4,0,0,0,0
    db 0,43,43,4,4,4,1,1,1,1,4,4,43,43,0,0
    db 0,43,43,0,1,1,1,14,1,1,1,0,43,43,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,1,1,1,1,0,0,0,1,1,1,1,0,0,0
    db 0,6,6,6,0,0,0,0,0,0,6,6,6,0,0,0
    db 0,6,6,0,0,0,0,0,0,0,0,6,6,6,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; --- SMALL MARIO: JUMPING (pose = 2) ---
spr_mario_small_jump:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,43,43,43
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,43,43,43
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,4,4,0
    db 0,0,0,0,6,6,6,43,43,8,43,0,4,4,0,0
    db 0,0,0,6,43,6,43,43,43,8,43,43,43,0,0,0
    db 0,0,0,6,43,6,6,43,43,43,6,43,43,43,0,0
    db 0,0,0,6,6,43,43,43,43,6,6,6,6,0,0,0
    db 0,0,0,0,0,43,43,43,43,43,43,43,0,0,0,0
    db 0,4,4,4,4,4,1,4,4,4,1,4,0,0,0,0
    db 43,43,4,4,4,1,1,1,1,1,1,0,0,0,0,0
    db 43,43,0,1,1,1,14,1,1,14,1,1,0,0,0,0
    db 0,0,1,1,1,1,1,1,1,1,1,1,1,6,0,0
    db 0,6,1,1,1,1,1,1,1,1,1,1,1,6,0,0
    db 0,6,6,0,0,0,0,0,0,0,1,1,1,6,0,0
    db 0,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; --- SUPER MARIO TOP HALF (16x16 upper head & chest) ---
spr_super_top:
    db 0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,4,0,0
    db 0,0,0,0,6,6,6,43,43,8,43,0,0,0,0,0
    db 0,0,0,6,43,6,43,43,43,8,43,43,43,0,0,0
    db 0,0,0,6,43,6,6,43,43,43,6,43,43,43,0,0
    db 0,0,0,6,6,43,43,43,43,6,6,6,6,0,0,0
    db 0,0,0,0,0,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,0,4,4,4,1,4,4,4,0,0,0,0,0
    db 0,0,0,4,4,4,4,1,4,4,4,4,0,0,0,0
    db 0,0,4,4,4,4,4,1,1,4,4,4,4,0,0,0
    db 0,0,4,4,4,4,1,1,1,1,4,4,4,0,0,0
    db 0,0,43,43,4,4,1,1,1,1,4,4,43,43,0,0
    db 0,0,43,43,43,1,14,1,1,14,1,43,43,43,0,0
    db 0,0,43,43,43,1,1,1,1,1,1,43,43,43,0,0
    db 0,0,0,43,1,1,1,1,1,1,1,1,43,0,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0

; --- SUPER MARIO BOTTOM HALF: STANDING (16x16 legs & boots) ---
spr_super_bot_stand:
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,0,1,1,1,1,0,0,1,1,1,1,0,0,0
    db 0,0,0,1,1,1,1,0,0,1,1,1,1,0,0,0
    db 0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0
    db 0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0
    db 0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0
    db 0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0
    db 0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0
    db 0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0
    db 0,0,0,6,6,6,0,0,0,0,6,6,6,0,0,0
    db 0,0,6,6,6,6,0,0,0,0,6,6,6,6,0,0
    db 0,0,6,6,6,6,0,0,0,0,6,6,6,6,0,0
    db 0,6,6,6,6,6,0,0,0,0,6,6,6,6,6,0
    db 0,6,6,6,6,6,0,0,0,0,6,6,6,6,6,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; --- SUPER MARIO BOTTOM HALF: RUNNING (16x16 legs & boots) ---
spr_super_bot_run:
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,1,1,1,1,0,0,0,1,1,1,1,0,0,0
    db 0,0,1,1,1,0,0,0,0,0,1,1,1,1,0,0
    db 0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0
    db 0,1,1,0,0,0,0,0,0,0,0,0,1,1,0,0
    db 0,6,6,0,0,0,0,0,0,0,0,0,6,6,6,0
    db 6,6,6,0,0,0,0,0,0,0,0,0,6,6,6,6
    db 6,6,0,0,0,0,0,0,0,0,0,0,0,6,6,6
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; --- GOOMBA: WALKING (16x16) ---
spr_goomba_walk:
    db 0,0,0,0,0,0,6,6,6,6,0,0,0,0,0,0
    db 0,0,0,0,0,6,6,6,6,6,6,0,0,0,0,0
    db 0,0,0,0,6,6,6,6,6,6,6,6,0,0,0,0
    db 0,0,0,6,6,6,6,6,6,6,6,6,6,0,0,0
    db 0,0,6,6,8,6,6,6,6,6,6,8,6,6,0,0
    db 0,6,6,6,15,8,6,6,6,6,8,15,6,6,6,0
    db 0,6,6,6,15,8,6,6,6,6,8,15,6,6,6,0
    db 6,6,6,6,15,15,6,6,6,6,15,15,6,6,6,6
    db 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    db 0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0
    db 0,0,0,0,43,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,43,43,43,43,43,43,43,43,43,43,0,0,0
    db 0,0,0,43,43,43,43,43,43,43,43,43,43,0,0,0
    db 0,0,8,8,8,8,0,0,0,0,8,8,8,8,0,0
    db 0,8,8,8,8,8,0,0,0,0,8,8,8,8,8,0
    db 0,8,8,8,8,0,0,0,0,0,0,8,8,8,8,0

; --- GOOMBA: SQUASHED FLAT (16x16) ---
spr_goomba_flat:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,6,6,6,6,6,6,6,6,6,6,6,6,0,0
    db 6,6,6,8,8,6,6,6,6,6,6,8,8,6,6,6
    db 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    db 0,0,43,43,43,43,43,43,43,43,43,43,0,0,0,0
    db 0,8,8,8,8,0,0,0,0,0,0,8,8,8,8,0
    db 0,8,8,8,8,0,0,0,0,0,0,8,8,8,8,0

; --- KOOPA TROOPA: WALKING (16x16, faces right by default) ---
spr_koopa_walk:
    db 0,0,0,0,0,0,0,0,14,14,14,0,0,0,0,0
    db 0,0,0,0,0,0,0,14,14,15,8,14,0,0,0,0
    db 0,0,0,0,0,0,0,14,14,15,8,14,14,0,0,0
    db 0,0,0,0,2,2,2,0,14,14,14,14,14,0,0,0
    db 0,0,0,2,10,2,10,2,0,14,14,0,0,0,0,0
    db 0,0,2,10,2,10,2,10,2,14,0,0,0,0,0,0
    db 0,2,10,2,10,2,10,2,10,2,0,0,0,0,0,0
    db 0,2,2,10,2,10,2,10,2,2,0,0,0,0,0,0
    db 0,15,2,2,2,2,2,2,2,15,0,0,0,0,0,0
    db 0,15,15,15,15,15,15,15,15,15,0,0,0,0,0,0
    db 0,0,14,14,14,0,0,14,14,14,0,0,0,0,0,0
    db 0,0,14,14,0,0,0,0,14,14,0,0,0,0,0,0
    db 0,6,6,6,0,0,0,0,6,6,6,0,0,0,0,0
    db 6,6,6,6,0,0,0,0,6,6,6,6,0,0,0,0
    db 6,6,6,6,0,0,0,0,6,6,6,6,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; --- KOOPA SHELL (16x16) ---
spr_koopa_shell:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0
    db 0,0,0,2,2,10,2,10,2,10,2,2,2,0,0,0
    db 0,0,2,10,2,10,2,10,2,10,2,10,2,2,0,0
    db 0,2,10,2,10,2,10,2,10,2,10,2,10,2,2,0
    db 0,2,2,10,2,10,2,10,2,10,2,10,2,2,2,0
    db 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
    db 15,15,2,2,2,2,2,2,2,2,2,2,2,2,15,15
    db 0,15,15,15,15,15,15,15,15,15,15,15,15,15,15,0
    db 0,0,15,15,15,15,15,15,15,15,15,15,15,15,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; --- SUPER MUSHROOM POWER-UP (16x16) ---
spr_mushroom:
    db 0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0
    db 0,0,0,0,4,4,15,15,15,15,4,4,0,0,0,0
    db 0,0,0,4,4,15,15,15,15,15,15,4,4,0,0,0
    db 0,0,4,15,4,15,15,15,15,15,15,4,15,4,0,0
    db 0,4,15,15,4,4,15,15,15,15,4,4,15,15,4,0
    db 0,4,15,15,4,4,4,4,4,4,4,4,15,15,4,0
    db 4,4,15,4,4,4,4,4,4,4,4,4,4,15,4,4
    db 4,4,4,4,4,4,15,15,15,15,4,4,4,4,4,4
    db 4,4,4,4,4,15,15,15,15,15,15,4,4,4,4,4
    db 0,4,4,4,4,4,15,15,15,15,4,4,4,4,4,0
    db 0,0,0,0,43,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,43,43,8,43,43,43,43,8,43,43,0,0,0
    db 0,0,0,43,43,8,43,43,43,43,8,43,43,0,0,0
    db 0,0,0,43,43,43,43,43,43,43,43,43,43,0,0,0
    db 0,0,0,0,43,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; Name     : DrawMario
; Purpose  : draws Mario at his current position (mario_x, mario_y)
;            using form (0=Small, 1=Super), pose (0=stand, 1=run, 2=jump),
;            facing (0=right, 1=left), and invuln_timer blinking
; Inputs   : global variables mario_x, mario_y, form, pose, facing, invuln_timer, camera_x
; Outputs  : draws Small (16x16) or Super (16x32) Mario into [fb_seg]
; Changes  : none (all registers saved and restored)
; ------------------------------------------------------------
DrawMario:
    push ax
    push bx
    push dx
    push si

    ; If invuln_timer > 0, blink every 4 frames
    mov ax, [invuln_timer]
    cmp ax, 0
    je .calc_screen_pos
    test ax, 0004h
    jnz .dm_done

.calc_screen_pos:
    mov bx, [mario_x]
    sub bx, [camera_x]          ; screen X

    mov dx, [mario_y]
    shr dx, 8                   ; whole world feet Y

    mov al, [facing]            ; 0 = right, 1 = left

    cmp byte [form], 0
    jne .draw_super

    ; --- SMALL MARIO (16x16) ---
    sub dx, SMALL_H             ; top Y = feet Y - 16
    mov si, spr_mario_small_stand
    cmp byte [pose], 1
    jne .chk_small_jump
    mov si, spr_mario_small_run
    jmp .render_small
.chk_small_jump:
    cmp byte [pose], 2
    jne .render_small
    mov si, spr_mario_small_jump
.render_small:
    call DrawSprite16
    jmp .dm_done

.draw_super:
    ; --- SUPER MARIO (16x32 = upper 16x16 + lower 16x16) ---
    sub dx, SUPER_H             ; top Y = feet Y - 32
    mov si, spr_super_top
    call DrawSprite16

    add dx, TILE_SIZE           ; lower 16x16 legs
    mov si, spr_super_bot_stand
    cmp byte [pose], 0
    je .render_super_bot
    mov si, spr_super_bot_run
.render_super_bot:
    call DrawSprite16

.dm_done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : DrawEnemies
; Purpose  : loops through all 8 enemy slots and draws active ones
; Inputs   : global enemies table (MAX_ENEMIES x EN_SIZE) and camera_x
; Outputs  : draws Goombas, Koopas, and Shells into [fb_seg]
; Changes  : none (all registers saved and restored)
; ------------------------------------------------------------
DrawEnemies:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov di, enemies             ; DI points to enemy record 0
    mov cx, MAX_ENEMIES         ; 8 slots

.enemy_loop:
    mov al, [di + EN_TYPE]
    cmp al, ENEMY_NONE          ; empty slot?
    je near .next_enemy

    ; Calculate screen X = EN_X - camera_x (whole pixels)
    mov bx, [di + EN_X]
    sub bx, [camera_x]

    ; Calculate screen top Y = EN_Y - 16 (whole pixels)
    mov dx, [di + EN_Y]
    sub dx, TILE_SIZE

    cmp al, ENEMY_GOOMBA
    je .draw_goomba
    cmp al, ENEMY_KOOPA
    je .draw_koopa
    cmp al, ENEMY_SHELL
    je .draw_shell
    jmp .next_enemy

.draw_goomba:
    mov si, spr_goomba_walk
    cmp byte [di + EN_STATE], ENS_FLAT
    jne .render_goomba
    mov si, spr_goomba_flat
.render_goomba:
    xor al, al                  ; Goomba doesn't need horizontal flip
    call DrawSprite16
    jmp .next_enemy

.draw_koopa:
    mov si, spr_koopa_walk
    mov al, [di + EN_DIR]       ; 0 = facing right, 1 = facing left (mirrored)
    call DrawSprite16
    jmp .next_enemy

.draw_shell:
    mov si, spr_koopa_shell
    xor al, al
    call DrawSprite16

.next_enemy:
    add di, EN_SIZE             ; advance 12 bytes to next enemy record
    loop .enemy_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret