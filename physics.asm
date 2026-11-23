; ============================================================
; FILE: src/physics.asm
; Module 9: Mario Physics, Gravity & Tile Collisions
; ============================================================

; ------------------------------------------------------------
; Name     : InitMario
; Purpose  : places Mario at the start of the level with zero
;            speed, Small Mario size, and camera at x = 0
; Inputs   : none
; Outputs  : sets mario_x, mario_y, velocities, form, hp,
;            pose, camera_x, need_redraw, and STATE_PLAYING
; Changes  : none
; ------------------------------------------------------------
InitMario:
    mov word [mario_x], START_X       ; starting X = 32 whole pixels
    mov byte [mario_x_sub], 0         ; clear fractional subpixel counter
    mov word [mario_y], START_Y * 256 ; feet start at Y = 160 (in 8.8 fixed point)
    mov word [mario_vx], 0            ; not moving sideways yet
    mov word [mario_vy], 0            ; not moving up or down yet
    mov byte [facing], 0              ; 0 = facing right
    mov byte [on_ground], 1           ; 1 = standing on solid ground
    mov byte [form], 0                ; 0 = Small Mario (16 pixels tall)
    mov byte [hp], 1                  ; 1 hit point when small
    mov word [invuln_timer], 0        ; no blinking safety frames active
    mov byte [stomp_chain], 0         ; reset consecutive stomp combo
    mov byte [pose], 0                ; 0 = standing pose
    mov word [camera_x], 0            ; camera starts at far-left edge (0)
    mov byte [need_redraw], 1         ; force full background draw on next frame
    mov byte [game_state], STATE_PLAYING ; begin active gameplay
    ret

; ------------------------------------------------------------
; Name     : UpdateMarioPhysics
; Purpose  : runs once per frame to move Mario sideways with
;            acceleration and friction, handle jumping and
;            gravity, stop Mario at walls/floors/ceilings,
;            bump ?-blocks/bricks, and scroll the camera
; Inputs   : mario_x, mario_y, mario_vx, mario_vy, on_ground,
;            facing, form, pose, key_state, camera_x, map_working
; Outputs  : updates Mario's coordinates, speeds, pose, camera_x,
;            need_redraw, and modified blocks in map_working
; Changes  : none (all registers saved and restored)
; ------------------------------------------------------------
UpdateMarioPhysics:
    push ax                         ; save registers we will use
    push bx
    push cx
    push dx
    push si

    ; Only move Mario while the game is actively playing
    cmp byte [game_state], STATE_PLAYING
    jne near .ump_done

    ; =========================================================================
    ; 1. SIDEWAYS MOVEMENT: ACCELERATION, SPRINT (LSHIFT) & FRICTION
    ; =========================================================================
    ; Check if Left Shift is held to pick Mario's top sideways speed
    mov cx, MAX_WALK                ; default top speed = 1.5 pixels/frame
    mov al, SC_LSHIFT
    call IsKeyDown                  ; ZF = 0 (JNZ) if held, ZF = 1 (JZ) if not
    jz .check_horiz_keys            ; not held -> keep normal walking speed
    mov cx, MAX_RUN                 ; held -> boost top speed to 2.5 pixels/frame

.check_horiz_keys:
    ; Check if Left Arrow key is held down
    mov al, SC_LEFT
    call IsKeyDown
    jz .check_right_key             ; Left not pressed -> check Right Arrow instead

    ; Left Arrow is held: turn left and speed up toward -max_speed
    mov byte [facing], 1            ; 1 = face left
    mov ax, [mario_vx]              ; get current sideways speed
    sub ax, WALK_ACCEL              ; push speed further left (more negative)
    neg cx                          ; flip max speed negative (-MAX_WALK or -MAX_RUN)
    cmp ax, cx                      ; did we exceed the left speed limit?
    jge .store_vx_move              ; no -> keep new speed
    mov ax, cx                      ; yes -> cap at -max_speed
    jmp .store_vx_move

.check_right_key:
    ; Check if Right Arrow key is held down
    mov al, SC_RIGHT
    call IsKeyDown
    jz .apply_friction              ; neither Left nor Right held -> slow down with friction

    ; Right Arrow is held: turn right and speed up toward +max_speed
    mov byte [facing], 0            ; 0 = face right
    mov ax, [mario_vx]              ; get current sideways speed
    add ax, WALK_ACCEL              ; push speed further right (more positive)
    cmp ax, cx                      ; did we exceed the right speed limit?
    jle .store_vx_move              ; no -> keep new speed
    mov ax, cx                      ; yes -> cap at +max_speed
    jmp .store_vx_move

