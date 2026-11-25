INCLUDE Irvine32.inc

; ------------------------------- constants ----------------------------------
SCR_W        = 80                 ; screen width  (columns)
SCR_H        = 24                 ; screen height (rows)
STRIDE       = SCR_W + 1          ; row length in buffer (80 chars + 0 byte)

MAXFILL      = 3                  ; a container holds at most 3 elements
TRUCK_CAP    = 4                  ; loads a truck takes before it is "full"

STEPS        = 4                  ; walking cells in each side tunnel
L_MAXX       = 32                 ; left tunnel: cells 29..32 (32 is next to the lift)
L_MINX       = L_MAXX - STEPS + 1 ;   cell 29 is next to the container
R_MINX       = 47                 ; right tunnel: cells 47..50 (47 is next to the lift)
R_MAXX       = R_MINX + STEPS - 1 ;   cell 50 is next to the container
LC_X         = L_MINX - 7         ; first interior column of the LEFT containers
RC_X         = R_MAXX + 3         ; first interior column of the RIGHT containers
TUN_LEN      = STEPS + 9          ; drawn length of each side tunnel
START_X      = L_MINX             ; respawn: left tunnel, height 2, at the container
START_H      = 2

LIFT_FRAMES  = 24                 ; frames between moves of ONE lift
LIFT_OFFSET  = LIFT_FRAMES / 2    ; the right lift starts this many frames later
FRAME_MS     = 40
BASE_DELAY   = 75                 ; frames between mixer drips at score 0
MIN_DELAY    = 30                 ; fastest drip rate

IN_LEFT      = 00000001b          ; input flag bits
IN_RIGHT     = 00000010b
IN_ACT       = 00000100b
IN_QUIT      = 00001000b
VKEY_LEFT    = 25h
VKEY_RIGHT   = 27h

BOX_CLR      = white + (red*16)   ; game-over box colour

; ------------------------------- prototypes ---------------------------------
CellIndex     PROTO, col:DWORD, row:DWORD
PutChar       PROTO, px:DWORD, py:DWORD, glyph:DWORD, clr:DWORD
PutStr        PROTO, px:DWORD, py:DWORD, pStr:PTR BYTE, clr:DWORD
HLine         PROTO, px:DWORD, py:DWORD, cnt:DWORD, glyph:DWORD, clr:DWORD
VLine         PROTO, px:DWORD, py:DWORD, cnt:DWORD, glyph:DWORD, clr:DWORD
PutNumber     PROTO, px:DWORD, py:DWORD, num:DWORD, clr:DWORD
FindPlat      PROTO, lift:DWORD, h:DWORD
DrawContainer PROTO, idx:DWORD
DrawTruck     PROTO, px:DWORD, load:DWORD
LoseLife      PROTO, reason:PTR BYTE

.data
; ---- 2-D screen buffers (SCR_H rows x STRIDE columns, row-major) ----
screenChars BYTE SCR_H*STRIDE DUP(' ')
screenAttr  BYTE SCR_H*STRIDE DUP(7)

; ---- world arrays ----
hRow        DWORD 20, 16, 12, 8             ; platform / tunnel-floor row of heights 0..3
shaftLeftX  DWORD 34, 41                    ; left column of each shaft (width 5)
liftPos     DWORD 4 DUP(0)                  ; heights of platforms: [lift*2 + k]
liftInit    DWORD 0, 2, 1, 3                ; lift 0 starts at 0,2 - lift 1 at 1,3
liftTick    DWORD 2 DUP(0)                  ; frame counter of each lift
liftTickInit DWORD 0, LIFT_OFFSET           ; lift 1 is half an interval behind
liftDir     SDWORD 1, -1                    ; lift 0 goes UP, lift 1 goes DOWN
contFill    DWORD 4 DUP(0)                  ; 0=top-left 1=bottom-left 2=top-right 3=bottom-right
truckLoad   DWORD 2 DUP(0)                  ; left truck, right truck

; ---- Mario ----
marioX      DWORD START_X
marioH      DWORD START_H                   ; height 0..3 (tunnels are 1 and 2)
marioOn     SDWORD -1                       ; -1 = in a tunnel, else lift number
marioPlat   DWORD 0                         ; which platform of that lift
walkFrame   DWORD 0
marioHead   BYTE "(M)",0
marioBody   BYTE "/H\",0,"|H|",0            ; 2 frames, 4 bytes each

