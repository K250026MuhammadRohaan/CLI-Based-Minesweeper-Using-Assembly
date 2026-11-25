; ============================================================================
;  MINESWEEPER IN x86 ASSEMBLY (MASM + Irvine32)
;  EL-2003 COAL Lab | Fall 2026 | Group 16 | BAI-3A
;  Muhammad Rohaan (25K-0026), Sarim Raza Ansari (25K-0064),
;  Rana Muhammad Hussain (25K-0141)
; ----------------------------------------------------------------------------
;  Game rules of THIS version:
;   - 3 difficulty levels: EASY, MEDIUM, HARD (each has its own board size).
;   - Selecting a tile (Enter) reveals that tile AND the 8 tiles around it
;     (a 3x3 area). Mines inside the 3x3 area stay hidden.
;   - The player loses ONLY if the selected tile itself is a mine.
;   - If the very first selected tile is a mine, the mine is moved elsewhere.
;   - CASCADE: any revealed blank tile (0 mines nearby) automatically opens
;     its neighbours, and this repeats until no more blank tiles can spread.
;   - CHORDING (C key): on a revealed number whose flag count equals the
;     number, all remaining hidden neighbours are opened at once.
;   - Best time of each difficulty is saved in "besttime.dat".
;
;  Controls: Arrow keys = move | Enter = select | F = flag | C = chord
;            Esc = back to menu
; ============================================================================

INCLUDE Irvine32.inc

; ============================================================================
;  CONSTANTS
; ============================================================================

; --- Cell state bits (every board cell is one byte) ---
CELL_MINE       EQU 1           ; bit 0 : cell contains a mine
CELL_REVEALED   EQU 2           ; bit 1 : cell is revealed
CELL_FLAG       EQU 4           ; bit 2 : cell has a flag

; --- Board limits and screen position ---
MAX_CELLS       EQU 480         ; largest board (HARD = 30 x 16)
BOARD_X         EQU 2           ; screen column where the board starts
BOARD_Y         EQU 5           ; screen row where the board starts

; --- Virtual key codes returned by ReadKey in DX ---
KEY_LEFT        EQU 25h
KEY_UP          EQU 26h
KEY_RIGHT       EQU 27h
KEY_DOWN        EQU 28h
KEY_ENTER       EQU 0Dh
KEY_ESC         EQU 1Bh
KEY_F           EQU 46h
KEY_C           EQU 43h

; --- Colours used for drawing ---
CURSOR_COLOR    EQU 0E0h        ; black text on yellow background
EXPLODE_COLOR   EQU 4Fh         ; white text on red background

; ============================================================================
;  MACROS
; ============================================================================

; Set the text colour (foreground + background*16)
SetColor MACRO colour
    mov eax, colour
    call SetTextColor
ENDM

; Move the console cursor to a row and column
GotoRC MACRO rowNum, colNum
    mov dh, rowNum
    mov dl, colNum
    call Gotoxy
ENDM

; Set a colour and print a zero-terminated string
ShowText MACRO textLabel, colour
    mov eax, colour
    call SetTextColor
    mov edx, OFFSET textLabel
    call WriteString
ENDM

; ============================================================================
;  DATA SECTION (shared by all modules)
; ============================================================================
.data

; ----- Board arrays (one-dimensional, index = row * boardW + column) -----
board           BYTE MAX_CELLS DUP(0)   ; cell state bits
counts          BYTE MAX_CELLS DUP(0)   ; number of mines around each cell

; ----- Difficulty tables (index 0 = EASY, 1 = MEDIUM, 2 = HARD) -----
widthTable      DWORD 9, 16, 30
heightTable     DWORD 9, 16, 16
mineTable       DWORD 10, 40, 99
diffNames       DWORD OFFSET strEasy, OFFSET strMedium, OFFSET strHard

; ----- Current game settings (filled by SetDifficulty) -----
difficulty      DWORD 0
boardW          DWORD 9
boardH          DWORD 9
boardSize       DWORD 81
mineCount       DWORD 10

; ----- Game state -----
cursorRow       DWORD 0
cursorCol       DWORD 0
flagsPlaced     DWORD 0
revealedCount   DWORD 0
gameOver        DWORD 0
gameWon         DWORD 0
firstMove       DWORD 1
timerRunning    DWORD 0
startTime       DWORD 0
elapsedSec      DWORD 0
newRecord       DWORD 0

; ----- Neighbour list filled by GetNeighbours -----
nbrCount        DWORD 0
nbrList         DWORD 8 DUP(0)

