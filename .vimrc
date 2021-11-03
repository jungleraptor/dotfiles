syntax on

set number
set cursorline

let g:gruvbox_contrast_dark = 'hard'
colorscheme gruvbox
set background=dark

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

let g:lightline = { 'colorscheme': 'gruvbox', }