; ---- game state ----
score       DWORD 0
bestScore   DWORD 0
lives       SDWORD 3
fillTimer   DWORD 0
inputFlags  BYTE 0
animPattern BYTE 11110000b                  ; rotated each frame (blink/animation)
lastGain    DWORD 0
gainTimer   DWORD 0
statusTimer DWORD 0
statusMsg   DWORD OFFSET msgNone
cursorInfo  DWORD 10, 0                     ; dwSize, bVisible (hide cursor)

; ---- strings ----
titleStr    BYTE "MARIO CEMENT FACTORY",0
scoreLbl    BYTE "SCORE:",0
bestLbl     BYTE "BEST:",0
livesLbl    BYTE "LIVES:",0
platStr     BYTE "[===]",0
upStr       BYTE "UP ^",0
dnStr       BYTE "DN v",0
mixerStr    BYTE "[MIXER]",0
helpStr     BYTE "Arrows/A,D = move   SPACE = drop cement   Q = quit",0
msgNone     BYTE 0
msgSpill    BYTE "CEMENT SPILLED!  A container overflowed.",0
msgFell     BYTE "The shaft was empty - you fell and crashed at the bottom!",0
msgCrashTop BYTE "Your lift crushed you against the roof!",0
msgCrashBot BYTE "Your lift slammed you into the floor!",0

introText   BYTE 0Dh,0Ah
            BYTE "   =================================================",0Dh,0Ah
            BYTE "                MARIO  CEMENT  FACTORY",0Dh,0Ah
            BYTE "   =================================================",0Dh,0Ah,0Dh,0Ah
            BYTE "    Mixers drip cement into the two TOP containers.",0Dh,0Ah
            BYTE "    Every container holds at most 3 elements.",0Dh,0Ah,0Dh,0Ah
            BYTE "    The centre has two lifts:  left = always UP,",0Dh,0Ah
            BYTE "    right = always DOWN.  They move at different",0Dh,0Ah
            BYTE "    moments, so wait for a platform at your height",0Dh,0Ah
            BYTE "    before stepping in or hopping across!",0Dh,0Ah,0Dh,0Ah
            BYTE "    SPACE at a TOP container    : drop 1 element down",0Dh,0Ah
            BYTE "                                  into the lower one",0Dh,0Ah
            BYTE "    SPACE at a BOTTOM container : drop 1 element into",0Dh,0Ah
            BYTE "                                  the truck (points!)",0Dh,0Ah,0Dh,0Ah
            BYTE "    You lose a life if a lift crushes you at the top or",0Dh,0Ah
            BYTE "    bottom, if you step into an empty shaft, or if a",0Dh,0Ah
            BYTE "    container overflows.  You have 3 lives.",0Dh,0Ah,0Dh,0Ah
            BYTE "    LEFT / RIGHT or A / D to move,  Q to quit",0Dh,0Ah,0Dh,0Ah
            BYTE "    Press any key to start...",0

; ---- game-over box (each line exactly 30 characters) ----
goL0 BYTE '+', 28 DUP('-'), '+', 0
goL1 BYTE '|', 9 DUP(' '), "GAME  OVER", 9 DUP(' '), '|', 0
goL2 BYTE '|', 28 DUP(' '), '|', 0
goL3 BYTE '|', "  SCORE:", 20 DUP(' '), '|', 0
goL4 BYTE '|', "  BEST :", 20 DUP(' '), '|', 0
goL5 BYTE '|', 28 DUP(' '), '|', 0
goL6 BYTE '|', "  [R] Play again  [Q] Quit  ", '|', 0
goL7 BYTE '+', 28 DUP('-'), '+', 0
goLines DWORD OFFSET goL0, OFFSET goL1, OFFSET goL2, OFFSET goL3
        DWORD OFFSET goL4, OFFSET goL5, OFFSET goL6, OFFSET goL7

.code


main PROC
    call Randomize
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    INVOKE SetConsoleCursorInfo, eax, ADDR cursorInfo
    call ShowTitle

newGame:
    call ResetGame
    call Clrscr

playLoop:
    call ReadInput
    test inputFlags, IN_QUIT
    jnz quitNow
    call MoveMario
    call DoAction
    call UpdateLifts
    call UpdateContainers
    call TickTimers
    rol animPattern, 1                  ; rotate -> blinking / moving chutes
    call DrawScene
    call Render
    INVOKE Sleep, FRAME_MS
    cmp lives, 0
    jg playLoop

    call ShowGameOver                   ; EAX = 1 -> play again
    cmp eax, 1
    je newGame

