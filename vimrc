syntax on

" Indenting is four spaces not eight
set shiftwidth=4

" Number of spaces inserted when inputting tab
set softtabstop=4

" Spaces instead of tabs
set expandtab

set relativenumber

set cursorline

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

" Use <C-L> to clear the highlighting of :set hlsearch.
if maparg('<C-L>', 'n') ==# ''
  nnoremap <silent> <C-L> :nohlsearch<C-R>=has('diff')?'<Bar>diffupdate':''<CR><CR><C-L>
endif

nnoremap <silent> <C-j> <C-e>

nnoremap <silent> <C-k> <C-y>

set background=dark
let g:lightline = { 'colorscheme': 'one', }
