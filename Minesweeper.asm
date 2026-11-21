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

; ---------------------------------------------------------------------------
;  SARIM RAZA ANSARI - DAY 1  (MainMenu)
; ---------------------------------------------------------------------------
.data
strMenuTitle    BYTE "      M I N E S W E E P E R",0
strMenuLine     BYTE "  ===============================",0
strMenu1        BYTE "    1. New Game",0
strMenu2        BYTE "    2. Best Times",0
strMenu3        BYTE "    3. How to Play",0
strMenu4        BYTE "    4. Exit",0
.code

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

SARIM_D1_DONE = 1      ; this day's code exists, so its stubs are skipped

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