quitNow:
    mov DWORD PTR [cursorInfo+4], 1     ; show the cursor again
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    INVOKE SetConsoleCursorInfo, eax, ADDR cursorInfo
    mov eax, lightGray
    call SetTextColor
    call Clrscr
    exit
main ENDP

CellIndex PROC USES ebx ecx edx, col:DWORD, row:DWORD
    mov eax, col
    cmp eax, SCR_W                      
    jae outside
    mov ebx, row
    cmp ebx, SCR_H
    jae outside
    mov ecx, ebx
    shl ecx, 6                          ; row * 64
    mov edx, ebx
    shl edx, 4                          ; row * 16
    add ecx, edx
    add ecx, ebx                        ; row * 81
    add eax, ecx
    ret
outside:
    mov eax, -1
    ret
CellIndex ENDP

PutChar PROC USES eax edx, px:DWORD, py:DWORD, glyph:DWORD, clr:DWORD
    INVOKE CellIndex, px, py
    cmp eax, -1
    je pcDone
    mov edx, eax
    mov eax, glyph
    mov screenChars[edx], al
    mov eax, clr
    mov screenAttr[edx], al
pcDone:
    ret
PutChar ENDP

PutStr PROC USES eax ebx esi, px:DWORD, py:DWORD, pStr:PTR BYTE, clr:DWORD
    mov esi, pStr
    mov ebx, px
psNext:
    movzx eax, BYTE PTR [esi]
    cmp al, 0
    je psDone
    INVOKE PutChar, ebx, py, eax, clr
    inc ebx
    inc esi
    jmp psNext
psDone:
    ret
PutStr ENDP

HLine PROC USES ebx ecx, px:DWORD, py:DWORD, cnt:DWORD, glyph:DWORD, clr:DWORD
    mov ecx, cnt
    mov ebx, px
    cmp ecx, 0
    jle hlDone
hlLoop:
    INVOKE PutChar, ebx, py, glyph, clr
    inc ebx
    loop hlLoop
hlDone:
    ret
HLine ENDP

VLine PROC USES ebx ecx, px:DWORD, py:DWORD, cnt:DWORD, glyph:DWORD, clr:DWORD
    mov ecx, cnt
    mov ebx, py
    cmp ecx, 0
    jle vlDone
vlLoop:
    INVOKE PutChar, px, ebx, glyph, clr
    inc ebx
    loop vlLoop
vlDone:
    ret
VLine ENDP

; RECURSIVE: writes the decimal digits of NUM at (px,py); returns the next
; free column in EAX.  PutNumber(n) = PutNumber(n/10) followed by digit n%10.
PutNumber PROC USES ebx ecx edx, px:DWORD, py:DWORD, num:DWORD, clr:DWORD
    mov eax, num
    mov ebx, px
    cmp eax, 10
    jb lastDigit
    xor edx, edx
    mov ecx, 10
    div ecx                             ; EAX = num / 10
    INVOKE PutNumber, px, py, eax, clr  ; recursive call, returns next column
    mov ebx, eax
lastDigit:
    mov eax, num
    xor edx, edx
    mov ecx, 10
    div ecx                             ; EDX = num mod 10
    add edx, '0'
    INVOKE PutChar, ebx, py, edx, clr
    lea eax, [ebx+1]
    ret
PutNumber ENDP

; fill both buffers using the string primitives (REP STOSB)
ClearScreen PROC USES eax ecx edi
    cld
    mov edi, OFFSET screenChars
    mov al, ' '
    mov ecx, LENGTHOF screenChars
    rep stosb
    mov edi, OFFSET screenAttr
    mov al, lightGray
    mov ecx, LENGTHOF screenAttr
    rep stosb
    mov edi, OFFSET screenChars + SCR_W ; put a 0 byte at the end of every row
    mov ecx, SCR_H
termLoop:
    mov BYTE PTR [edi], 0
    add edi, STRIDE
    loop termLoop
    ret
ClearScreen ENDP

; Copy the buffers to the console. Consecutive cells with the same colour are
; written together as one "run" (temporarily 0-terminated) to keep it fast.
Render PROC USES eax ebx ecx edx esi edi
    LOCAL rowNo:DWORD, colNo:DWORD, runEnd:DWORD, startIdx:DWORD
    LOCAL endIdx:DWORD, runClr:DWORD, saveCh:BYTE

    mov rowNo, 0
