" Keep a usable palette over SSH without requiring true color or special fonts.
set background=dark
set notermguicolors
if $COLORTERM =~? 'truecolor\|24bit' || &term =~# '-direct$'
    set termguicolors
endif

colorscheme habamax

" Text encoding and line endings: detect LF/CRLF, but always save text as LF.
set encoding=utf-8
set fileformats=unix,dos
set fileformat=unix
augroup linux_configs_line_endings
    autocmd!
    autocmd BufWritePre,FileWritePre,FileAppendPre * if &buftype ==# '' && !&binary | setlocal fileformat=unix | endif
augroup END

" Display and window layout.
" Terminal selection copies screen text, including any visible line numbers.
set nonumber
set norelativenumber
set cursorline
set laststatus=2
set showcmd
set showmode
set showmatch
set scrolloff=5
set sidescrolloff=8
set sidescroll=1
set nowrap
set linebreak
set breakindent
set splitbelow
set splitright
set nolist
set listchars=tab:>-,trail:.,nbsp:+

let &statusline = ' %<%f %h%m%r%=%{&paste?"PASTE ":""}'
    \ . ' %y %{&fileencoding==#""?&encoding:&fileencoding}'
    \ . ' [%{&fileformat}] %l:%c %p%%  F1:keys '

" Search and completion.
set ignorecase
set smartcase
set incsearch
set hlsearch
set wildmenu
set wildmode=longest:full,full
set wildoptions=pum
set wildignore+=*.swp,*.swo,*~,*.o,*.pyc
set complete=.,w,b,u
set completeopt=menuone,noselect
set pumheight=12

" Keep edits in memory when switching files; never save them implicitly.
set hidden
set confirm
set noautowrite
set noautowriteall
set noautoread
set nomodeline
" Terminal selection/copy must work even without a remote clipboard provider.
set mouse=
set pastetoggle=<F2>
