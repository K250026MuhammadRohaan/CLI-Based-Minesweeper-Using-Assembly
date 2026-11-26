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
;   - CASCADE: any revealed blank tile (0 mines nearby) automatically opens
;     its neighbours, and this repeats until no more blank tiles can spread.
;   - Best time of each difficulty is saved in "besttime.dat".
;
;  Controls: Arrow keys = move | Enter = select | F = flag
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

; --- Colours used for drawing ---
CURSOR_COLOR    EQU 0E0h        ; black text on yellow background

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
;  DATA SECTION
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
passStart       DWORD 0         ; used by Cascade

; ----- Neighbour list filled by GetNeighbours -----
nbrCount        DWORD 0
nbrList         DWORD 8 DUP(0)

; ----- Number colours for 0..8 -----
;   0 = unused, 1 = light green, 2 = light yellow, 3 = dark yellow,
;   4 = light red, 5 = blue, 6 = blue, 7 = magenta, 8 = magenta
numColors       BYTE 7, 10, 14, 12, 9, 1, 1, 5, 5

; ----- Best-time file -----
fileName        BYTE "besttime.dat",0
fileHandle      DWORD 0
bestTimes       DWORD 3 DUP(0)  ; best seconds for Easy, Medium, Hard (0 = none)

; ----- Text strings -----
strEasy         BYTE "EASY",0
strMedium       BYTE "MEDIUM",0
strHard         BYTE "HARD",0

strMenuTitle    BYTE "      M I N E S W E E P E R",0
strMenuLine     BYTE "  ===============================",0
strMenu1        BYTE "    1. New Game",0
strMenu2        BYTE "    2. Best Times",0
strMenu3        BYTE "    3. How to Play",0
strMenu4        BYTE "    4. Exit",0

strChoose       BYTE "  Choose a difficulty:",0
strOptEasy      BYTE "    1. Easy   (9 x 9,   10 mines)",0
strOptMedium    BYTE "    2. Medium (16 x 16, 40 mines)",0
strOptHard      BYTE "    3. Hard   (30 x 16, 99 mines)",0
strEscBack      BYTE "    Esc. Back",0

strGameTitle    BYTE "MINESWEEPER - ",0
lblMines        BYTE "Mines:",0
lblTime         BYTE "Time:",0
lblBest         BYTE "Best:",0
strControls     BYTE "Arrows:Move  Enter:Open  F:Flag  Esc:Menu",0
strPad          BYTE "    ",0
strNone         BYTE "--",0
strSecUnit      BYTE " s",0

strWin          BYTE "YOU WIN!  Time: ",0
strLose         BYTE "GAME OVER!  You selected a mine.",0
strRecord       BYTE "   NEW BEST TIME!",0
strReturn       BYTE "Press Enter or Esc to return to the menu.",0

strBestTitle    BYTE "BEST TIMES",0
strBestEasy     BYTE "  Easy   : ",0
strBestMedium   BYTE "  Medium : ",0
strBestHard     BYTE "  Hard   : ",0
strAnyKey       BYTE "  Press any key to go back...",0

strHelpTitle    BYTE "HOW TO PLAY",0
strHelp1        BYTE "  Goal: open every safe tile without selecting a mine.",0
strHelp2        BYTE "  Enter : select a tile. The tile and the 8 tiles around it",0
strHelp3        BYTE "          are opened (3x3 area). Mines in that area stay hidden.",0
strHelp4        BYTE "          You lose only if the tile you select is a mine.",0
strHelp5        BYTE "  Arrows: move the cursor.",0
strHelp6        BYTE "  F     : put or remove a flag on a suspected mine.",0
strHelp9        BYTE "  Cascade: blank tiles automatically open their neighbours.",0
strHelp10       BYTE "  Numbers tell how many mines touch that tile.",0
strHelp11       BYTE "  Your best time for each difficulty is saved in a file.",0
strHelp12       BYTE "  Esc   : go back to the menu.",0

; ============================================================================
;  CODE SECTION
; ============================================================================
.code

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
;  MODULE 1: MAIN MENU AND SCREENS
; ============================================================================

; ---------------------------------------------------------------------------
; ClearScreen: resets colour to normal, then clears the console
; ---------------------------------------------------------------------------
ClearScreen PROC
    SetColor 7
    call Clrscr
    ret
ClearScreen ENDP