.apply_friction:
    ; Neither arrow key is held, so gradually bring sideways speed back to 0
    mov ax, [mario_vx]
    cmp ax, 0
    je .store_vx_move               ; already stopped -> nothing to slow down
    jg .fric_pos                    ; moving right -> subtract friction

    ; Moving left (negative speed): add friction until we reach 0
    add ax, FRICTION
    cmp ax, 0
    jle .store_vx_move              ; still moving left -> keep slowed speed
    xor ax, ax                      ; crossed 0 -> come to a full stop
    jmp .store_vx_move

.fric_pos:
    ; Moving right (positive speed): subtract friction until we reach 0
    sub ax, FRICTION
    cmp ax, 0
    jge .store_vx_move              ; still moving right -> keep slowed speed
    xor ax, ax                      ; crossed 0 -> come to a full stop

.store_vx_move:
    mov [mario_vx], ax              ; save updated sideways speed
    cmp ax, 0
    je near .update_idle_pose       ; if speed is 0, skip movement and show standing pose

    ; Add signed 8.8 velocity AX to 24-bit position (mario_x : mario_x_sub)
    cwd
    add [mario_x_sub], al           ; add fractional byte
    adc [mario_x], ah               ; add signed whole-pixel byte + carry/borrow
    adc byte [mario_x + 1], dl      ; apply sign extension for negative speeds

    ; Stop Mario from walking backward past the left edge of the camera view
    mov ax, [mario_x]
    cmp ax, [camera_x]
    jge .check_right_edge           ; still inside screen -> check right boundary
    mov ax, [camera_x]              ; clamp Mario to left edge of camera
    mov [mario_x], ax
    mov word [mario_vx], 0          ; stop sideways momentum at edge
    jmp .check_x_collisions

.check_right_edge:
    ; Stop Mario from walking past the right end of the 960-pixel level
    mov ax, [mario_x]
    cmp ax, LEVEL_W_PX - TILE_SIZE  ; rightmost allowed X = 944
    jle .check_x_collisions         ; inside level -> check wall collisions
    mov word [mario_x], LEVEL_W_PX - TILE_SIZE ; clamp at end of level
    mov word [mario_vx], 0          ; stop sideways speed

    ; =========================================================================
    ; 2. SIDEWAYS WALL COLLISION (STOP MARIO FROM WALKING INTO BLOCKS/PIPES)
    ; =========================================================================
.check_x_collisions:
    ; Pick the front edge of Mario's 12px hitbox based on which way he's moving
    mov bx, [mario_x]               ; whole-pixel X
    add bx, 2                       ; left edge of hitbox (2px inside 16px sprite)
    cmp word [mario_vx], 0
    jl .x_edge_ready                ; moving left -> test left hitbox edge
    add bx, HIT_W - 1               ; moving right -> test right hitbox edge (X + 13)

.x_edge_ready:
    ; Find Y coordinates of Mario's feet and head so we can test both against walls
    mov dx, [mario_y]
    shr dx, 8                       ; feet Y in whole pixels
    dec dx                          ; lift 1px up so flat floor tiles don't trigger wall hit

    mov si, dx                      ; SI will hold Mario's head Y
    sub si, SMALL_H - 2             ; head Y for Small Mario (14px above feet)
    cmp byte [form], 0
    je .test_wall_tiles             ; Small Mario -> head Y is ready
    sub si, TILE_SIZE               ; Super Mario is 16px taller -> raise head Y

.test_wall_tiles:
    ; Test 1: Check foot level against solid walls
    call CheckPixelSolid
    jc .hit_wall_x                  ; CF = 1 -> hit a wall at foot level

    ; Test 2: Check head level against solid walls
    push dx
    mov dx, si                      ; temporarily put head Y into DX
    call CheckPixelSolid
    pop dx                          ; restore feet Y into DX
    jc .hit_wall_x                  ; CF = 1 -> hit a wall at head level

    ; Test 3: If Super Mario (32px tall), also check middle/waist height
    cmp byte [form], 0
    je .set_run_pose                ; Small Mario only needs 2 checks
    push dx
    sub dx, TILE_SIZE               ; waist Y = 16px above feet
    call CheckPixelSolid
    pop dx
    jnc .set_run_pose               ; no wall hit -> update running animation

