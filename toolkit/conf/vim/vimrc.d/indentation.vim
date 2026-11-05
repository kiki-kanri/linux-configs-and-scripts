" Default: four spaces for JS/TS (including JSX/TSX, MJS/CJS), Vue, Rust,
" and all other filetypes. Existing tabs are not converted automatically.
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smarttab
set backspace=indent,eol,start

" Registered after filetype plugin/indent loading so their defaults cannot win.
" Apply on every FileType event, including changes within an existing buffer.
" Even Makefiles use spaces here; recipes need a literal tab (Ctrl-v Tab).
augroup linux_configs_indent
    autocmd!
    autocmd FileType * setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
    autocmd FileType toml,yaml,json,jsonc,json5 setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
augroup END