; ---------------------------------------------------------------------------
; MainMenu: shows the menu and handles the choices 1-4
; ---------------------------------------------------------------------------
MainMenu PROC
menuTop:
    call ClearScreen
    GotoRC 2, 0
    ShowText strMenuLine, 11
    call Crlf
    ShowText strMenuTitle, 14
    call Crlf
    ShowText strMenuLine, 11
    call Crlf
    call Crlf
    ShowText strMenu1, 10
    call Crlf
    ShowText strMenu2, 10
    call Crlf
    ShowText strMenu3, 10
    call Crlf
    ShowText strMenu4, 12
    call Crlf

    call ReadChar               ; wait for a key, result in AL
    cmp al, '1'
    je chooseNew
    cmp al, '2'
    je chooseBest
    cmp al, '3'
    je chooseHelp
    cmp al, '4'
    je menuExit
    jmp menuTop

chooseNew:
    call DifficultyMenu
    jmp menuTop
chooseBest:
    call ShowBestTimes
    jmp menuTop
chooseHelp:
    call ShowHowToPlay
    jmp menuTop
menuExit:
    call ClearScreen
    ret
MainMenu ENDP

; ---------------------------------------------------------------------------
; DifficultyMenu: lets the player pick Easy / Medium / Hard, then plays
; ---------------------------------------------------------------------------
DifficultyMenu PROC
    call ClearScreen
    GotoRC 3, 0
    ShowText strChoose, 11
    call Crlf
    call Crlf
    ShowText strOptEasy, 10
    call Crlf
    ShowText strOptMedium, 14
    call Crlf
    ShowText strOptHard, 12
    call Crlf
    ShowText strEscBack, 7
    call Crlf

readDiff:
    call ReadChar
    cmp al, '1'
    je pickEasy
    cmp al, '2'
    je pickMedium
    cmp al, '3'
    je pickHard
    cmp al, 27                  ; Esc key
    je diffBack
    jmp readDiff

pickEasy:
    mov difficulty, 0
    jmp startIt
pickMedium:
    mov difficulty, 1
    jmp startIt
pickHard:
    mov difficulty, 2
startIt:
    call PlayGame
diffBack:
    ret
DifficultyMenu ENDP

; ---------------------------------------------------------------------------
; ShowBestTimes: prints the saved best time of each difficulty
; ---------------------------------------------------------------------------
ShowBestTimes PROC
    call ClearScreen
    GotoRC 2, 2
    ShowText strBestTitle, 14
    call Crlf
    call Crlf
    ShowText strBestEasy, 10
    mov eax, bestTimes[0]
    call WriteBest
    call Crlf
    ShowText strBestMedium, 14
    mov eax, bestTimes[4]
    call WriteBest
    call Crlf
    ShowText strBestHard, 12
    mov eax, bestTimes[8]
    call WriteBest
    call Crlf
    call Crlf
    ShowText strAnyKey, 7
    call ReadChar
    ret
ShowBestTimes ENDP

; ---------------------------------------------------------------------------
; ShowHowToPlay: prints the instructions screen
; ---------------------------------------------------------------------------
ShowHowToPlay PROC
    call ClearScreen
    GotoRC 1, 2
    ShowText strHelpTitle, 14
    call Crlf
    call Crlf
    ShowText strHelp1, 15
    call Crlf
    call Crlf
    ShowText strHelp2, 11
    call Crlf
    ShowText strHelp3, 11
    call Crlf
    ShowText strHelp4, 11
    call Crlf
    call Crlf
    ShowText strHelp5, 15
    call Crlf
    call Crlf
    ShowText strHelp6, 15
    call Crlf
    call Crlf
    ShowText strHelp9, 10
    call Crlf
    call Crlf
    ShowText strHelp10, 15
    call Crlf
    call Crlf
    ShowText strHelp11, 15
    call Crlf
    call Crlf
    ShowText strHelp12, 15
    call Crlf
    call Crlf
    ShowText strAnyKey, 7
    call ReadChar
    ret
ShowHowToPlay ENDP

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

; ============================================================================
;  MODULE 2: BOARD SETUP AND MINE PLACEMENT
; ============================================================================

; ---------------------------------------------------------------------------
; SetDifficulty: copies width, height and mines for the chosen difficulty
; ---------------------------------------------------------------------------
SetDifficulty PROC
    pushad
    mov eax, difficulty
    mov ebx, widthTable[eax*4]
    mov boardW, ebx
    mov ecx, heightTable[eax*4]
    mov boardH, ecx
    imul ebx, ecx               ; boardSize = width * height
    mov boardSize, ebx
    mov ebx, mineTable[eax*4]
    mov mineCount, ebx
    popad
    ret
