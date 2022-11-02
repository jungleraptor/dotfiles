syntax on

set number
set cursorline
set expandtab

" Better search
set ignorecase
set smartcase
set incsearch

" Disable annoying error noise
set noerrorbells visualbell t_vb=

" Makes lightline work
set laststatus=2

" Removes redundant --INSERT--
set noshowmode

" Fuzzy Find installed via git
set rtp+=~/.fzf

" Persistent undo
set undodir=~/.vimdid
set undofile

" Judge me!
set mouse=a

set background=dark
let g:lightline = { 'colorscheme': 'one', }