nextRow:
    mov colNo, 0
nextRun:
    INVOKE CellIndex, colNo, rowNo
    mov startIdx, eax
    mov esi, eax
    movzx eax, screenAttr[esi]
    mov runClr, eax
    mov eax, colNo
    inc eax
    mov runEnd, eax
    inc esi                             ; ESI = index of cell number runEnd
extendRun:
    cmp runEnd, SCR_W
    jae runDone
    movzx eax, screenAttr[esi]
    cmp eax, runClr
    jne runDone
    inc runEnd
    inc esi
    jmp extendRun
runDone:
    mov endIdx, esi
    mov ebx, esi
    mov al, screenChars[ebx]
    mov saveCh, al
    mov screenChars[ebx], 0             ; temporary terminator
    mov eax, runClr
    call SetTextColor
    mov dh, BYTE PTR rowNo
    mov dl, BYTE PTR colNo
    call Gotoxy
    mov edx, OFFSET screenChars
    add edx, startIdx
    call WriteString
    mov ebx, endIdx
    mov al, saveCh
    mov screenChars[ebx], al            ; restore
    mov eax, runEnd
    mov colNo, eax
    cmp eax, SCR_W
    jb nextRun
    inc rowNo
    cmp rowNo, SCR_H
    jb nextRow
    ret
Render ENDP

;=====================================================================================
;Draw Scene
;=====================================================================================

; Container idx: 0 = top-left, 1 = bottom-left, 2 = top-right, 3 = bottom-right
DrawContainer PROC USES eax ebx ecx edx esi edi, idx:DWORD
    mov esi, idx
    mov eax, esi
    and eax, 1                          ; 0 = top container, 1 = bottom one
    mov ebx, 2
    sub ebx, eax                        ; height of its tunnel (2 or 1)
    mov ebx, hRow[ebx*4]                ; floor row of this container
    mov edi, LC_X                       ; first interior column (left side)
    cmp esi, 2
    jb sideSet
    mov edi, RC_X                       ; right side
sideSet:
    ; walls: columns edi-1 and edi+5, rows floor-3 .. floor-1
    mov ecx, MAXFILL
    mov edx, ebx
    dec edx
wallLoop:
    lea eax, [edi-1]
    INVOKE PutChar, eax, edx, '|', lightGray
    lea eax, [edi+5]
    INVOKE PutChar, eax, edx, '|', lightGray
    dec edx
    loop wallLoop

    ; cement stack (colour warns as it fills)
    mov ecx, contFill[esi*4]
    cmp ecx, 0
    je noCement
    mov eax, lightGray
    cmp ecx, 2
    jb colSet
    mov eax, yellow
    cmp ecx, MAXFILL
    jb colSet
    mov eax, lightRed
colSet:
    mov edx, ebx
    dec edx
fillLoop:
    INVOKE HLine, edi, edx, 5, '#', eax
    dec edx
    loop fillLoop
noCement:

    ; blinking warning when the container is full
    cmp contFill[esi*4], MAXFILL
    jb noWarn
    test animPattern, 1
    jz noWarn
    mov edx, ebx
    sub edx, 2
    lea eax, [edi-3]                    ; "!" just outside the container
    cmp esi, 2
    jb warnCol
    lea eax, [edi+7]
warnCol:
    INVOKE PutChar, eax, edx, '!', lightRed
noWarn:
    ret
DrawContainer ENDP

; Truck: bed (4 load cells), cab, chassis, wheels. Occupies rows 18..20.
DrawTruck PROC USES eax ebx ecx, px:DWORD, load:DWORD
    INVOKE PutChar, px, 18, '|', lightGray
    mov ebx, px
    inc ebx                             ; first bed cell
    mov ecx, 0
bedLoop:
    mov eax, ' '
    cmp load, ecx
    jbe bedEmpty                        ; load <= cell number -> empty cell
    mov eax, '#'
bedEmpty:
    INVOKE PutChar, ebx, 18, eax, lightGray
    inc ebx
    inc ecx
    cmp ecx, TRUCK_CAP
    jb bedLoop
    INVOKE PutChar, ebx, 18, '|', lightGray
    inc ebx
    INVOKE PutChar, ebx, 18, '[', yellow
    inc ebx
    INVOKE PutChar, ebx, 18, ']', yellow
    INVOKE HLine, px, 19, 8, '=', brown
    mov ebx, px
    inc ebx
    INVOKE PutChar, ebx, 20, 'O', white
    add ebx, 5
    INVOKE PutChar, ebx, 20, 'O', white
    ret
