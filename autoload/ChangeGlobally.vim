" ChangeGlobally.vim: Change {motion} text and repeat the substitution on the entire line.
"
" DEPENDENCIES:
"   - CompleteHelper.vim autoload script
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

function! ChangeGlobally#SetRegister()
    let s:register = v:register
endfunction
function! s:ArmInsertMode()
    augroup ChangeGlobally
	autocmd! InsertLeave * call ChangeGlobally#Substitute() | autocmd! ChangeGlobally
    augroup END
endfunction
function! ChangeGlobally#Operator( type )
    let l:isAtEndOfLine = 0

    if a:type ==# 'v'
	let s:range = 'line'
	let l:isAtEndOfLine = (col("'>") == col('$'))
	silent! execute 'normal! gv'
    elseif a:type ==# 'V'
	let s:range = 'buffer'
	silent! execute 'normal! gv'
    elseif a:type ==# "\<C-v>"
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    elseif a:type ==# 'char'
	let s:range = 'line'
	let l:isAtEndOfLine = (col("']") + 1 == col('$'))
	silent! execute 'normal! `[v`]'. (&selection ==# 'exclusive' ? 'l' : '')
    elseif a:type ==# 'line'
	let s:range = 'buffer'
	silent! execute "normal! '[V']"
    elseif a:type ==# 'block'
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    endif

    " For linewise deletion, the "s" command collapses all line(s) into a single
    " one. We insert and remove a dummy character to keep the indent, then leave
    " insert mode, to be re-entered via :startinsert!
    let l:deleteCommand = (s:range ==# 'line' ? 'd' : "s$\<BS>\<Esc>")

    " TODO: Special case for "_
    execute 'normal! "' . s:register . l:deleteCommand

    if l:isAtEndOfLine || s:range ==# 'buffer'
	startinsert!
    else
	startinsert
    endif

    " Don't set up the repeat; we're not done yet. We now install an autocmd,
    " and the ChangeGlobally#Substitute() will conclude the command, and set the
    " repeat there.
    call s:ArmInsertMode()
endfunction
function! ChangeGlobally#OperatorExpression()
    call ChangeGlobally#SetRegister()
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

function! s:GetInsertion( range )
    " Unfortunately, we cannot simply use register "., because it contains all
    " editing keys, so also <Del> and <BS>, which show up in raw form "<80>kD".
    " Instead, we rely on the range delimited by the marks '[ and '] (last one
    " exclusive).

    if a:range ==# 'buffer'
	" There may have been existing indent before we started editing, which
	" isn't captured by '[, but which we need to correctly reproduce the
	" change. Therefore, grab the entire starting line.
	let l:startPos = [line("'["), 1]
    else
	let l:startPos = getpos("'[")[1:2]
    endif
    let l:endPos = [line("']"), (col("']") - 1)]
    return CompleteHelper#ExtractText(l:startPos, l:endPos, {})
endfunction
function! ChangeGlobally#Substitute()
    let l:changedText = getreg(s:register)
    let l:newText = s:GetInsertion(s:range)
echomsg '**** subst' string(l:changedText) string(@.) string(l:newText)

    " For :substitute, we need to convert newlines in both parts (differently).
    let l:search = substitute(escape(l:changedText, '/\'), '\n', '\\n', 'g')
    let l:replace = substitute(escape(l:newText, '/\'.(&magic ? '&~' : '')), '\n', "\r", 'g')

    if s:range ==# 'line'
	" TODO: Special case when l:changedText is contained in l:newText; we
	" need to avoid re-applying the substitution over the just changed part
	" of the line.
	let s:substitution = printf('substitute/\V%s/%s/g',
	\   l:search,
	\   l:replace
	\)

	" The line may have been split into multiple lines by the editing.
	execute "'[,']" . s:substitution . 'e'
    elseif s:range ==# 'buffer'
	let s:substitution = printf('substitute/\V\^%s/%s\r/',
	\   l:search,
	\   l:replace
	\)

	execute "%" . s:substitution . 'e'
    else
	throw 'ASSERT: Invalid s:range: ' . string(s:range)
    endif

    " Do not store the [count] here; it is invalid / empty due to the autocmd
    " invocation here, anyway. But allow specifying a custom [count] on
    " repetition (which would be disallowed by passing -1).
    silent! call       repeat#set("\<Plug>(ChangeGloballyRepeat)", '')
    silent! call visualrepeat#set("\<Plug>(ChangeGloballyVisualRepeat)", '')
endfunction

function! ChangeGlobally#Repeat( isVisualMode )
    if a:isVisualMode
	let l:range = "'<,'>"
    else
	let l:range = (v:count1 > 1 ? '.,.+'.(v:count1 - 1) : '')
    endif

    try
	execute l:range . s:substitution
    catch /^Vim\%((\a\+)\)\=:E/
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away.
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None

	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
    endtry

    silent! call       repeat#set(a:isVisualMode ? "\<Plug>(ChangeGloballyVisualRepeat)" : "\<Plug>(ChangeGloballyRepeat)")
    silent! call visualrepeat#set("\<Plug>(ChangeGloballyVisualRepeat)")
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