.hit_wall_x:
    ; Mario bumped into a wall sideways: snap him flush against the tile's edge
    cmp word [mario_vx], 0
    jg .snap_left_wall              ; moving right -> snap to left face of tile

    ; Moving left: snap Mario to the right edge of the solid tile
    and bx, 0FFF0h                  ; round X down to tile's left edge (multiple of 16)
    add bx, TILE_SIZE - 2           ; tile's right edge minus 2px hitbox margin
    mov [mario_x], bx
    mov word [mario_vx], 0          ; stop sideways speed
    jmp .set_run_pose

.snap_left_wall:
    ; Moving right: snap Mario to the left edge of the solid tile
    and bx, 0FFF0h                  ; round X down to tile's left edge
    sub bx, 2 + HIT_W               ; place Mario's right hitbox edge flush with tile
    mov [mario_x], bx
    mov word [mario_vx], 0          ; stop sideways speed

.set_run_pose:
    ; Alternate between standing (0) and running (1) poses every 4 ticks on ground
    cmp byte [on_ground], 1
    jne .vertical_physics           ; in midair -> keep jump pose
    mov ax, [tick_count]
    test ax, 0004h                  ; toggle pose every 4 timer ticks
    jz .run_frame_1
    mov byte [pose], 0              ; stride frame A
    jmp .vertical_physics
.run_frame_1:
    mov byte [pose], 1              ; stride frame B
    jmp .vertical_physics

.update_idle_pose:
    ; Mario has 0 sideways speed: show standing pose if he is on the ground
    cmp byte [on_ground], 1
    jne .vertical_physics
    mov byte [pose], 0              ; standing pose

    ; =========================================================================
    ; 3. JUMPING, VARIABLE JUMP HEIGHT & GRAVITY
    ; =========================================================================
.vertical_physics:
    ; Check if Spacebar (Jump) is held down
    mov al, SC_SPACE
    call IsKeyDown
    jz .space_not_held              ; Space not held -> check early jump release

    ; Space is held: launch a jump only if Mario is standing on solid ground
    cmp byte [on_ground], 1
    jne .apply_gravity              ; already in air -> prevent double-jumping
    mov word [mario_vy], JUMP_START ; give strong upward velocity (-5.5 px/frame)
    mov byte [on_ground], 0         ; mark Mario as airborne
    mov byte [pose], 2              ; switch to jumping pose
    push si
    mov si, sfx_jump
    call PlaySound
    pop si
    jmp .apply_gravity

.space_not_held:
    ; Variable jump height: if Space is released early while rising fast,
    ; cut upward speed to JUMP_CUTOFF (-2.0) so tapping Space gives a short hop
    cmp byte [on_ground], 0
    jne .apply_gravity              ; on ground -> nothing to cut
    mov ax, [mario_vy]
    cmp ax, JUMP_CUTOFF             ; rising faster than -2.0 px/frame?
    jge .apply_gravity              ; no -> let gravity slow him naturally
    mov word [mario_vy], JUMP_CUTOFF ; yes -> cap upward speed

.apply_gravity:
    ; Pull Mario downward each frame by adding GRAVITY to vertical speed
    mov ax, [mario_vy]
    add ax, GRAVITY                 ; accelerate downward
    cmp ax, MAX_FALL                ; reached terminal fall speed (4.0 px/frame)?
    jle .store_vy
    mov ax, MAX_FALL                ; cap fall speed so Mario never skips through tiles
.store_vy:
    mov [mario_vy], ax
    add [mario_y], ax               ; move Mario vertically (8.8 fixed point)

    ; Check if Mario fell down a pit below the bottom of the screen (Y >= 192)
    mov dx, [mario_y]
    shr dx, 8                       ; convert feet Y to whole pixels
    cmp dx, PIT_Y
    jl .check_y_collisions          ; still above pit -> check floor/ceiling collisions
    call KillMario                  ; fell into a pit -> lose a life
    jmp .ump_done

    ; =========================================================================
    ; 4. VERTICAL COLLISIONS (FLOOR LANDING & CEILING BLOCK HITS)
    ; =========================================================================