DrawTruck ENDP

DrawScene PROC USES eax ebx ecx edx esi edi
    INVOKE ClearScreen

    ; ---- HUD ----
    INVOKE PutStr, 2, 0, ADDR titleStr, yellow
    INVOKE PutStr, 28, 0, ADDR scoreLbl, white
    INVOKE PutNumber, 35, 0, score, lightGreen
    INVOKE PutStr, 46, 0, ADDR bestLbl, white
    INVOKE PutNumber, 52, 0, bestScore, lightCyan
    INVOKE PutStr, 62, 0, ADDR livesLbl, white
    mov ecx, lives
    cmp ecx, 0
    jle noHearts
    mov ebx, 69
heartLoop:
    INVOKE PutChar, ebx, 0, 'M', lightRed
    add ebx, 2
    loop heartLoop
noHearts:

    ; ---- tunnel floors / ceilings (heights 1,2,3) + container release gaps ----
    mov esi, 1
levelLoop:
    mov ebx, hRow[esi*4]
    INVOKE HLine, LC_X-1, ebx, TUN_LEN, '=', brown   ; left  tunnel
    INVOKE HLine, 46, ebx, TUN_LEN, '=', brown       ; right tunnel
    INVOKE PutChar, LC_X+2, ebx, 'v', lightGray      ; cement falls through here
    INVOKE PutChar, RC_X+2, ebx, 'v', lightGray
    inc esi
    cmp esi, 4
    jb levelLoop

    ; ---- shaft walls (openings at the tunnel heights), divider, roof, pit ----
    INVOKE HLine, 34, 1, 12, 'v', red        ; roof: lifts crush Mario here
    INVOKE HLine, 34, 21, 12, '^', red       ; floor: Mario crashes here
    INVOKE VLine, 33, 2, 6, '|', gray
    INVOKE VLine, 33, 17, 4, '|', gray
    INVOKE VLine, 46, 2, 6, '|', gray
    INVOKE VLine, 46, 17, 4, '|', gray
    INVOKE VLine, 39, 2, 19, '|', gray
    INVOKE VLine, 40, 2, 19, '|', gray
    INVOKE PutStr, 35, 3, ADDR upStr, lightGreen
    INVOKE PutStr, 42, 3, ADDR dnStr, lightCyan
    INVOKE HLine, 0, 21, 34, '#', brown
    INVOKE HLine, 46, 21, 34, '#', brown

    ; ---- mixers with animated chutes ----
    INVOKE PutStr, LC_X-1, 3, ADDR mixerStr, yellow
    INVOKE PutStr, RC_X-1, 3, ADDR mixerStr, yellow
    mov ebx, 4
chuteLoop:
    mov eax, ebx
    xor al, animPattern
    test al, 1
    mov eax, ':'
    jz drawChute
    mov eax, '.'
drawChute:
    INVOKE PutChar, LC_X+2, ebx, eax, lightGray
    INVOKE PutChar, RC_X+2, ebx, eax, lightGray
    inc ebx
    cmp ebx, 8
    jb chuteLoop

    ; ---- the four containers and the two trucks ----
    mov esi, 0
contLoop:
    INVOKE DrawContainer, esi
    inc esi
    cmp esi, LENGTHOF contFill
    jb contLoop
    INVOKE DrawTruck, LC_X-2, truckLoad[0]
    INVOKE DrawTruck, RC_X-1, truckLoad[4]

    ; ---- lift platforms (4 in total: 2 per lift) ----
    mov esi, 0
platDraw:
    mov ebx, esi
    shr ebx, 1                          ; lift number = platform / 2
    mov edi, shaftLeftX[ebx*4]
    mov eax, liftPos[esi*4]
    mov edx, hRow[eax*4]
    mov eax, yellow
    cmp ebx, 0
    je platClr
    mov eax, lightCyan