; ----- Best times (Easy, Medium, Hard; 0 = no record yet) -----
bestTimes       DWORD 3 DUP(0)

; ----- Strings used by more than one module -----
strEasy         BYTE "EASY",0
strMedium       BYTE "MEDIUM",0
strHard         BYTE "HARD",0
strPad          BYTE "    ",0
strNone         BYTE "--",0
strSecUnit      BYTE " s",0
strAnyKey       BYTE "  Press any key to go back...",0

; ============================================================================
;  "DAY DONE" FLAGS  (each day file sets its own flag to 1 at its last line)
; ============================================================================
ROHAAN_D1_DONE  = 0
ROHAAN_D2_DONE  = 0
ROHAAN_D3_DONE  = 0
ROHAAN_D4_DONE  = 0
ROHAAN_D5_DONE  = 0
ROHAAN_D6_DONE  = 0
SARIM_D1_DONE   = 0
SARIM_D2_DONE   = 0
SARIM_D3_DONE   = 0
SARIM_D4_DONE   = 0
SARIM_D5_DONE   = 0
SARIM_D6_DONE   = 0
RANA_D1_DONE    = 0
RANA_D2_DONE    = 0
RANA_D3_DONE    = 0
RANA_D4_DONE    = 0
RANA_D5_DONE    = 0
RANA_D6_DONE    = 0

; ============================================================================
;  CODE SECTION
;  Layout: [Rohaan zone] [Sarim zone] [Rana zone] [stubs] [main + game loop]
; ============================================================================
.code

; ############################################################################
; #  ZONE 1 OF 3 :  MUHAMMAD ROHAAN  -  Board and mines / Neighbour counting / 3x3 reveal (+Cascade, Chording)
; #  Only Muhammad Rohaan writes inside this zone, between the START and END lines.
; #  Everything outside the three zones is shared base code: do NOT edit it.
; ############################################################################
; >>>>>>>>>>>>>>>>>>>>  ROHAAN ZONE START  <<<<<<<<<<<<<<<<<<<<

; >>>>>>>>>>>>>>>>>>>>  ROHAAN ZONE END  <<<<<<<<<<<<<<<<<<<<<<

; ----------------------------------------------------------------------------
; (end of zone - shared base code continues below)
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------

; ############################################################################
; #  ZONE 2 OF 3 :  SARIM RAZA ANSARI  -  Main menu / Flags / Win and lose logic
; #  Only Sarim Raza Ansari writes inside this zone, between the START and END lines.
; #  Everything outside the three zones is shared base code: do NOT edit it.
; ############################################################################
; >>>>>>>>>>>>>>>>>>>>  SARIM ZONE START  <<<<<<<<<<<<<<<<<<<<

; >>>>>>>>>>>>>>>>>>>>  SARIM ZONE END  <<<<<<<<<<<<<<<<<<<<<<

; ----------------------------------------------------------------------------
; (end of zone - shared base code continues below)
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------

; ############################################################################
; #  ZONE 3 OF 3 :  RANA MUHAMMAD HUSSAIN  -  Display and cursor / Counter and timer / Best-time file
; #  Only Rana Muhammad Hussain writes inside this zone, between the START and END lines.
; #  Everything outside the three zones is shared base code: do NOT edit it.
; ############################################################################
; >>>>>>>>>>>>>>>>>>>>  RANA ZONE START  <<<<<<<<<<<<<<<<<<<<

; ---------------------------------------------------------------------------
;  RANA MUHAMMAD HUSSAIN - DAY 1  (GetCursorIndex, DrawCell)
; ---------------------------------------------------------------------------
.data
numColors       BYTE 7, 9, 2, 12, 1, 4, 3, 15, 8      ; colours for digits 0..8
.code

; ---------------------------------------------------------------------------
; GetCursorIndex: returns EAX = cursorRow * boardW + cursorCol
; ---------------------------------------------------------------------------
GetCursorIndex PROC
    mov eax, cursorRow
    imul eax, boardW
    add eax, cursorCol
    ret
GetCursorIndex ENDP

; ---------------------------------------------------------------------------
; DrawCell: EAX = cell index. Draws one cell (2 characters wide).
;   Hidden = #   Flag = F   Number = coloured digit   Blank = space
;   After the game: mines = *   exploded mine = red *   wrong flag = X
;   The cell under the cursor gets a yellow background.
; ---------------------------------------------------------------------------
DrawCell PROC
    pushad
    mov esi, eax                ; ESI = cell index

    ; --- is the cursor on this cell? (EDI = 1 if yes) ---
    mov edi, 0
    call GetCursorIndex
    cmp eax, esi
    jne notCursorCell
    mov edi, 1