.check_y_collisions:
    mov ax, [mario_vy]
    cmp ax, 0
    jl .check_ceiling               ; negative speed = moving upward -> check head hit

    ; --- MOVING DOWNWARD (OR STANDING): CHECK SOLID FLOOR UNDER BOTH FEET ---
    mov dx, [mario_y]
    shr dx, 8                       ; feet Y in whole pixels

    ; Check tile under Mario's left foot
    mov bx, [mario_x]
    add bx, 2                       ; left edge of hitbox
    call CheckPixelSolid
    jc .land_on_floor               ; solid tile under left foot -> land

    ; Check tile under Mario's right foot
    add bx, HIT_W - 1               ; right edge of hitbox
    call CheckPixelSolid
    jc .land_on_floor               ; solid tile under right foot -> land

    ; Empty air under both feet -> Mario is falling
    mov byte [on_ground], 0
    mov byte [pose], 2              ; airborne jump/fall pose
    jmp .update_camera

.land_on_floor:
    ; Snap Mario's feet cleanly onto the top surface of the floor tile
    and dx, 0FFF0h                  ; round Y down to top of tile (multiple of 16)
    shl dx, 8                       ; convert back to 8.8 fixed point
    mov [mario_y], dx
    mov word [mario_vy], 0          ; stop falling
    mov byte [on_ground], 1         ; mark Mario as grounded
    mov byte [stomp_chain], 0       ; reset consecutive stomp combo on landing
    jmp .update_camera

.check_ceiling:
    ; --- MOVING UPWARD: CHECK IF MARIO'S HEAD HIT A BLOCK OR HUD BAR ---
    mov dx, [mario_y]
    shr dx, 8                       ; feet Y in pixels
    sub dx, SMALL_H                 ; subtract 16px to get Small Mario's head Y
    cmp byte [form], 0
    je .head_y_ok
    sub dx, TILE_SIZE               ; Super Mario is 32px tall -> head is 16px higher
.head_y_ok:
    cmp dx, HUD_HEIGHT              ; keep Mario below the top 16px blue HUD strip
    jge .test_ceiling_tile
    mov dx, HUD_HEIGHT + SMALL_H
    cmp byte [form], 0
    je .hud_clamp_done
    add dx, TILE_SIZE
.hud_clamp_done:
    shl dx, 8
    mov [mario_y], dx
    mov word [mario_vy], 0
    jmp .update_camera

.test_ceiling_tile:
    ; Test the horizontal center point above Mario's head
    mov bx, [mario_x]
    add bx, 8                       ; horizontal midpoint of Mario's 16px sprite
    call CheckPixelSolid
    jnc .update_camera              ; nothing solid above head -> keep rising

    ; Head hit a solid tile! Trigger block reaction (? block / brick) and rebound
    call HandleBlockBump
    and dx, 0FFF0h                  ; top of the bumped tile
    add dx, TILE_SIZE + SMALL_H     ; place Small Mario's feet directly below tile
    cmp byte [form], 0
    je .snap_head
    add dx, TILE_SIZE               ; adjust feet 16px lower if Super Mario
.snap_head:
    shl dx, 8                       ; convert back to 8.8 fixed point
    mov [mario_y], dx
    mov word [mario_vy], 0080h      ; slight downward bounce (0.5 px/frame)

    ; =========================================================================
    ; 5. ONE-WAY CAMERA SCROLLING (FOLLOW MARIO TO THE RIGHT)
    ; =========================================================================
.update_camera:
    ; Scroll camera once Mario passes the horizontal follow threshold (X = 160)
    mov ax, [mario_x]               ; whole-pixel X
    cmp ax, CAMERA_FOLLOW_X
    jbe .ump_done                   ; still in left half of screen -> keep camera at 0
    sub ax, CAMERA_FOLLOW_X         ; desired camera_x = mario_x - 160
    cmp ax, [camera_x]
    jle .ump_done                   ; camera never scrolls backward in classic Mario
    cmp ax, CAMERA_MAX
    jle .set_cam                    ; within level bounds -> update camera_x
    mov ax, CAMERA_MAX              ; clamp camera at end of level (640)
.set_cam:
    mov [camera_x], ax              ; ScrollScreenLeft in camera.asm handles fast shift!

.ump_done:
    pop si                          ; restore all saved registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : EraseMarioTrail