SetDifficulty ENDP

; ---------------------------------------------------------------------------
; InitGame: prepares a fresh game (clears arrays, resets state, places mines)
; ---------------------------------------------------------------------------
InitGame PROC
    pushad
    call SetDifficulty

    ; clear both arrays
    mov esi, 0
    mov ecx, MAX_CELLS
clearLoop:
    mov board[esi], 0
    mov counts[esi], 0
    inc esi
    loop clearLoop

    ; reset the game state
    mov flagsPlaced, 0
    mov revealedCount, 0
    mov gameOver, 0
    mov gameWon, 0
    mov firstMove, 1
    mov timerRunning, 0
    mov startTime, 0
    mov elapsedSec, 0
    mov newRecord, 0

    ; put the cursor in the middle of the board
    mov eax, boardH
    shr eax, 1
    mov cursorRow, eax
    mov eax, boardW
    shr eax, 1
    mov cursorCol, eax

    call PlaceMines
    call CalcCounts
    popad
    ret
InitGame ENDP

; ---------------------------------------------------------------------------
; PlaceMines: puts mineCount mines on random, different cells
; ---------------------------------------------------------------------------
PlaceMines PROC
    pushad
    mov ecx, mineCount
placeLoop:
    mov eax, boardSize
    call RandomRange            ; EAX = random index 0..boardSize-1
    test BYTE PTR board[eax], CELL_MINE
    jnz placeLoop               ; already a mine here, pick again
    or BYTE PTR board[eax], CELL_MINE
    loop placeLoop
    popad
    ret
PlaceMines ENDP

; ============================================================================
;  MODULE 3: NEIGHBOUR COUNTING
; ============================================================================

; ---------------------------------------------------------------------------
; GetNeighbours: EAX = cell index.
;   Fills nbrList with the indexes of all valid neighbours (edges handled)
;   and nbrCount with how many there are (3 to 8).
; ---------------------------------------------------------------------------
GetNeighbours PROC
    pushad
    mov nbrCount, 0
    xor edx, edx
    div boardW                  ; EAX = row, EDX = column
    mov esi, eax                ; ESI = row of the centre cell
    mov edi, edx                ; EDI = column of the centre cell

    mov ebx, -1                 ; EBX = row offset  (-1, 0, +1)
rowStep:
    mov ecx, -1                 ; ECX = column offset (-1, 0, +1)
colStep:
    mov eax, ebx
    or eax, ecx
    jz nextCol                  ; offset (0,0) is the cell itself, skip it

    mov eax, esi
    add eax, ebx                ; EAX = neighbour row
    cmp eax, 0
    jl nextCol                  ; above the board
    cmp eax, boardH
    jge nextCol                 ; below the board

    mov edx, edi
    add edx, ecx                ; EDX = neighbour column
    cmp edx, 0
    jl nextCol                  ; left of the board
    cmp edx, boardW
    jge nextCol                 ; right of the board

    imul eax, boardW            ; index = row * width + column
    add eax, edx
    mov edx, nbrCount
    mov nbrList[edx*4], eax     ; store the neighbour index
    inc nbrCount
nextCol:
    inc ecx
    cmp ecx, 1
    jle colStep
    inc ebx
    cmp ebx, 1
    jle rowStep
    popad
    ret
GetNeighbours ENDP

; ---------------------------------------------------------------------------
; CalcCounts: fills the counts array (mines around every cell)
; ---------------------------------------------------------------------------
CalcCounts PROC
    pushad
    mov esi, 0                  ; ESI = current cell
cellLoop:
    cmp esi, boardSize
    jae countsDone
    mov eax, esi
    call GetNeighbours
    mov ecx, nbrCount
    mov edi, 0                  ; EDI = position in nbrList
    mov ebx, 0                  ; EBX = mines found
neighbourLoop:
    mov eax, nbrList[edi*4]
    test BYTE PTR board[eax], CELL_MINE
    jz notAMine
    inc ebx
notAMine:
    inc edi
    loop neighbourLoop
    mov counts[esi], bl
    inc esi
    jmp cellLoop
countsDone:
    popad
    ret
CalcCounts ENDP

; ============================================================================
;  MODULE 4: DISPLAY AND CURSOR
; ============================================================================

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
; DrawCell: EAX = cell index. Draws one cell (2 characters wide).
;   Hidden = #   Flag = F   Number = coloured digit   Blank = space
;   After a win: mines are shown as flags. On a loss: all mines are shown as *.
;   Wrong flags remain F. The cell under the cursor gets a yellow background.
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
    cmp gameWon, 0
    jne checkWonMine            ; winning screen
    test cl, CELL_MINE
    jz normalView               ; safe cells keep their normal appearance
    mov al, '*'
    mov bl, 12                  ; reveal every mine, even if it was flagged
    jmp drawIt

