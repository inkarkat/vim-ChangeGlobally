" ChangeGlobally.vim: Change {motion} text and repeat the substitution on the entire line.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	001	28-Aug-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ChangeGlobally#Arm()
    let s:register = v:register

    augroup ChangeGlobally
	autocmd! InsertLeave * call ChangeGlobally#Substitute() | autocmd! ChangeGlobally
    augroup END
endfunction
function! ChangeGlobally#Operator( type, ... )
    let l:isAtEndOfLine = 0

    if a:type =~# "^[vV\<C-v>]$"
	silent! execute 'normal! `<' . a:type . '`>'
    elseif a:type ==# 'char'
	let s:range = 'line'
	let l:isAtEndOfLine = (col("']") + 1 == col('$'))
	silent! execute 'normal! `[v`]'. (&selection ==# 'exclusive' ? 'l' : '')
    elseif a:type ==# 'line'
	silent! execute "normal! '[V']"
    elseif a:type ==# 'block'
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    endif
    " TODO: Special case for "_
    execute 'normal! "' . s:register . 'd'

    if l:isAtEndOfLine
	startinsert!
    else
	startinsert
    endif

    if a:0 | silent! call repeat#set(a:1) | endif
    silent! call visualrepeat#set("\<Plug>ChangeGloballyVisual")
endfunction

function! ChangeGlobally#OperatorExpression()
    call ChangeGlobally#Arm()
    set opfunc=ChangeGlobally#Operator

    let l:keys = 'g@'

    if ! &l:modifiable || &l:readonly
	" Probe for "Cannot make changes" error and readonly warning via a no-op
	" dummy modification.
	" In the case of a nomodifiable buffer, Vim will abort the normal mode
	" command chain, discard the g@, and thus not invoke the operatorfunc.
	let l:keys = ":call setline('.', getline('.'))\<CR>" . l:keys
    endif

    return l:keys
endfunction

function! s:GetInsertion()
    " Unfortunately, we cannot simply use register "., because it contains all
    " editing keys, so also <Del> and <BS>, which show up in raw form "<80>kD".
    " Instead, we rely on the range delimited by the marks '[ and '] (last one
    " exclusive).
    let l:startPos = getpos("'[")[1:2]
    let l:endPos = [line("']"), (col("']") - 1)]
    return CompleteHelper#ExtractText(l:startPos, l:endPos, {})
endfunction
function! ChangeGlobally#Substitute()
    let l:changedText = getreg(s:register)
    let l:newText = s:GetInsertion()
"****D echomsg '**** subst' string(l:changedText) string(@.) string(l:newText)

    if s:range ==# 'line'
	" The line may have been split into multiple lines by the editing.
	execute printf("'[,']substitute/\\V%s/%s/ge",
	\   escape(l:changedText, '/\'),
	\   escape(l:newText, '/\'.(&magic ? '&~' : ''))
	\)
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
