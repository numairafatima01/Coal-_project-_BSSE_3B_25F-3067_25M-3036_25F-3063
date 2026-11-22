; ============================================================
; FILE: src/level.asm
; Module 5: Level Map Data & Fast Tile Renderer
; ============================================================

map_original:
    ; Row 0: HUD strip (y = 0..15)
    times 60 db TILE_SKY
    ; Row 1: Sky (y = 16..31)
    times 60 db TILE_SKY
    ; Row 2: Flagpole top (y = 32..47)
    times 55 db 0
    db 12,0,0,0,0
    ; Row 3: Floating coins & blocks (y = 48..63)
    db 0,0,0,0,0,0,0,0,0,0,0,0,11,11,11,0,0,0,0,0
    db 0,0,0,0,0,0,2,2,3,2,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,12,0,0,0,0
    ; Row 4: Flagpole shaft (y = 64..79)
    times 55 db 0
    db 12,0,0,0,0
    ; Row 5: Stair top & flagpole (y = 80..95)
    times 52 db 0
    db 10,0,0,12,0,0,0,0
    ; Row 6: '?' blocks, bricks, coins, stairs, flagpole (y = 96..111)
    db 0,0,0,0,0,0,3,0,0,2,4,2,3,2,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,11,11,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,10,10,0,0,12,0,0,0,0
    ; Row 7: Tall pipe top, stairs, flagpole (y = 112..127)
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,6,7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,10,10,10,0,0,12,0,0,0,0
    ; Row 8: Short pipe top, pipes, stairs, flagpole (y = 128..143)
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,7,0,0
    db 0,0,8,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,7
    db 0,0,0,0,0,0,0,0,0,10,10,10,10,0,0,12,0,0,0,0
    ; Row 9: Pipe bases, stairs, flagpole base (y = 144..159)
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,9,0,0
    db 0,0,8,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,9
    db 0,0,0,0,0,0,0,0,10,10,10,10,10,0,0,10,0,0,0,0
    ; Row 10: Ground top layer with 2 pits (y = 160..175)
    times 26 db TILE_GROUND
    db TILE_SKY, TILE_SKY
    times 16 db TILE_GROUND
    db TILE_SKY, TILE_SKY
    times 14 db TILE_GROUND
    ; Row 11: Ground bottom layer (y = 176..191)
    times 26 db TILE_GROUND
    db TILE_SKY, TILE_SKY
    times 16 db TILE_GROUND
    db TILE_SKY, TILE_SKY
    times 14 db TILE_GROUND

map_working:
    times MAP_COLS * MAP_ROWS db 0

; ------------------------------------------------------------
; ResetMap: copies clean map_original into map_working
; ------------------------------------------------------------
ResetMap:
    push ax
    push cx
    push si
    push di
    push es

    push ds
    pop es
    mov si, map_original
    mov di, map_working
    mov cx, MAP_COLS * MAP_ROWS
    cld
    rep movsb

    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; ------------------------------------------------------------
; IsSolidTile: CF = 1 if AL is solid (1..10), CF = 0 if passable
; ------------------------------------------------------------
IsSolidTile:
    cmp al, TILE_GROUND
    jb .passable
    cmp al, TILE_STAIR
    ja .passable
    stc
    ret
.passable:
    clc
    ret

; ------------------------------------------------------------
; DrawBox: draws a solid rectangle (BX=x, DX=y, CX=w, SI=h, AL=color)
; ------------------------------------------------------------
DrawBox:
    push ax
    xor ah, ah
    push bx
    push dx
    push cx
    push si
    push ax
    call FillRect
    pop ax
    ret

; ------------------------------------------------------------
; DrawOutlinedBox: draws a 16x16 block with a 1px black border
;                  and inner fill colour in AL
; ------------------------------------------------------------
DrawOutlinedBox:
    push ax
    push bx
    push cx
    push dx
    push si

    ; 16x16 black outline
    push ax
    mov cx, 16
    mov si, 16
    mov al, 0
    call DrawBox
    pop ax

    ; 14x14 inner color fill
    inc bx
    inc dx
    mov cx, 14
    mov si, 14
    call DrawBox

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tile_draw_table:
    dw DrawTile.t_sky           ; 0 = sky
    dw DrawTile.t_ground        ; 1 = ground
    dw DrawTile.t_brick         ; 2 = brick
    dw DrawTile.t_qblock        ; 3 = ? coin
    dw DrawTile.t_qblock        ; 4 = ? mushroom
    dw DrawTile.t_empty         ; 5 = used ? block
    dw DrawTile.t_pipe_top      ; 6 = pipe top-left
    dw DrawTile.t_pipe_top      ; 7 = pipe top-right
    dw DrawTile.t_pipe_body     ; 8 = pipe body-left
    dw DrawTile.t_pipe_body     ; 9 = pipe body-right
    dw DrawTile.t_stair         ; 10 = stair block
    dw DrawTile.t_coin          ; 11 = coin
    dw DrawTile.t_flag          ; 12 = flagpole

