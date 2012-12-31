" pyflakes-nopython.vim - A slight modification of Kevin Watters's 
" pyflakes.vim script that can be used even with vim that has no Python
" support. The original script can be found
" at http://www.vim.org/scripts/script.php?script_id=2441.
"
" Its objective is to to highlight Python code on the fly with warnings
" from Pyflakes, a Python lint tool. See README for information about
" installation.
"
" Author: Hynek Urban <wwuzzy@gmail.com>
" Version: 0.2


if exists("b:did_pyflakes_plugin")
    finish " only load once
else
    let b:did_pyflakes_plugin = 1
endif

" Let Python find the necessary files.
if has('win16') || has('win32') || has('win64') || has('win95')
    let s:path_separator='\'
    let s:pathlist_separator=';'
else
    let s:path_separator='/'
    let s:pathlist_separator=':'
endif
let s:current_file=expand("<sfile>")
let s:path=fnamemodify(s:current_file, ':p:h')
let $PYTHONPATH=$PYTHONPATH . s:pathlist_separator . s:path . s:path_separator . 'pyflakes'
let s:python_call = 'python ' . s:path . s:path_separator . 'pyflakes-wrapper.py' " Change this to suit your needs if necessary.

if !exists('g:pyflakes_use_quickfix')
    let g:pyflakes_use_quickfix = 1
endif



au BufLeave <buffer> call s:ClearPyflakes()

au BufEnter <buffer> call s:RunPyflakes()
au InsertLeave <buffer> call s:RunPyflakes()
au InsertEnter <buffer> call s:RunPyflakes()
au BufWritePost <buffer> call s:RunPyflakes()

au CursorHold <buffer> call s:RunPyflakes()
au CursorHoldI <buffer> call s:RunPyflakes()

au CursorHold <buffer> call s:GetPyflakesMessage()
au CursorMoved <buffer> call s:GetPyflakesMessage()

if !exists("*s:PyflakesUpdate")
    function s:PyflakesUpdate()
        silent call s:RunPyflakes()
        call s:GetPyflakesMessage()
    endfunction
endif

" Call this function in your .vimrc to update PyFlakes
if !exists(":PyflakesUpdate")
  command PyflakesUpdate :call s:PyflakesUpdate()
endif

" Hook common text manipulation commands to update PyFlakes
"   TODO: is there a more general "text op" autocommand we could register
"   for here?
noremap <buffer><silent> dd dd:PyflakesUpdate<CR>
noremap <buffer><silent> dw dw:PyflakesUpdate<CR>
noremap <buffer><silent> u u:PyflakesUpdate<CR>
noremap <buffer><silent> <C-R> <C-R>:PyflakesUpdate<CR>

" WideMsg() prints [long] message up to (&columns-1) length
" guaranteed without "Press Enter" prompt.
if !exists("*s:WideMsg")
    function s:WideMsg(msg)
        let x=&ruler | let y=&showcmd
        set noruler noshowcmd
        redraw
        echo strpart(a:msg, 0, &columns-1)
        let &ruler=x | let &showcmd=y
    endfun
endif

if !exists("*s:GetQuickFixStackCount")
    function s:GetQuickFixStackCount()
        let l:stack_count = 0
        try
            silent colder 9
        catch /E380:/
        endtry

        try
            for i in range(9)
                silent cnewer
                let l:stack_count = l:stack_count + 1
            endfor
        catch /E381:/
            return l:stack_count
        endtry
    endfunction
endif

if !exists("*s:ActivatePyflakesQuickFixWindow")
    function s:ActivatePyflakesQuickFixWindow()
        try
            silent colder 9 " go to the bottom of quickfix stack
        catch /E380:/
        endtry

        if s:pyflakes_qf > 0
            try
                exe "silent cnewer " . s:pyflakes_qf
            catch /E381:/
                echoerr "Could not activate Pyflakes Quickfix Window."
            endtry
        endif
    endfunction