notCursorCell:

    ; --- work out the screen position ---
    mov eax, esi
    xor edx, edx
    div boardW                  ; EAX = row, EDX = column
    add eax, BOARD_Y            ; screen row
    shl edx, 1                  ; each cell is 2 characters wide
    add edx, BOARD_X            ; screen column
    mov dh, al                  ; DH = row, DL = column
    call Gotoxy

    ; --- choose the character (AL) and colour (BL) ---
    movzx ecx, BYTE PTR board[esi]      ; CL = cell state bits
    mov al, '#'
    mov bl, 7
    cmp gameOver, 0
    je normalView

    ; game is over: show the mines
    test cl, CELL_MINE
    jz wrongFlagCheck
    test cl, CELL_FLAG
    jnz drawFlag                ; correctly flagged mine
    cmp gameWon, 0
    jne drawFlag                ; on a win, show all mines as flags
    test cl, CELL_REVEALED
    jnz exploded                ; the mine that was selected
    mov al, '*'
    mov bl, 12
    jmp drawIt
exploded:
    mov al, '*'
    mov bl, EXPLODE_COLOR
    jmp drawIt
wrongFlagCheck:
    test cl, CELL_FLAG
    jz normalView
    mov al, 'X'                 ; flag on a safe tile
    mov bl, 14
    jmp drawIt

normalView:
    test cl, CELL_FLAG
    jnz drawFlag
    test cl, CELL_REVEALED
    jz drawIt                   ; hidden tile stays '#'
    movzx edx, BYTE PTR counts[esi]
    cmp edx, 0
    je blankCell
    mov al, dl
    add al, '0'                 ; digit character
    mov bl, numColors[edx]
    jmp drawIt
blankCell:
    mov al, ' '
    jmp drawIt
drawFlag:
    mov al, 'F'
    mov bl, 12

drawIt:
    cmp edi, 1
    jne applyColour
    mov bl, CURSOR_COLOR        ; cursor overrides the colour
applyColour:
    mov dl, al                  ; keep the character
    movzx eax, bl
    call SetTextColor
    mov al, dl
    call WriteChar
    mov al, ' '
    call WriteChar
    SetColor 7                  ; do not leave the highlight colour active
    popad
    ret
DrawCell ENDP

RANA_D1_DONE = 1      ; this day's code exists, so its stubs are skipped

; ---------------------------------------------------------------------------
;  RANA MUHAMMAD HUSSAIN - DAY 2  (DrawBoard, MoveCursor)
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; DrawBoard: draws every cell
; ---------------------------------------------------------------------------
DrawBoard PROC
    pushad
    mov esi, 0
boardLoop:
    cmp esi, boardSize
    jae boardDrawn
    mov eax, esi
    call DrawCell
    inc esi
    jmp boardLoop
boardDrawn:
    popad
    ret
DrawBoard ENDP

; ---------------------------------------------------------------------------
; MoveCursor: EAX = row change, EBX = column change (each -1, 0 or +1).
;             Ignores moves that would leave the board.
; ---------------------------------------------------------------------------
MoveCursor PROC
    pushad
    add eax, cursorRow
    js moveDone                 ; went above the board
    cmp eax, boardH
    jge moveDone                ; went below the board
    add ebx, cursorCol
    js moveDone                 ; went left of the board
    cmp ebx, boardW
    jge moveDone                ; went right of the board
    mov esi, eax                ; ESI = new row
    mov edi, ebx                ; EDI = new column

    call GetCursorIndex         ; old cursor cell
    push eax
    mov cursorRow, esi
    mov cursorCol, edi
    pop eax
    call DrawCell               ; redraw old cell (no longer highlighted)
    call GetCursorIndex
    call DrawCell               ; draw new cell (highlighted)
moveDone:
    popad
    ret
MoveCursor ENDP

RANA_D2_DONE = 1      ; this day's code exists, so its stubs are skipped

; ---------------------------------------------------------------------------
;  RANA MUHAMMAD HUSSAIN - DAY 3  (DrawStatus, WriteBest)
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; DrawStatus: draws mines left, time and best time (numbers only)
; ---------------------------------------------------------------------------
DrawStatus PROC
    pushad
    GotoRC 1, 7
    SetColor 15
    mov eax, mineCount
    sub eax, flagsPlaced        ; mines left = mines - flags placed
    call WriteDec
    mov edx, OFFSET strPad
    call WriteString

    GotoRC 1, 20
    SetColor 15
    mov eax, elapsedSec
    call WriteDec
    mov edx, OFFSET strPad
    call WriteString

    GotoRC 1, 34
    SetColor 15
    mov ebx, difficulty
    mov eax, bestTimes[ebx*4]
    call WriteBest
    mov edx, OFFSET strPad
    call WriteString
    popad
    ret