platClr:
    INVOKE PutStr, edi, edx, ADDR platStr, eax
    inc esi
    cmp esi, LENGTHOF liftPos
    jb platDraw

    ; ---- Mario (2 rows tall, 3 wide), feet stand on the row above hRow ----
    mov eax, marioH
    mov ebx, hRow[eax*4]
    dec ebx                             ; feet row
    mov ecx, ebx
    dec ecx                             ; head row
    mov eax, marioX
    dec eax
    INVOKE PutStr, eax, ecx, ADDR marioHead, lightRed
    mov edx, walkFrame
    shl edx, 2                          ; frame * 4 bytes per sprite string
    add edx, OFFSET marioBody
    INVOKE PutStr, eax, ebx, edx, lightCyan

    ; ---- "+points" popup (uses the recursive PutNumber) ----
    cmp gainTimer, 0
    je noGain
    mov eax, marioX
    sub ebx, 3
    INVOKE PutChar, eax, ebx, '+', lightGreen
    inc eax
    INVOKE PutNumber, eax, ebx, lastGain, lightGreen
noGain:

    ; ---- status line + help ----
    cmp statusTimer, 0
    je noStatus
    INVOKE PutStr, 2, 22, statusMsg, lightRed
noStatus:
    INVOKE PutStr, 2, 23, ADDR helpStr, gray
    ret
DrawScene ENDP

; ============================================================================
;  Input
; ============================================================================
ReadInput PROC USES eax edx
    mov inputFlags, 0
pollKey:
    call ReadKey                        ; ZF = 1 when no key is waiting
    jz inputDone
    cmp dx, VKEY_LEFT
    je setLeft
    cmp dx, VKEY_RIGHT
    je setRight
    cmp al, 0                           ; other special keys: ignore
    je pollKey
    or al, 20h                          ; fold upper case to lower case
    cmp al, 'a'
    je setLeft
    cmp al, 'd'
    je setRight
    cmp al, ' '
    je setAct
    cmp al, 'q'
    je setQuit
    jmp pollKey
setLeft:
    or inputFlags, IN_LEFT
    jmp pollKey
setRight:
    or inputFlags, IN_RIGHT
    jmp pollKey
setAct:
    or inputFlags, IN_ACT
    jmp pollKey
setQuit:
    or inputFlags, IN_QUIT
    jmp pollKey
inputDone:
    ret
ReadInput ENDP

; ============================================================================
;  Game logic
; ============================================================================

; EAX = platform number (0/1) of LIFT that is at height H, or -1 if none
FindPlat PROC USES ebx ecx, lift:DWORD, h:DWORD
    mov ebx, lift
    shl ebx, 1                          ; first platform of that lift
    mov ecx, h
    cmp liftPos[ebx*4], ecx
    je plat0
    cmp liftPos[ebx*4+4], ecx
    je plat1
    mov eax, -1
    ret
plat0:
    mov eax, 0
    ret
plat1:
    mov eax, 1
    ret
FindPlat ENDP

LoseLife PROC USES eax ecx edi, reason:PTR BYTE
    dec lives
    mov eax, reason
    mov statusMsg, eax
    mov statusTimer, 45
    mov marioX, START_X                 ; respawn in the left tunnel, height 2
    mov marioH, START_H
    mov marioOn, -1
    cld                                 ; empty all containers (REP STOSD)
    mov edi, OFFSET contFill
    mov ecx, LENGTHOF contFill
    xor eax, eax
    rep stosd
    mov fillTimer, 0
    ret
LoseLife ENDP

MoveMario PROC USES eax ecx edx
    LOCAL dirv:SDWORD

    mov dirv, 0
    test inputFlags, IN_LEFT
    jz noLeft
    dec dirv
noLeft:
    test inputFlags, IN_RIGHT
    jz noRight
    inc dirv
noRight:
    cmp dirv, 0
    je mmDone                           ; no key, or both keys
    xor walkFrame, 1                    ; toggle walking animation

    cmp marioOn, -1
    jne onALift

    ; ---------- walking in a tunnel ----------
    mov eax, marioX
    add eax, dirv                       ; EAX = wanted column
    cmp marioX, 40
    jge rightTunnel

    cmp eax, L_MINX                     ; left tunnel
    jl mmDone
    cmp eax, L_MAXX+1                   ; one step past the end = the shaft
    je boardLeft
    mov marioX, eax
    jmp mmDone
boardLeft:
    mov ecx, 0                          ; lift 0 (the UP lift)
    jmp boardLift

rightTunnel:
    cmp eax, R_MAXX
    jg mmDone
    cmp eax, R_MINX-1                   ; one step past the end = the shaft
    je boardRight
    mov marioX, eax
    jmp mmDone
boardRight:
    mov ecx, 1                          ; lift 1 (the DOWN lift)