endif


if !exists("*s:GetBufferContents")
    function s:GetBufferContents()
        return join(getline(1, 999999), "\n") " TODO: read the number of lines correctly, account for folds etc.
    endfunction
endif


if !exists("*s:RunPyflakes")
    function s:RunPyflakes()
        highlight link PyFlakes SpellBad

        if exists("b:cleared")
            if b:cleared == 0
                silent call s:ClearPyflakes()
                let b:cleared = 1
            endif
        else
            let b:cleared = 1
        endif
        
        let b:matched = []
        let b:matchedlines = {}

        let b:qf_list = []
        let b:qf_window_count = -1

        " The output from the Python call is supposed to have the following
        " format:
        " <line_number> <column_number> <message>
        let b:python_call = s:python_call . ' ' . bufname('%')
        let b:python_output=system(b:python_call, s:GetBufferContents())

        let b:issues = split(b:python_output, "\n")
        for b:issue in b:issues
            let b:python_arr = split(b:issue, ' ')
            let b:lineno = b:python_arr[0]
            let b:colno = b:python_arr[1]
            let b:msg = join(b:python_arr[2:], ' ')
        
            let s:matchDict = {}
            let s:matchDict['lineNum'] = b:lineno
            let s:matchDict['message'] = b:msg
            let b:matchedlines[b:lineno + 0] = s:matchDict
            
            let l:qf_item = {}
            let l:qf_item.bufnr = bufnr('%')
            let l:qf_item.filename = expand('%')
            let l:qf_item.lnum = b:lineno
            let l:qf_item.text = b:msg
            let l:qf_item.type = 'E'
        
            if b:colno == "-1"
                " without column information, just highlight the whole line
                " (minus the newline)
                let s:mID = matchadd('PyFlakes', '\%' . b:lineno . 'l\n\@!')
            else
                " with a column number, highlight the first keyword there
                let s:mID = matchadd('PyFlakes', '^\%' . b:lineno . 'l\_.\{-}\zs\k\+\k\@!\%>' . b:colno . 'c')
        
                let l:qf_item.vcol = 1
                let l:qf_item.col = b:colno
            endif
        
            call add(b:matched, s:matchDict)
            call add(b:qf_list, l:qf_item)
        endfor

        if g:pyflakes_use_quickfix == 1
            if exists("s:pyflakes_qf")
                " if pyflakes quickfix window is already created, reuse it
                call s:ActivatePyflakesQuickFixWindow()
                call setqflist(b:qf_list, 'r')
            else
                " one pyflakes quickfix window for all buffer
                call setqflist(b:qf_list, '')
                let s:pyflakes_qf = s:GetQuickFixStackCount()
            endif
        endif

        let b:cleared = 0
    endfunction
end

" keep track of whether or not we are showing a message
let b:showing_message = 0

if !exists("*s:GetPyflakesMessage")
    function s:GetPyflakesMessage()
        let s:cursorPos = getpos(".")

        " Bail if RunPyflakes hasn't been called yet.
        if !exists('b:matchedlines')
            return
        endif

        " if there's a message for the line the cursor is currently on, echo
        " it to the console
        if has_key(b:matchedlines, s:cursorPos[1])
            let s:pyflakesMatch = get(b:matchedlines, s:cursorPos[1])
            call s:WideMsg(s:pyflakesMatch['message'])
            let b:showing_message = 1
            return
        endif

        " otherwise, if we're showing a message, clear it
        if b:showing_message == 1
            echo
            let b:showing_message = 0
        endif
    endfunction
endif

if !exists('*s:ClearPyflakes')
    function s:ClearPyflakes()
        let s:matches = getmatches()
        for s:matchId in s:matches
            if s:matchId['group'] == 'PyFlakes'
                call matchdelete(s:matchId['id'])
            endif
        endfor
        let b:matched = []
        let b:matchedlines = {}
        let b:cleared = 1
    endfunction
endif