DrawStatus ENDP

; ---------------------------------------------------------------------------
; WriteBest: prints the time in EAX as "N s", or "--" if EAX is 0
; ---------------------------------------------------------------------------
WriteBest PROC
    cmp eax, 0
    jne hasRecord
    mov edx, OFFSET strNone
    call WriteString
    ret
hasRecord:
    call WriteDec
    mov edx, OFFSET strSecUnit
    call WriteString
    ret
WriteBest ENDP

RANA_D3_DONE = 1      ; this day's code exists, so its stubs are skipped

; ---------------------------------------------------------------------------
;  RANA MUHAMMAD HUSSAIN - DAY 4  (UpdateTimer, DrawGameScreen)
; ---------------------------------------------------------------------------
.data
strGameTitle    BYTE "MINESWEEPER - ",0
lblMines        BYTE "Mines:",0
lblTime         BYTE "Time:",0
lblBest         BYTE "Best:",0
strControls     BYTE "Arrows:Move  Enter:Open  F:Flag  C:Chord  Esc:Menu",0
.code

; ---------------------------------------------------------------------------
; UpdateTimer: recalculates elapsed seconds and redraws if the second changed
; ---------------------------------------------------------------------------
UpdateTimer PROC
    pushad
    cmp timerRunning, 0
    je timerDone
    cmp gameOver, 0
    jne timerDone
    call GetMseconds            ; milliseconds since midnight
    sub eax, startTime
    xor edx, edx
    mov ecx, 1000
    div ecx                     ; EAX = whole seconds
    cmp eax, elapsedSec
    je timerDone                ; same second, nothing to redraw
    mov elapsedSec, eax
    call DrawStatus
timerDone:
    popad
    ret
UpdateTimer ENDP

; ---------------------------------------------------------------------------
; DrawGameScreen: draws the title, labels, controls, numbers and the board
; ---------------------------------------------------------------------------
DrawGameScreen PROC
    pushad
    call ClearScreen
    GotoRC 0, 0
    ShowText strGameTitle, 14
    mov eax, difficulty
    mov edx, diffNames[eax*4]
    call WriteString
    GotoRC 1, 0
    ShowText lblMines, 11
    GotoRC 1, 14
    ShowText lblTime, 11
    GotoRC 1, 28
    ShowText lblBest, 11
    GotoRC 2, 0
    ShowText strControls, 7
    call DrawStatus
    call DrawBoard
    popad
    ret
DrawGameScreen ENDP

RANA_D4_DONE = 1      ; this day's code exists, so its stubs are skipped

; >>>>>>>>>>>>>>>>>>>>  RANA ZONE END  <<<<<<<<<<<<<<<<<<<<<<

; ----------------------------------------------------------------------------
; (end of zone - shared base code continues below)
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------

; ============================================================================
;  STUBS  -  placeholder procedures for code that has not been written yet
;  A stub is assembled ONLY while its day's flag is still 0. Once a member's
;  day file sets its flag to 1, the stub disappears and the real code is used.
;  (Nobody edits this section.)
; ============================================================================

IF ROHAAN_D1_DONE EQ 0
SetDifficulty PROC
    ret
SetDifficulty ENDP
InitGame PROC
    ret
InitGame ENDP
ENDIF

IF ROHAAN_D2_DONE EQ 0
PlaceMines PROC
    ret
PlaceMines ENDP
RelocateMine PROC
    ret
RelocateMine ENDP
ENDIF

IF ROHAAN_D3_DONE EQ 0
GetNeighbours PROC
    ret
GetNeighbours ENDP
CalcCounts PROC
    ret
CalcCounts ENDP
ENDIF

IF ROHAAN_D4_DONE EQ 0
RevealCell PROC
    ret
RevealCell ENDP
RevealArea PROC
    ret
RevealArea ENDP
ENDIF

IF ROHAAN_D5_DONE EQ 0
Cascade PROC
    ret
Cascade ENDP
SelectCell PROC
    ret
SelectCell ENDP
ENDIF

IF ROHAAN_D6_DONE EQ 0
ChordCell PROC
    ret
ChordCell ENDP
ENDIF