boardLift:                              ; is a platform at Mario's height?
    INVOKE FindPlat, ecx, marioH
    cmp eax, -1
    je fell                             ; nothing there: he falls down the shaft
    mov marioPlat, eax
    mov marioOn, ecx
    mov eax, shaftLeftX[ecx*4]
    add eax, 2                          ; middle of the shaft
    mov marioX, eax
    jmp mmDone

    ; ---------- standing on a lift ----------
onALift:
    mov ecx, marioOn
    cmp dirv, 0
    jl wantLeft
    cmp ecx, 0                          ; pressing RIGHT
    je crossLift                        ; on lift 0 -> hop to lift 1
    mov edx, R_MINX                     ; on lift 1 -> leave into right tunnel
    jmp exitLift
wantLeft:
    cmp ecx, 1
    je crossLift                        ; on lift 1 -> hop to lift 0
    mov edx, L_MAXX                     ; on lift 0 -> leave into left tunnel
exitLift:
    mov eax, marioH
    cmp eax, 1                          ; tunnels exist only at heights 1 and 2
    jb mmDone
    cmp eax, 2
    ja mmDone
    mov marioX, edx
    mov marioOn, -1
    jmp mmDone
crossLift:
    xor ecx, 1                          ; the other lift
    jmp boardLift

fell:
    INVOKE LoseLife, ADDR msgFell
mmDone:
    ret
MoveMario ENDP

; SPACE: drop one cement element from the container Mario stands at
DoAction PROC USES eax ebx ecx edx
    test inputFlags, IN_ACT
    jz daDone
    cmp marioOn, -1
    jne daDone                          ; not while riding a lift

    mov ebx, 0                          ; EBX = side (0 left, 1 right)
    cmp marioX, L_MINX                  ; only the cell next to the container works
    jbe haveSide
    mov ebx, 1
    cmp marioX, R_MAXX
    jae haveSide
    jmp daDone                          ; not next to a container
haveSide:
    mov ecx, ebx
    shl ecx, 1                          ; side * 2
    mov eax, 2
    sub eax, marioH                     ; height 2 -> 0 (top), height 1 -> 1 (bottom)
    add ecx, eax                        ; ECX = container index
    cmp contFill[ecx*4], 0
    je daDone                           ; nothing to drop
    dec contFill[ecx*4]

    cmp marioH, 2
    jne toTruck
    inc contFill[ecx*4+4]               ; top container -> container below
    cmp contFill[ecx*4+4], MAXFILL
    jbe moveOk
    INVOKE LoseLife, ADDR msgSpill      ; the lower one was already full!
    jmp daDone
moveOk:
    mov eax, 5
    jmp addPoints
toTruck:                                ; bottom container -> truck
    mov eax, 10
    inc truckLoad[ebx*4]
    cmp truckLoad[ebx*4], TRUCK_CAP
    jb addPoints
    add eax, 40                         ; truck is full: bonus, new truck
    mov truckLoad[ebx*4], 0
addPoints:
    add score, eax
    mov lastGain, eax
    mov gainTimer, 15
daDone:
    ret
DoAction ENDP

; Each lift has its OWN timer.  Every LIFT_FRAMES frames a lift moves both of its
; platforms one height (lift 0 up, lift 1 down).  Lift 1's timer starts
; LIFT_OFFSET frames behind lift 0, so the two lifts change state at different
; moments.  Leaving the range 0..3 means hitting the roof / floor (crash if Mario
; is on that platform) and the platform re-appears at the opposite end.
UpdateLifts PROC USES eax ecx edx esi edi
    LOCAL riding:DWORD
    mov edi, 0                          ; EDI = lift number
liftLoop:
    inc liftTick[edi*4]
    cmp liftTick[edi*4], LIFT_FRAMES
    jb nextLift                         ; not this lift's turn yet
    mov liftTick[edi*4], 0
    mov esi, edi
    shl esi, 1                          ; ESI = first platform of this lift
    mov edx, esi
    add edx, 2                          ; EDX = one past its last platform
platLoop:
    mov riding, 0                       ; is Mario standing on this platform?
    cmp marioOn, edi
    jne notRiding
    mov ecx, esi
    and ecx, 1                          ; platform number within its lift
    cmp marioPlat, ecx
    jne notRiding
    mov riding, 1
notRiding:
    mov eax, liftPos[esi*4]
    add eax, liftDir[edi*4]             ; new height (-1 .. 4)
    cmp eax, 0
    jl outOfRange
    cmp eax, 3
    jle inRange