checkWonMine:
    test cl, CELL_MINE
    jz normalView
    jmp drawFlag                ; on a win, show mines as flags

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
    mov bl, 13                  ; flag colour: light magenta (purple/pink)

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

; ============================================================================
;  MODULE 5: SELECTING TILES, 3x3 REVEAL AND CASCADE
; ============================================================================

; ---------------------------------------------------------------------------
; RevealCell: EAX = cell index. Opens the cell only if it is hidden,
;             not flagged and not a mine.
; ---------------------------------------------------------------------------
RevealCell PROC
    pushad
    test BYTE PTR board[eax], CELL_FLAG OR CELL_REVEALED OR CELL_MINE
    jnz revealSkip
    or BYTE PTR board[eax], CELL_REVEALED
    inc revealedCount
revealSkip:
    popad
    ret
RevealCell ENDP

; ---------------------------------------------------------------------------
; RevealArea: EAX = cell index. Opens that cell and its 8 neighbours
;             (the 3x3 area). Mines in the area stay hidden.
; ---------------------------------------------------------------------------
RevealArea PROC
    pushad
    mov esi, eax
    call RevealCell             ; the centre cell (EAX = index)
    mov eax, esi
    call GetNeighbours
    mov ecx, nbrCount
    mov edi, 0
areaLoop:
    mov eax, nbrList[edi*4]
    call RevealCell
    inc edi
    loop areaLoop
    popad
    ret
RevealArea ENDP

; ---------------------------------------------------------------------------
; Cascade: every revealed blank cell (0 mines nearby) opens its neighbours.
;          The board is scanned again and again until nothing new opens.
; ---------------------------------------------------------------------------
Cascade PROC
    pushad
cascadeAgain:
    mov eax, revealedCount
    mov passStart, eax          ; remember how many were open before this pass
    mov esi, 0
cascadeScan:
    cmp esi, boardSize
    jae cascadePassEnd
    test BYTE PTR board[esi], CELL_REVEALED
    jz cascadeNext              ; skip hidden cells
    cmp BYTE PTR counts[esi], 0
    jne cascadeNext             ; skip cells that show a number
    mov eax, esi                ; revealed blank cell: open its neighbours
    call GetNeighbours
    mov ecx, nbrCount
    mov edi, 0
cascadeOpen:
    mov eax, nbrList[edi*4]
    call RevealCell
    inc edi
    loop cascadeOpen
cascadeNext:
    inc esi
    jmp cascadeScan
cascadePassEnd:
    mov eax, revealedCount
    cmp eax, passStart
    jne cascadeAgain            ; something new opened, scan once more
    popad
    ret
Cascade ENDP

; ---------------------------------------------------------------------------
; SelectCell: Enter key. Handles the first move, mine hit, 3x3 reveal,
;             cascade and win check for the cell under the cursor.
; ---------------------------------------------------------------------------
SelectCell PROC
    pushad
    call GetCursorIndex
    mov esi, eax
    test BYTE PTR board[esi], CELL_FLAG OR CELL_REVEALED
    jnz selDone                 ; flagged or already open: do nothing

    cmp firstMove, 0
    je selNotFirst
    mov firstMove, 0            ; this is the first selection
    mov timerRunning, 1
    call GetMseconds
    mov startTime, eax          ; the timer starts now
    call GetCursorIndex
    mov esi, eax

selNotFirst:
    test BYTE PTR board[esi], CELL_MINE
    jnz selHitMine
    mov eax, esi
    call RevealArea             ; open the 3x3 area
    call Cascade                ; spread through blank tiles
    call CheckWin
    jmp selDone

selHitMine:
    mov gameOver, 1             ; keep the selected mine hidden
selDone:
    popad
    ret
SelectCell ENDP

; ============================================================================
;  MODULE 6: FLAGS, MINE COUNTER AND TIMER
; ============================================================================

; ---------------------------------------------------------------------------
; ToggleFlag: F key. Puts or removes a flag on the hidden cell under the cursor
; ---------------------------------------------------------------------------
ToggleFlag PROC
    pushad
    call GetCursorIndex
    mov esi, eax
    test BYTE PTR board[esi], CELL_REVEALED
    jnz flagDone                ; cannot flag an opened tile
    test BYTE PTR board[esi], CELL_FLAG
    jnz removeFlag
    mov eax, flagsPlaced
    cmp eax, mineCount
    jae flagDone                ; no more flags than mines
    or BYTE PTR board[esi], CELL_FLAG
    inc flagsPlaced
    jmp flagRedraw
