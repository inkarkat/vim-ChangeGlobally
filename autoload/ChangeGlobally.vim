" ChangeGlobally.vim: Change {motion} text and repeat the substitution on the entire line.
"
" DEPENDENCIES:
"   - ingointegration.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	003	21-Sep-2012	ENH: Use [count] before the operator and in
"				visual mode to specify the number of
"				substitutions that should be made.
"				Add ChangeGlobally#SetCount() to record it.
"				ENH: When a characterwise change cannot be
"				re-applied in the same line, perform the
"				substitution globally or [count] times in the
"				text following the change.
"				ENH: Limit too large [count] on repeat to the
"				end of the buffer instead of displaying an "E16:
"				invalid range" error. This allows using a large
"				count to re-apply the command to the rest of the
"				buffer.
"				Silence :undo messages, because together with
"				the :substitution messages they lead to
"				hit-enter prompts.
"	002	01-Sep-2012	Switch from CompleteHelper#ExtractText() to
"				ingointegration#GetText().
"	001	28-Aug-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ChangeGlobally#SetCount( count )
    let s:count = a:count
endfunction
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

    let s:previousInsertedText = @.
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
    return ingointegration#GetText(l:startPos, l:endPos)
endfunction
function! s:LastReplaceInit()
    let s:lastReplaceCnt = 0
    let s:lastReplacementLnum = line('.')
    let s:lastReplacementLines = {}
endfunction
function! ChangeGlobally#CountedReplace( count )
    if s:lastReplaceCnt < a:count
	let s:lastReplaceCnt += 1
	let s:lastReplacementLnum = line('.')
	let s:lastReplacementLines[line('.')] = 1
	return s:newText
    else
	return submatch(0)
    endif
endfunction
function! s:Substitute( range, substitutionArguments )
    let l:substitutionCommand = a:range . 'substitute/\V' . a:substitutionArguments . 'e'
"****D echomsg '****' l:substitutionCommand
    call s:LastReplaceInit()
    if s:count
	" It would be nice if we could abort the :substitution when the
	" s:lastReplaceCnt has been reached. Unfortunately, throwing an
	" exception from ChangeGlobally#CountedReplace() will still substitute
	" with an empty string, so we cannot use that. Instead, we have the line
	" number recorded and jump back to the line with the last substitution.
	" Because of this, the "N substitutions on M lines" will also be wrong.
	" We have to suppress the original message and emulate that, too.
	silent execute l:substitutionCommand
	execute 'normal!' s:lastReplacementLnum . 'G^'

	let l:replacementLines = len(s:lastReplacementLines)
	if l:replacementLines >= &report
	    echomsg printf('%d substitution%s on %d line%s',
	    \   s:lastReplaceCnt, (s:lastReplaceCnt == 1 ? '' : 's'),
	    \   l:replacementLines, (l:replacementLines == 1 ? '' : 's')
	    \)
	endif
    else
	execute l:substitutionCommand
    endif
endfunction
function! ChangeGlobally#Substitute()
    let l:changeStartVirtCol = virtcol("'[") " Need to save this, both :undo and the check substitution will set the column to 1.

    " XXX: :startinsert does not clear register . when insertion is aborted
    " immediately (in Vim 7.3). So compare with the captured previous contents,
    " too.
    let l:hasAbortedInsert = getpos("'[") == getpos("']") && (empty(@.) || @. ==# s:previousInsertedText)
"****D echomsg '****' string(getpos("'[")) string(getpos("']")) string(@.) l:hasAbortedInsert
    let l:changedText = getreg(s:register)
    let s:newText = s:GetInsertion(s:range)