outOfRange:
    cmp riding, 0
    je wrapIt
    mov riding, 0                       ; Mario respawns, he is no longer on it
    cmp eax, 3
    jg crashTop
    INVOKE LoseLife, ADDR msgCrashBot
    jmp wrapIt
crashTop:
    INVOKE LoseLife, ADDR msgCrashTop
wrapIt:
    cmp eax, 0
    jl wrapToTop
    mov eax, 0                          ; went above the roof -> back to bottom
    jmp inRange
wrapToTop:
    mov eax, 3                          ; went below the floor -> back to top
inRange:
    mov liftPos[esi*4], eax
    cmp riding, 0                       ; carry Mario along
    je nextPlat
    mov marioH, eax
nextPlat:
    inc esi
    cmp esi, edx
    jb platLoop
nextLift:
    inc edi
    cmp edi, LENGTHOF liftTick
    jb liftLoop
    ret
UpdateLifts ENDP

; Mixers drip cement into a random TOP container; faster as the score grows
UpdateContainers PROC USES eax ebx edx
    inc fillTimer
    mov eax, score                      ; delay = BASE - score/10 (min MIN)
    xor edx, edx
    mov ebx, 10
    div ebx
    mov ebx, BASE_DELAY
    sub ebx, eax
    cmp ebx, MIN_DELAY
    jge delayOk
    mov ebx, MIN_DELAY
delayOk:
    cmp fillTimer, ebx
    jb ucDone
    mov fillTimer, 0
    mov eax, 2
    call RandomRange                    ; 0 = left mixer, 1 = right mixer
    shl eax, 1                          ; index of that side's TOP container
    inc contFill[eax*4]
    cmp contFill[eax*4], MAXFILL
    jbe ucDone
    INVOKE LoseLife, ADDR msgSpill      ; top container overflowed
ucDone:
    ret
UpdateContainers ENDP

TickTimers PROC
    cmp statusTimer, 0
    je tt1
    dec statusTimer
tt1:
    cmp gainTimer, 0
    je tt2
    dec gainTimer
tt2:
    ret
TickTimers ENDP

ResetGame PROC USES eax ecx esi edi
    cld
    mov score, 0
    mov lives, 3
    mov marioX, START_X
    mov marioH, START_H
    mov marioOn, -1
    mov marioPlat, 0
    mov walkFrame, 0
    mov fillTimer, 0
    mov statusTimer, 0
    mov gainTimer, 0
    mov statusMsg, OFFSET msgNone

    mov esi, OFFSET liftInit            ; copy start heights (REP MOVSD)
    mov edi, OFFSET liftPos
    mov ecx, LENGTHOF liftPos
    rep movsd
    mov esi, OFFSET liftTickInit        ; lift 1 starts half an interval behind
    mov edi, OFFSET liftTick
    mov ecx, LENGTHOF liftTick
    rep movsd

    xor eax, eax                        ; empty containers and trucks (REP STOSD)
    mov edi, OFFSET contFill
    mov ecx, LENGTHOF contFill
    rep stosd
    mov edi, OFFSET truckLoad
    mov ecx, LENGTHOF truckLoad
    rep stosd
    ret
ResetGame ENDP


ShowTitle PROC USES eax edx
    call Clrscr
    mov eax, yellow
    call SetTextColor
    mov edx, OFFSET introText
    call WriteString
    call ReadChar
    ret
ShowTitle ENDP


ShowGameOver PROC USES ebx ecx edx esi
    mov eax, score
    cmp eax, bestScore
    jbe keepBest
    mov bestScore, eax
keepBest:
    mov esi, 0
boxLoop:
    mov eax, esi
    add eax, 8                          ; box starts at row 8
    INVOKE PutStr, 25, eax, goLines[esi*4], BOX_CLR
    inc esi
    cmp esi, LENGTHOF goLines
    jb boxLoop
    INVOKE PutNumber, 35, 11, score, BOX_CLR
    INVOKE PutNumber, 35, 12, bestScore, BOX_CLR
    call Render

flushKeys:
    call ReadKey
    jnz flushKeys
waitKey:
    call ReadChar
    or al, 20h
    cmp al, 'r'
    je replay
    cmp al, 'q'
    jne waitKey
    mov eax, 0
    ret
replay:
    mov eax, 1
    ret
ShowGameOver ENDP

END main