; ------------------------------------------------------------
; DrawTile: draws a clean, outlined 16x16 tile at (BX, DX)
; ------------------------------------------------------------
DrawTile:
    push ax
    push bx
    push cx
    push dx
    push si

    cmp bx, -16
    jle near .dt_done
    cmp bx, SCREEN_W
    jge near .dt_done

    xor ah, ah
    cmp ax, TILE_FLAG
    ja near .t_sky

    mov si, ax
    shl si, 1
    jmp [tile_draw_table + si]

.t_sky:
    mov cx, 16
    mov si, 16
    mov al, COL_SKY
    call DrawBox
    jmp .dt_done

.t_ground:
    mov cx, 16
    mov si, 16
    mov al, COL_GROUND
    call DrawBox
    mov cx, 16
    mov si, 4
    mov al, COL_PIPE
    call DrawBox
    mov cx, 16
    mov si, 1
    mov al, 0
    call DrawBox
    jmp .dt_done

.t_brick:
    mov al, COL_BRICK
    call DrawOutlinedBox
    jmp .dt_done

.t_qblock:
    mov al, 14
    call DrawOutlinedBox
    add bx, 6
    add dx, 4
    mov cx, 4
    mov si, 2
    mov al, COL_GROUND
    call DrawBox
    add bx, 2
    add dx, 2
    mov cx, 2
    mov si, 3
    call DrawBox
    add dx, 4
    mov cx, 2
    mov si, 2
    call DrawBox
    jmp .dt_done

.t_empty:
    mov al, COL_GROUND
    call DrawOutlinedBox
    jmp .dt_done

.t_pipe_top:
    mov al, COL_PIPE
    call DrawOutlinedBox
    jmp .dt_done

.t_pipe_body:
    mov cx, 16
    mov si, 16
    mov al, COL_SKY
    call DrawBox
    add bx, 1
    mov cx, 14
    mov si, 16
    mov al, 0
    call DrawBox
    add bx, 1
    mov cx, 12
    mov si, 16
    mov al, COL_PIPE
    call DrawBox
    jmp .dt_done

.t_stair:
    mov al, 7
    call DrawOutlinedBox
    jmp .dt_done

.t_coin:
    mov cx, 16
    mov si, 16
    mov al, COL_SKY
    call DrawBox
    add bx, 5
    add dx, 3
    mov cx, 6
    mov si, 10
    mov al, 0
    call DrawBox
    add bx, 1
    add dx, 1
    mov cx, 4
    mov si, 8
    mov al, 14
    call DrawBox
    jmp .dt_done

.t_flag:
    mov cx, 16
    mov si, 16
    mov al, COL_SKY
    call DrawBox
    add bx, 7
    mov cx, 2
    mov si, 16
    mov al, COL_TEXT
    call DrawBox

.dt_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; RenderLevel: draws visible map rows 1..11 into [fb_seg]
; ------------------------------------------------------------
RenderLevel:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Bottom 8px black border
    xor bx, bx
    mov dx, VISIBLE_H
    mov cx, SCREEN_W
    mov si, 8
    mov al, 0
    call DrawBox

    mov ax, [camera_x]
    mov cx, ax
    shr cx, 4
    and ax, 0Fh
    neg ax
    mov [rl_start_x], ax
    mov [rl_start_col], cx

    mov di, 1
.row_loop:
    cmp di, MAP_ROWS
    jge .rl_done

    mov si, di
    shl si, 6
    mov ax, di
    shl ax, 2
    sub si, ax
    add si, [rl_start_col]

    mov dx, di
    shl dx, 4

    mov bx, [rl_start_x]
    mov cx, VISIBLE_COLS + 1

.col_loop:
    mov al, [map_working + si]
    call DrawTile

    inc si
    add bx, TILE_SIZE
    loop .col_loop

    inc di
    jmp .row_loop

.rl_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

rl_start_x      dw 0
rl_start_col    dw 0