"****Dechomsg '**** subst' string(l:changedText) string(@.) string(s:newText)
    " For :substitute, we need to convert newlines in both parts (differently).
    let l:search = substitute(escape(l:changedText, '/\'), '\n', '\\n', 'g')
    if s:count
	" Only apply the substitution [count] times. We do this via a
	" replace-expression that counts the number of replacements; unlike a
	" repeated single substitution, this avoids the issue of re-replacing.
	" Note: We cannot simply pass in the replacement via string(s:newText);
	" it may contain the / substitution separator, which must not appear at
	" all in the expression. Therefore, we store this in a variable and
	" directly reference it from ChangeGlobally#CountedReplace().
	let l:replace = printf('\=ChangeGlobally#CountedReplace(%d)', s:count)
    else
	let l:replace = substitute(escape(s:newText, '/\'.(&magic ? '&~' : '')), '\n', "\r", 'g')
    endif


    " To turn the change and following substitutions into a single change, first
    " undo the deletion and insertion. (I couldn't get them combined with
    " :undojoin across the :startinsert.)
    " This also solves the special case when l:changedText is contained in
    " s:newText; without the undo, we would need to avoid re-applying the
    " substitution over the just changed part of the line.
    if ! l:hasAbortedInsert
	silent undo " the insertion of s:newText
    endif
    silent undo " the deletion of l:changedText


    let l:locationRestriction = ''
    let s:locationRestriction = ''
    if s:range ==# 'line'
	" Check whether more than one substitution can be made in the line to
	" determine whether the substitution should be applied to the line or
	" beyond.
	redir => l:substitutionCounting
	    silent! execute printf("'[,']".'substitute/\V%s/&/gn', l:search)
	redir END
	let l:substitutionCnt = str2nr(matchstr(l:substitutionCounting, '\d\+'))
	let l:isBeyondLineSubstitution = (l:substitutionCnt == 1)

	if s:count
	    " When a [count] was given, only apply the substitution [count]
	    " times starting from the original change, not before it.
	    let l:locationRestriction = printf('\%%(\%%>%dv\|\%%>%dl\)', l:changeStartVirtCol - 1, line("'["))
	    let s:locationRestriction = printf('\%%>%dv', l:changeStartVirtCol - 1)
	    let l:beyondLineRange = "'[,$"
	else
	    " Otherwise, apply it globally.
	    let l:beyondLineRange = '%'
	endif

	let s:substitution = printf('%s/%s/g',
	\   l:search,
	\   l:replace
	\)

	" Note: The line may have been split into multiple lines by the editing;
	" use '[, '] instead of the . range.
	let l:range = (l:isBeyondLineSubstitution ? l:beyondLineRange : "'[,']")
    elseif s:range ==# 'buffer'
	" We need to remove the trailing newline in the search pattern and
	" anchor the search to the beginning and end of a line, so that only
	" entire lines are substituted. Were we to alternatively append a \r to
	" the replacement, the next line would be involved and the cursor
	" misplaced.
	let s:substitution = printf('\^%s\$/%s/',
	\   substitute(l:search, '\\n$', '', ''),
	\   l:replace
	\)

	let l:range = (s:count ? '.,$' : '%')
    else
	throw 'ASSERT: Invalid s:range: ' . string(s:range)
    endif


    " Note: Only part of the location restriction (without the line restriction)
    " applies to repeats, so it's not included in s:substitution.
    call s:Substitute(l:range, l:locationRestriction . s:substitution)


    " Do not store the [count] here; it is invalid / empty due to the autocmd
    " invocation here, anyway. But allow specifying a custom [count] on
    " repetition (which would be disallowed by passing -1).
    silent! call       repeat#set("\<Plug>(ChangeGloballyRepeat)", '')
    silent! call visualrepeat#set("\<Plug>(ChangeGloballyVisualRepeat)", '')
endfunction

function! ChangeGlobally#Repeat( isVisualMode )
    " Re-apply the previous substitution (without new insert mode) to the visual
    " selection, [count] next lines, or the range of the previous substitution.
    if a:isVisualMode
	let l:range = "'<,'>"
    elseif v:count1 > 1
	" Avoid "E16: invalid range" when a too large [count] was given.
	let l:range = (line('.') + v:count - 1 < line('$') ? '.,.+'.(v:count1 - 1) : '.,$')
    else
	let l:range = (s:range ==# 'line' ? '' : '%')
    endif

    try
	if s:count && s:range ==# 'line'
	    " When we this is substitution inside a line, and the number of
	    " matches is restricted, we need to apply the substitution to each
	    " line separately in order to reset s:lastReplaceCnt. Otherwise, the
	    " substitution count would peter out on the first line already, and
	    " any repeat count would be without effect.
	    execute l:range 'call s:Substitute(".", s:locationRestriction . s:substitution)'
	else
	    call s:Substitute(l:range, s:locationRestriction . s:substitution)
	endif
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