; Purpose  : fast background restore that redraws only the 2x3
;            map tiles overlapping Mario's previous frame so we
;            don't have to redraw all 231 tiles every frame
; Inputs   : prev_mario_x, prev_mario_y, prev_camera_x, map_working
; Outputs  : redraws the 6 tiles around Mario's old position
; Changes  : none (all registers including BP are preserved)
; ------------------------------------------------------------
EraseMarioTrail:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    ; Find starting map column and row covering Mario's previous sprite box
    mov cx, [prev_mario_x]
    shr cx, 4                       ; left tile col = prev_mario_x / 16
    mov di, [prev_mario_y]
    sub di, SUPER_H                 ; top of 32px Super Mario box
    shr di, 4                       ; top tile row = top_y / 16
    cmp di, 1
    jge .emt_row_ok
    mov di, 1                       ; never overwrite HUD row 0

.emt_row_ok:
    mov bp, 3                       ; redraw 3 rows vertically (covers 32px Super Mario)
.emt_row_loop:
    cmp di, MAP_ROWS
    jge .emt_done

    ; Compute screen Y = row * 16
    mov dx, di
    shl dx, 4

    ; Redraw 2 columns horizontally (covers 16px wide Mario across tile edges)
    push cx
    mov ah, 2                       ; 2 columns wide
.emt_col_loop:
    cmp cx, MAP_COLS
    jge .emt_next_row

    ; Compute screen X = (col * 16) - prev_camera_x
    mov bx, cx
    shl bx, 4
    sub bx, [prev_camera_x]

    ; Look up tile ID at (col, row) in map_working: index = row * 60 + col
    push ax
    mov ax, di
    mov si, ax
    shl si, 6                       ; row * 64
    shl ax, 2                       ; row * 4
    sub si, ax                      ; row * 60
    add si, cx                      ; row * 60 + col
    mov al, [map_working + si]
    call DrawTile
    pop ax

    inc cx
    dec ah
    jnz .emt_col_loop

.emt_next_row:
    pop cx
    inc di
    dec bp
    jnz .emt_row_loop

.emt_done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : CheckPixelSolid
; Purpose  : converts world pixel (BX, DX) to a map tile and
;            checks if that tile blocks Mario (also collects
;            floating coins automatically on touch)
; Inputs   : BX = world X (pixels), DX = world Y (pixels)
; Outputs  : CF = 1 if tile is solid, CF = 0 if passable
; Changes  : none
; ------------------------------------------------------------
CheckPixelSolid:
    push ax
    push bx
    push dx

    cmp dx, 0
    jl .not_solid
    cmp dx, VISIBLE_H
    jge .not_solid

    shr bx, 4                       ; tile column = world_x / 16
    shr dx, 4                       ; tile row    = world_y / 16
    cmp bx, MAP_COLS
    jge .not_solid
    cmp dx, MAP_ROWS
    jge .not_solid

    ; Compute flat map index: index = row * 60 + col
    mov ax, dx
    mov dl, MAP_COLS
    mul dl                          ; AX = row * MAP_COLS
    add ax, bx                      ; AX = row * MAP_COLS + col
    mov bx, ax
    mov al, [map_working + bx]      ; read tile code from working map

    ; Collect floating coins immediately if Mario touches a coin tile
    cmp al, TILE_COIN
    jne .test_solid
    mov byte [map_working + bx], TILE_SKY ; erase coin from map
    mov byte [need_redraw], 1       ; trigger redraw so coin disappears
    call AddCoinAndScore            ; +1 coin and +200 points
    clc                             ; coins do not block movement (CF = 0)
    jmp .cps_done

.test_solid:
    call IsSolidTile                ; Module 3 helper: sets CF = 1 if solid
    jmp .cps_done

.not_solid:
    clc                             ; CF = 0 (passable)
.cps_done:
    pop dx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : KillMario
; Purpose  : deducts 1 life when Mario falls in a pit; respawns
;            Mario if lives remain, otherwise triggers Game Over
; Inputs   : lives
; Outputs  : updates lives and either calls InitMario or sets
;            game_state = STATE_GAMEOVER
; Changes  : none
; ------------------------------------------------------------
KillMario:
    push si
    mov si, sfx_hurt
    call PlaySound
    pop si
    dec byte [lives]                ; subtract 1 life
    jz .game_over                   ; 0 lives left -> trigger Game Over
    call InitMario                  ; lives remaining -> reset at level start
    ret
.game_over:
    mov byte [game_state], STATE_GAMEOVER ; switch to Game Over state
    ret