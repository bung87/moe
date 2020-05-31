const helpSentences = """
# Exiting
Check command bar

:w    - Write file
:q    - Quit
:wq   - Write file and quit
:q!   - Force quit
:qa   - Quit all window
:wqa  - Write and quit all window
:qa!  - Force quit all window

# Normal mode

h - move left
j or + - move down
k or - - move up
l - move right
w - Move forwards to the start of a word
e - Move forwards to the end of a word
b - Move backwards to the start of a word
Page Up - Page up
Page Down - Page down
gg - Move to the first line
g_ - Move to the last non-blank character of the line
G - Move to the last line
0 - (zero) First of the line
$ - End of the line
^ or _ - Move to beginning of non-blank characters in a line

Ctrl-u - Half page down  
Ctrl-d - Half page up  

u - Undo
Ctrl-r - Redo

v - Start visual mode
Ctrl-v Start visual block mode
r - Start replace mode
i - Start insert mode
o - Insert a new line and start insert mode
a - Append after the cursor and start insert mode
r - Replace a character at the cursor
A - Same as $a
I - Same as 0a

> - Indent
< - Unindent

dd - Delete(cut) a line
d$ or D - Delete the characters under the cursor until the end of the line

x - Delete(cut) current character

S or cc - Delete the characters in current line and start insert mode

yy - Copy a line
p - Paste the clipboard

n - Repeat search in same direction
N - Repeat search in opposite direction

f - Jump to next occurrence
F - Jump to previous occurence

Ctrl-k - Move next window
Ctrl-j - Move prev window

z. - Center the screen on the cursor
zt - Scroll the screen so the cursor is at the top
zb - Scroll the screen so the cursor is at the bottom

ZZ - Write current file and exit
ZQ - Same as ":q!"

/ - Search text
: - Start ex mode

# Visual (block) mode
d or x - Delete(cut) text
y - Copy text
r - Replace character
J - Join lines
u - Convert string to lowercase
U - Convert string to uppercase

> - Indent
< - Unindent

Ctrl-a - Increas number under the cursor
Ctrl-x - Decreas number under the cursor

~ - Toggle case of the character under the cursor

Esc - Start normal mode

Esc - Start normal mode

D - Delete file  
g - Go to top of list  
G - Go to last of list  
i - Detail information  

number - Jump to line number : Exmaple :10  
! shell command - Shell command execution  

e filename - Open file  

/keyword - Search text, file or directory  

%s/keyword1/keyword2/ - Replace text (normal mode only)  

ls - Display all buffer  
bprev - Switch to the previous buffer  
bnext - Switch to the next buffer  
bfirst - Switch to the first buffer  
blast - Switch to the last buffer  
bd or bd number - Delete buffer  
buf - Open buffer manager  

vs - Vertical split window  
sv - Horizontal split window  

cws - Create new work space  
ws number - Change current work space : Example ws 2  
dws - Delete current work space  

livereload on or livereload on - Change setting of live reload of configuration file  
theme themeName - Change color theme : Example theme dark  
tab on or tab off - Change setting to tab line  
synatx on or syntax off - Change setting to syntax highlighting  
tabstop number - Change setting to tabStop : Exmaple tabstop 2  
paren on or paren off - Change setting to auto close paren  
indent on or indent off - Chnage sestting to auto indent  
linenum on or linenum off - Change setting to dispaly line number  
statusbar on or statusbar on - Change setting to display stattus bar  
realtimesearch on or realtimesearch off - Change setting to real-time search   
deleteparen on or deleteparen off - Change setting to auto delete paren  
smoothscroll on or smoothscroll off - Change setting to smooth scroll  
scrollspeed number - Set smooth scroll speed : Example scrollspeed 10  
highlightcurrentword on or highlightcurrentword off - Change setting to highlight other uses of the current word  
clipboard on or clipboard off - Change setting to system clipboard  
highlightfullspace on or highlightfullspace off - Change setting to highlight full width space  
buildonsave on or buildonsave off - Change setting to build on save
noh - Turn off highlights  

log - Open messages log viwer  
"""
