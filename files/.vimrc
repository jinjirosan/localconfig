"==============================================
" Jin's .vimrc 2018-2026
" version                   : 0.7.1
"
" plugin path (*NIX)        : /usr/share/vim/vim80/plugin           # airline
" plugin path (FBSD)        : /usr/local/share/vim/vim74/plugin     # airline
" colorscheme path (*NIX)   : /usr/share/vim/vim80/colors/          # badwolf
" colorscheme path (FBSD)   : /usr/local/share/vim/vim74/colors/    # badwolf
"
" Use Vim settings, rather then Vi settings
" This must be first as it changes other options as a side effect.
set nocompatible

" ================ Colorscheme ==================== {{{1
set t_Co=256
syntax enable

colorscheme badwolf
let g:badwolf_darkgutter = 1            " Make the gutters darker than the background.
let g:badwolf_css_props_highlight = 1   " Turn on CSS properties highlighting
let g:badwolf_tabline = 0               " Make the tab line darker than the background.

" ================ General Config ==================== {{{1

set number                       "Line numbers are good
set backspace=indent,eol,start   "Allow backspace in insert mode
set history=1000                 "Store lots of :cmdline history
set showcmd                      "Show incomplete cmds down the bottom
set showmode                     "Show current mode down the bottom
set gcr=a:blinkon0               "Disable cursor blink
set visualbell                   "No sounds
set autoread                     "Reload files changed outside vim

set tabstop=4                    "how many columns makes up a tab
set softtabstop=4                "when using the TB key, how many spaces to move
set expandtab                    "convert each tab to the number of space set in tabstop
set cursorline                   "highlight the entire line not only the cursor itself
filetype indent on               "use indentation scripts to set indent correctly for each language
set wildmenu                     "autocomplete commands and auto-tab-lookup bar

au BufWinLeave * mkview           "save the current state of folds in file
au BufWinEnter * silent loadview  "load the foldstate as previously close

set clipboard=unnamed,unnamedplus "Enable using system clipboard (doesn't seem to work well)

" ================ Search =========================== {{{1
set ignorecase                    "case-insensitive searches
set showmatch                     "highlight a / search string match
set incsearch                     "incremetnal searching plugin, highlight all matches while searching
set hlsearch                      "highligh all search matches permanently (until clear)

" ================ Moving Around =========================== {{{1
nnoremap <leader><space> :nohlsearch<CR>
nnoremap B ^                    " move cursor to beginning of line
nnoremap E $                    " move cursor to end of line

nnoremap $ <nop>                " Remove $
nnoremap ^ <nop>                " Remove ^

nnoremap <CR> :noh<CR><CR>      " Unsets last search pattern register by hitting ENTER

" ============ No indent on paste buffer ============ {{{1
set pastetoggle=<C-P>

" ================ Persistent Undo ================== {{{1
" Keep undo history across sessions, by storing in file.
" Only works all the time.
if has('persistent_undo') && isdirectory(expand('~').'/.vim/backups')
    silent !mkdir ~/.vim/backups > /dev/null 2>&1
    set undodir=~/.vim/backups
    set undofile
endif

" ================ Copy-Paste To OSX Clipboard =============== {{{1
"let @c = ':w !xsel -i -b'
"let @p = ':r !xsel -o -b'

" ================ folding ========================== {{{1
set foldenable
set foldlevelstart=10
set foldnestmax=10
nnoremap <space> za
set foldmethod=marker

" ================ Scrolling ======================== {{{1

set scrolloff=8         "Start scrolling 8 lines away from margins
set sidescrolloff=15    "The number of columns to keep left and right of the cursor
set sidescroll=1        "scroll one char at a time to the right when needed instead of jumping

" ========== copy without row numbers =============== {{{1
set mouse+=a

" ========== Testing stuff =============== {{{1
" vim: filetype=screen foldmethod=marker
