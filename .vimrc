"==============================================
" Jin's .vimrc 2018
" version                   : 0.4
"
" plugin path (*NIX)        : /usr/share/vim/vim80/plugin           # airline
" plugin path (FBSD)        : /usr/local/share/vim/vim74/plugin     # airline
" colorscheme path (*NIX)   : /usr/share/vim/vim80/colors/          # badwolf
" colorscheme path (FBSD)   : /usr/local/share/vim/vim74/colors/    # badwolf
"
" Use Vim settings, rather then Vi settings
" This must be first as it changes other options as a side effect.
set nocompatible

set t_Co=256
syntax enable
colorscheme badwolf
" Make the gutters darker than the background.
let g:badwolf_darkgutter = 1
" Turn on CSS properties highlighting
let g:badwolf_css_props_highlight = 1
" Make the tab line darker than the background.
let g:badwolf_tabline = 0

" ================ General Config ====================

set number                      "Line numbers are good
set backspace=indent,eol,start  "Allow backspace in insert mode
set history=1000                "Store lots of :cmdline history
set showcmd                     "Show incomplete cmds down the bottom
set showmode                    "Show current mode down the bottom
set gcr=a:blinkon0              "Disable cursor blink
set visualbell                  "No sounds
set autoread                    "Reload files changed outside vim

set tabstop=4
set softtabstop=4
set expandtab
set cursorline
filetype indent on
set wildmenu
set showmatch

set clipboard=unnamedplus

" ================ Search ===========================
set ignorecase
set incsearch
set hlsearch

nnoremap <leader><space> :nohlsearch<CR>
" move to beginning/end of line
nnoremap B ^
nnoremap E $

" $/^ doesn't do anything
nnoremap $ <nop>
nnoremap ^ <nop>

" ================ Persistent Undo ==================
" Keep undo history across sessions, by storing in file.
" Only works all the time.
if has('persistent_undo') && isdirectory(expand('~').'/.vim/backups')
    silent !mkdir ~/.vim/backups > /dev/null 2>&1
    set undodir=~/.vim/backups
    set undofile
endif

" ================ Scrolling ========================

set scrolloff=8         "Start scrolling when we're 8 lines away from margins
set sidescrolloff=15
set sidescroll=1

" ========== copy without row numbers ===============
set mouse+=a