IF SARIM_D1_DONE EQ 0
MainMenu PROC
    ; temporary: start an Easy game directly until the real menu exists
    mov difficulty, 0
    call PlayGame
    ret
MainMenu ENDP
ENDIF

IF SARIM_D2_DONE EQ 0
DifficultyMenu PROC
    ret
DifficultyMenu ENDP
ENDIF

IF SARIM_D3_DONE EQ 0
ShowHowToPlay PROC
    ret
ShowHowToPlay ENDP
ENDIF

IF SARIM_D4_DONE EQ 0
ShowBestTimes PROC
    ret
ShowBestTimes ENDP
ENDIF

IF SARIM_D5_DONE EQ 0
ToggleFlag PROC
    ret
ToggleFlag ENDP
ShowEndMessage PROC
    ret
ShowEndMessage ENDP
ENDIF

IF SARIM_D6_DONE EQ 0
CheckWin PROC
    ret
CheckWin ENDP
ENDIF

IF RANA_D1_DONE EQ 0
GetCursorIndex PROC
    ret
GetCursorIndex ENDP
DrawCell PROC
    ret
DrawCell ENDP
ENDIF

IF RANA_D2_DONE EQ 0
DrawBoard PROC
    ret
DrawBoard ENDP
MoveCursor PROC
    ret
MoveCursor ENDP
ENDIF

IF RANA_D3_DONE EQ 0
DrawStatus PROC
    ret
DrawStatus ENDP
WriteBest PROC
    ret
WriteBest ENDP
ENDIF

IF RANA_D4_DONE EQ 0
UpdateTimer PROC
    ret
UpdateTimer ENDP
DrawGameScreen PROC
    ret
DrawGameScreen ENDP
ENDIF

IF RANA_D5_DONE EQ 0
LoadBestTimes PROC
    ret
LoadBestTimes ENDP
SaveBestTimes PROC
    ret
SaveBestTimes ENDP
ENDIF

IF RANA_D6_DONE EQ 0
RefreshScreen PROC
    ret
RefreshScreen ENDP
ENDIF


; ============================================================================
;  MAIN PROGRAM
; ============================================================================
main PROC
    call Randomize              ; seed the random number generator
    call LoadBestTimes          ; read saved best times (if file exists)
    call MainMenu               ; run the menu until the player exits
    exit
main ENDP

; ============================================================================
;  UTILITY
; ============================================================================

; ---------------------------------------------------------------------------
; ClearScreen: resets colour to normal, then clears the console
; ---------------------------------------------------------------------------
ClearScreen PROC
    SetColor 7
    call Clrscr
    ret
ClearScreen ENDP

; ============================================================================
;  GAME LOOP (connects all the modules together)
; ============================================================================

; ---------------------------------------------------------------------------
; PlayGame: runs one complete game of the chosen difficulty
; ---------------------------------------------------------------------------
PlayGame PROC
    call InitGame
    call DrawGameScreen

gameLoop:
    mov eax, 30
    call Delay                  ; short pause so the CPU is not busy all the time
    call UpdateTimer            ; keep the timer running
    call ReadKey                ; no key pressed -> ZF = 1
    jz gameLoop                 ; DX = virtual key code when a key was pressed

    cmp dx, KEY_ESC
    je leaveGame                ; Esc always returns to the menu
    cmp gameOver, 0
    je playing
    cmp dx, KEY_ENTER           ; after the game ends, Enter also leaves
    je leaveGame
    jmp gameLoop

playing:
    cmp dx, KEY_UP
    jne notUp
    mov eax, -1
    mov ebx, 0
    call MoveCursor
    jmp gameLoop
notUp:
    cmp dx, KEY_DOWN
    jne notDown
    mov eax, 1
    mov ebx, 0
    call MoveCursor
    jmp gameLoop
notDown:
    cmp dx, KEY_LEFT
    jne notLeft
    mov eax, 0
    mov ebx, -1
    call MoveCursor
    jmp gameLoop
notLeft:
    cmp dx, KEY_RIGHT
    jne notRight
    mov eax, 0
    mov ebx, 1
    call MoveCursor
    jmp gameLoop
notRight:
    cmp dx, KEY_ENTER
    jne notEnter
    call SelectCell
    call RefreshScreen
    jmp gameLoop
notEnter:
    cmp dx, KEY_F
    jne notFlagKey
    call ToggleFlag
    jmp gameLoop
notFlagKey:
    cmp dx, KEY_C
    jne gameLoop
    call ChordCell
    call RefreshScreen
    jmp gameLoop

leaveGame:
    ret
PlayGame ENDP

END main
