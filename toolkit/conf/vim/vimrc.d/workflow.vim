let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_winsize = 25
let g:netrw_keepdir = 1

" File explorer.
function! s:toggle_explorer() abort
    let explorers = filter(getwininfo(), {_, win ->
        \ win.tabnr == tabpagenr() && getbufvar(win.bufnr, '&filetype') ==# 'netrw'})
    if empty(explorers)
        execute 'Lexplore ' . fnameescape(expand('%:p:h'))
    else
        Lexplore
    endif
endfunction

" Compare unsaved changes with the on-disk snapshot.
function! s:set_disk_diff(enabled) abort
    let command = a:enabled ? 'if !&diff | diffthis | endif' : 'if &diff | diffoff | endif'
    for preview in filter(getwininfo(), {_, win ->
        \ win.tabnr == tabpagenr() && getbufvar(win.bufnr, 'linux_configs_diff_source', 0) != 0})
        let source = getbufvar(preview.bufnr, 'linux_configs_diff_source')
        if a:enabled
            if !getbufvar(preview.bufnr, 'linux_configs_diff_resume', 0) || win_id2win(source) == 0
                continue
            endif
        else
            call setbufvar(preview.bufnr, 'linux_configs_diff_resume', getwinvar(preview.winnr, '&diff'))
        endif
        if win_id2win(source) > 0
            call win_execute(source, command)
        endif
        call win_execute(preview.winid, command)
    endfor
endfunction

function! s:toggle_disk_diff() abort
    let previews = filter(getwininfo(), {_, win ->
        \ win.tabnr == tabpagenr() && getbufvar(win.bufnr, 'linux_configs_diff_source', 0) != 0})
    if !empty(previews)
        let source = getbufvar(previews[0].bufnr, 'linux_configs_diff_source')
        if winnr('$') == 1
            enew
        else
            call win_execute(previews[0].winid, 'close')
        endif
        if win_id2win(source) > 0
            call win_gotoid(source)
        endif
        return
    endif

    let path = expand('%:p')
    if &buftype !=# '' || !filereadable(path)
        echoerr 'Open an existing file before comparing it with disk'
        return
    endif
    if !empty(filter(getwininfo(), {_, win ->
        \ win.tabnr == tabpagenr() && getwinvar(win.winnr, '&diff')}))
        echoerr 'Leave the current tab diff session before comparing with disk'
        return
    endif

    let source = win_getid()
    let filetype = &filetype
    let view = winsaveview()
    keepalt vertical new
    setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
    " Keep a real placeholder so :read cannot discard the initial empty line.
    call setline(1, '[disk snapshot]')
    execute 'silent keepalt read ++edit ' . fnameescape(path)
    silent 1delete _
    let &l:filetype = filetype
    let b:linux_configs_diff_source = source
    let b:linux_configs_disk_path = path
    let &l:statusline = ' [DISK - read only] %<%{b:linux_configs_disk_path} %= %l:%c '
    setlocal readonly nomodifiable nomodified
    diffthis
    call win_gotoid(source)
    diffthis
    call winrestview(view)
endfunction

" Literal-text configuration search via ripgrep and quickfix.
function! s:search_configs(pattern, directory) abort
    if empty(a:pattern) || empty(a:directory)
        return
    endif
    if !executable('rg')
        echoerr 'ripgrep is not installed'
        return
    endif
    let directory = fnamemodify(a:directory, ':p')
    if !isdirectory(directory) || resolve(directory) ==# '/'
        echoerr 'Choose an existing configuration directory, not /'
        return
    endif

    let output = systemlist('rg --no-config --vimgrep --fixed-strings --smart-case'
        \ . ' --hidden --follow --glob ' . shellescape('!.git')
        \ . ' -- ' . shellescape(a:pattern) . ' ' . shellescape(directory))
    if v:shell_error > 1
        echoerr 'Search failed: ' . join(output, "\n")
        return
    endif
    call setqflist([], ' ', {
        \ 'title': 'Config search: ' . a:pattern,
        \ 'lines': output,
        \ 'efm': '%f:%l:%c:%m',
        \ })
    if empty(output)
        cclose
        echomsg 'No matches'
    else
        botright copen
    endif
endfunction

" Shortcut reference and mappings.
function! s:show_shortcuts() abort
    call popup_menu([
        \ '一般模式：先按空白鍵（Space），再按下一個鍵。',
        \ '',
        \ 'Space e        開關目前檔案旁的檔案樹',
        \ 'Space b        列出緩衝區，再輸入編號切換',
        \ '[b / ]b        上一個／下一個緩衝區',
        \ 'Space d        開關與磁碟已存檔版本的差異比較',
        \ 'Space f        在指定目錄搜尋文字（非正規表示式）',
        \ 'Space c        顯示搜尋結果；Enter 開啟項目',
        \ '[q / ]q        上一筆／下一筆搜尋結果',
        \ 'Space u        檢查檔案是否被外部修改',
        \ 'Space v / s    左右／上下分割視窗',
        \ 'Ctrl-w h/j/k/l 切換至左／下／上／右視窗',
        \ 'Space /        清除搜尋反白',
        \ 'Space n / r    開關絕對行號／相對行號（預設關閉）',
        \ 'Space l / z    開關空白字元標記／自動折行',
        \ '滑鼠拖曳       使用終端選取文字，而非 Vim',
        \ '複製           使用終端複製；顯示行號時會一起複製',
        \ 'F2             開關貼上模式，供舊式終端使用',
        \ 'Ctrl-n / p     插入模式中的下一個／上一個文字補全',
        \ ':e + Tab       補全檔案路徑；:help 開啟 Vim 說明',
        \ ], {
        \ 'title': ' Vim 快捷鍵：j/k 捲動，Esc 關閉 ',
        \ 'padding': [0, 1, 0, 1],
        \ 'maxheight': 18,
        \ 'maxwidth': 72,
        \ })
endfunction

command! -nargs=+ ConfigSearch call <SID>search_configs(<q-args>, input('Directory: ', expand('%:p:h'), 'dir'))

nnoremap <silent> <F1> :call <SID>show_shortcuts()<CR>
nnoremap <silent> <leader>? :call <SID>show_shortcuts()<CR>
nnoremap <silent> <leader>e :call <SID>toggle_explorer()<CR>
nnoremap <silent> <leader>d :call <SID>toggle_disk_diff()<CR>
nnoremap <leader>f :ConfigSearch<Space>
nnoremap <silent> <leader>c :copen<CR>
nnoremap <silent> [q :cprevious<CR>
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> <leader>u :checktime<CR>
nnoremap <leader>b :ls<CR>:buffer<Space>
nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> <leader>v :vsplit<CR>
nnoremap <silent> <leader>s :split<CR>
nnoremap <silent> <leader>/ :nohlsearch<CR>
nnoremap <silent> <leader>n :setlocal number!<CR>
nnoremap <silent> <leader>r :setlocal relativenumber!<CR>
nnoremap <silent> <leader>l :setlocal list!<CR>
nnoremap <silent> <leader>z :setlocal wrap!<CR>
xnoremap < <gv
xnoremap > >gv

" Window lifecycle, filetype detection, and cursor restoration.
augroup linux_configs_vim
    autocmd!
    autocmd FocusGained,BufEnter * if mode() ==# 'n' && getcmdwintype() ==# '' | checktime | endif
    " Ctrl-w T recreates the window; suspend before it can copy stale diff options.
    autocmd TabLeave * call <SID>set_disk_diff(0)
    autocmd TabEnter * call <SID>set_disk_diff(1)
    autocmd BufWinLeave * if exists('b:linux_configs_diff_source') | call <SID>set_disk_diff(0) | endif
    " Nginx site/snippet files often have no extension.
    autocmd BufRead,BufNewFile */nginx/sites-available/*,*/nginx/sites-enabled/*,*/nginx/snippets/* setfiletype nginx
    autocmd BufReadPost *
        \ if &buftype ==# '' && &filetype !~# 'commit\|rebase'
        \ && line("'\"") > 1 && line("'\"") <= line('$')
        \ | execute "normal! g`\""
        \ | endif
augroup END