removeFlag:
    xor BYTE PTR board[esi], CELL_FLAG
    dec flagsPlaced
flagRedraw:
    mov eax, esi
    call DrawCell
    call DrawStatus
flagDone:
    popad
    ret
ToggleFlag ENDP

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

; ============================================================================
;  MODULE 7: WIN AND LOSE LOGIC
; ============================================================================

; ---------------------------------------------------------------------------
; CheckWin: the player wins when all safe tiles are open.
;           Also saves the best time if it is a new record.
; ---------------------------------------------------------------------------
CheckWin PROC
    pushad
    mov eax, boardSize
    sub eax, mineCount          ; number of safe tiles
    cmp revealedCount, eax
    jne winDone

    mov gameOver, 1
    mov gameWon, 1
    mov timerRunning, 0
    mov eax, mineCount
    mov flagsPlaced, eax        ; all mines count as flagged

    call GetMseconds            ; final time in seconds
    sub eax, startTime
    xor edx, edx
    mov ecx, 1000
    div ecx
    cmp eax, 0
    jne timeOk
    mov eax, 1                  ; never store 0 (0 means "no record")
timeOk:
    mov elapsedSec, eax

    ; compare with the saved best time of this difficulty
    mov ebx, difficulty
    mov ecx, bestTimes[ebx*4]
    cmp ecx, 0
    je isRecord                 ; no record yet
    cmp eax, ecx
    jae winDone                 ; not faster than the record
isRecord:
    mov bestTimes[ebx*4], eax
    mov newRecord, 1
    call SaveBestTimes
winDone:
    popad
    ret
CheckWin ENDP

; ---------------------------------------------------------------------------
; ShowEndMessage: prints the win or lose message under the controls line
; ---------------------------------------------------------------------------
ShowEndMessage PROC
    pushad
    GotoRC 3, 0
    cmp gameWon, 0
    jne showWin
    ShowText strLose, 12
    jmp showPrompt
showWin:
    ShowText strWin, 10
    mov eax, elapsedSec
    call WriteDec
    ShowText strSecUnit, 10
    cmp newRecord, 0
    je showPrompt
    ShowText strRecord, 14
showPrompt:
    GotoRC 4, 0
    ShowText strReturn, 7
    popad
    ret
ShowEndMessage ENDP

; ---------------------------------------------------------------------------
; RefreshScreen: redraws board and numbers, and shows the end message if done
; ---------------------------------------------------------------------------
RefreshScreen PROC
    pushad
    call DrawBoard
    call DrawStatus
    cmp gameOver, 0
    je refreshDone
    call ShowEndMessage
refreshDone:
    popad
    ret
RefreshScreen ENDP

; ============================================================================
;  MODULE 8: BEST-TIME FILE
; ============================================================================

; ---------------------------------------------------------------------------
; LoadBestTimes: reads the 3 saved times from the file (if it exists)
; ---------------------------------------------------------------------------
LoadBestTimes PROC
    pushad
    mov edx, OFFSET fileName
    call OpenInputFile          ; EAX = file handle
    cmp eax, INVALID_HANDLE_VALUE
    je loadDone                 ; no file yet, keep zeros
    mov fileHandle, eax
    mov edx, OFFSET bestTimes
    mov ecx, 12                 ; 3 DWORDs = 12 bytes
    call ReadFromFile
    mov eax, fileHandle
    call CloseFile
loadDone:
    popad
    ret
LoadBestTimes ENDP

; ---------------------------------------------------------------------------
; SaveBestTimes: writes the 3 best times to the file
; ---------------------------------------------------------------------------
SaveBestTimes PROC
    pushad
    mov edx, OFFSET fileName
    call CreateOutputFile       ; EAX = file handle
    cmp eax, INVALID_HANDLE_VALUE
    je saveDone
    mov fileHandle, eax
    mov edx, OFFSET bestTimes
    mov ecx, 12
    call WriteToFile
    mov eax, fileHandle
    call CloseFile
saveDone:
    popad
    ret
SaveBestTimes ENDP

; ============================================================================
;  GAME LOOP
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
    jne gameLoop
    call ToggleFlag
    jmp gameLoop

leaveGame:
    ret
PlayGame ENDP

END main
