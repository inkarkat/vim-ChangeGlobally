" ChangeGlobally.vim: Change {motion} text and repeat the substitution.
"
" DEPENDENCIES:
"   - ingo/msg.vim autoload script
"   - ingo/search/buffer.vim autoload script
"   - ingo/text.vim autoload script
"   - repeat.vim (vimscript #2136) autoload script (optional)
"   - visualrepeat.vim (vimscript #3848) autoload script (optional)
"   - visualrepeat/reapply.vim autoload script (optional)
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ChangeGlobally#SetParameters( isDelete, count, isVisualMode, repeatMapping, visualrepeatMapping, ... )
    let s:isDelete = a:isDelete
    let s:register = v:register
    let [s:isVisualMode, s:repeatMapping, s:visualrepeatMapping] = [a:isVisualMode, a:repeatMapping, a:visualrepeatMapping]

    if g:ChangeGlobally_ConfirmCount > 0 && a:count == g:ChangeGlobally_ConfirmCount
	let [s:count, s:isForceGlobal, s:isConfirm] = [0, 1, 1]
    elseif g:ChangeGlobally_GlobalCountThreshold > 0 && a:count >= g:ChangeGlobally_GlobalCountThreshold
	" When a very large [count] is given, turn a line-scoped substitution
	" into a global, buffer-scoped one.
	let [s:count, s:isForceGlobal, s:isConfirm] = [0, 1, 0]
    else
	let [s:count, s:isForceGlobal, s:isConfirm] = [a:count, 0, 0]
    endif

    if a:0
	let s:SubstitutionHook = a:1
    else
	unlet! s:SubstitutionHook
    endif
endfunction
function! s:ArmInsertMode( search, replace )
    " Autocmds may interfere with the plugin when they temporarily leave insert
    " mode (i_CTRL-O) or create an undo point (i_CTRL-G_u). Disable them until
    " the user is done inserting.
    if &eventignore ==? 'all'
	" Also handle the (unlikely) case where autocmds are completely turned
	" off.
	let s:save_eventignore = &eventignore
	set eventignore=
    elseif ! empty(&eventignore)
	let s:save_eventignore = &eventignore
	set eventignore-=CursorMovedI
	set eventignore-=CursorHoldI
    endif

    augroup ChangeGlobally
	execute printf('autocmd! InsertLeave * call ChangeGlobally#UnarmInsertMode() | call ChangeGlobally#Substitute(%s, %s)', string(a:search), string(a:replace))
    augroup END
endfunction
function! ChangeGlobally#UnarmInsertMode()
    autocmd! ChangeGlobally

    if exists('s:save_eventignore')
	let &eventignore = s:save_eventignore
	unlet s:save_eventignore
    endif
endfunction
function! ChangeGlobally#SourceOperator( type )
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
	silent! execute 'normal! g`[vg`]'. (&selection ==# 'exclusive' ? 'l' : '')
    elseif a:type ==# 'line'
	let s:range = 'buffer'
	silent! execute "normal! g'[Vg']"
    elseif a:type ==# 'block'
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    endif

    " For linewise deletion, the "s" command collapses all line(s) into a single
    " one. We insert and remove a dummy character to keep the indent, then leave
    " insert mode, to be re-entered via :startinsert!
    let l:deleteCommand = (s:isDelete || s:range ==# 'line' ? 'd' : "s$\<BS>\<Esc>")

    " TODO: Special case for "_
    execute 'normal! "' . s:register . l:deleteCommand


    let l:changedText = getreg(s:register)
    let l:search = '\V\C' . substitute(escape(l:changedText, '/\'), '\n', '\\n', 'g')
    " Only apply the substitution [count] times. We do this via a
    " replace-expression that counts the number of replacements; unlike a
    " repeated single substitution, this avoids the issue of re-replacing.
    " We also do this for the global (line / buffer) substitution without a
    " [count] in order to determine whether there actually were other matches.
    " If not, we indicate this with a beep.
    " Note: We cannot simply pass in the replacement via string(s:newText); it
    " may contain the / substitution separator, which must not appear at all in
    " the expression. Therefore, we store this in a variable and directly
    " reference it from ChangeGlobally#CountedReplace().
    let l:replace = '\=ChangeGlobally#CountedReplace()'

    if s:isDelete
	" For a global deletion, we don't need to set up and go to insert mode;
	" just record what got deleted, and reapply that.

	" Not needed for deletion.
	let s:originalChangeNr = -1
	let s:insertStartPos = [0,0]

	call ChangeGlobally#Substitute(l:search, l:replace)
	return
    endif

    let s:originalChangeNr = changenr()
    let s:insertStartPos = getpos("'[")[1:2]
    if l:isAtEndOfLine || s:range ==# 'buffer'
	startinsert!
    else
	startinsert
    endif

    " Don't set up the repeat; we're not done yet. We now install an autocmd,
    " and the ChangeGlobally#Substitute() will conclude the command, and set the
    " repeat there.
    call s:ArmInsertMode(l:search, l:replace)
endfunction
function! ChangeGlobally#CwordSourceTargetOperator( type )
    let s:range = 'area'
    " TODO: Capture area.
    " if a:type ==# 'char'
    " elseif a:type ==# 'line'
    " elseif a:type ==# 'block'
    " endif

    " TODO: Check for keyword under cursor, try jump, error if none.
    let l:isAtEndOfLine = (search('\%#\k\+$', 'cnW', line('.')) > 0)
    " TODO: Special case for "_
    execute 'normal! "' . s:register . 'daw'


    let l:changedText = getreg(s:register)
    let l:search = '\V\C\<' . substitute(escape(l:changedText, '/\'), '\n', '\\n', 'g') . '\>'
    " Only apply the substitution [count] times. We do this via a
    " replace-expression that counts the number of replacements; unlike a
    " repeated single substitution, this avoids the issue of re-replacing.
    " We also do this for the global (line / buffer) substitution without a
    " [count] in order to determine whether there actually were other matches.
    " If not, we indicate this with a beep.
    " Note: We cannot simply pass in the replacement via string(s:newText); it
    " may contain the / substitution separator, which must not appear at all in
    " the expression. Therefore, we store this in a variable and directly
    " reference it from ChangeGlobally#CountedReplace().
    let l:replace = '\=ChangeGlobally#CountedAreaReplace()'

    if s:isDelete
	" For a global deletion, we don't need to set up and go to insert mode;
	" just record what got deleted, and reapply that.

	" Not needed for deletion.
	let s:originalChangeNr = -1
	let s:insertStartPos = [0,0]

	call ChangeGlobally#Substitute(l:search, l:replace)
	return
    endif

    let s:originalChangeNr = changenr()
    let s:insertStartPos = getpos("'[")[1:2]
    if l:isAtEndOfLine
	startinsert!
    else
	startinsert
    endif

    " Don't set up the repeat; we're not done yet. We now install an autocmd,
    " and the ChangeGlobally#Substitute() will conclude the command, and set the
    " repeat there.
    call s:ArmInsertMode(l:search, l:replace)
endfunction
function! ChangeGlobally#OperatorExpression( opfunc )
    let &opfunc = a:opfunc

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

function! s:GetInsertion( range, isMultiChangeInsert )
    " Unfortunately, we cannot simply use register "., because it contains all
    " editing keys, so also <Del> and <BS>, which show up in raw form "<80>kD".
    " Instead, we rely on the range delimited by the marks '[ and '] (last one
    " exclusive).

    if a:isMultiChangeInsert
	" When an undo point is created during insertion |i_CTRL-G_u|, the
	" change marks are reset, too, and we would only capture the last part
	" of the insertion. Use the original start position instead to capture
	" the entire inserted text.
	let l:startPos = s:insertStartPos
    else
	" In the usual case, do use the start change mark, though. This makes
	" the capture more robust in the case that the whole change position
	" shifted (e.g. by indenting via |i_CTRL-T|).
	let l:startPos = getpos("'[")[1:2]
    endif

    if a:range ==# 'buffer'
	" There may have been existing indent before we started editing, which
	" isn't captured by '[, but which we need to correctly reproduce the
	" change. Therefore, grab the entire starting line.
	let l:startPos[1] = 1
    endif

    let l:endPos = [line("']"), (col("']") - 1)]
"****D echomsg '****' a:isMultiChangeInsert string(l:startPos) string(l:endPos)
    return ingo#text#Get(l:startPos, l:endPos)
endfunction
function! s:CountMatches( pattern )
    redir => l:substitutionCounting
	silent! execute printf('substitute/%s/&/gn', a:pattern)
    redir END
    return str2nr(matchstr(l:substitutionCounting, '\d\+'))
endfunction
function! s:LastReplaceInit()
    let s:lastReplaceCnt = 0
    let s:lastReplacementLnum = line('.')
    let s:lastReplacementLines = {}
endfunction
function! ChangeGlobally#CountedReplace()
    if ! s:count || s:lastReplaceCnt < s:count
	let s:lastReplaceCnt += 1
	let s:lastReplacementLnum = line('.')
	let s:lastReplacementLines[line('.')] = 1
	return s:newText
    else
	return submatch(0)
    endif
endfunction
function! ChangeGlobally#CountedAreaReplace()
    if (! s:count || s:lastReplaceCnt < s:count) && line('.') > 10 && virtcol('.') > 20 " TODO
	let s:lastReplaceCnt += 1
	let s:lastReplacementLnum = line('.')
	let s:lastReplacementLines[line('.')] = 1
	return s:newText
    else
	return submatch(0)
    endif
endfunction
function! s:Report( replaceCnt, replacementLines )
    if a:replacementLines >= &report
	echomsg printf('%d substitution%s on %d line%s',
	\   a:replaceCnt, (a:replaceCnt == 1 ? '' : 's'),
	\   a:replacementLines, (a:replacementLines == 1 ? '' : 's')
	\)
    endif
endfunction
function! s:Substitute( range, localRestriction, substitutionArguments )
    " a:substitutionArguments format:
    "   [patternPrefix, pattern, patternPostfix, separator, replacement, separator, flags]
    let l:substitutionCommand = a:range . 'substitute/' . a:localRestriction . join(a:substitutionArguments, '') . 'e'
"****D echomsg '****' l:substitutionCommand string(s:newText)
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
	execute 'keepjumps normal!' s:lastReplacementLnum . 'G^'

	call s:Report(s:lastReplaceCnt, len(s:lastReplacementLines))
    else
	execute l:substitutionCommand
    endif

    return s:lastReplaceCnt
endfunction
function! ChangeGlobally#Substitute( search, replace )
    let l:changeStartVirtCol = virtcol("'[") " Need to save this, both :undo and the check substitution will set the column to 1.

    if s:isDelete
	let l:hasAbortedInsert = 1
	let s:newText = ''
    else
	let l:hasAbortedInsert = (changenr() <= s:originalChangeNr)
	let l:isMultiChangeInsert = (changenr() > s:originalChangeNr + 1)
	let s:newText = s:GetInsertion(s:range, l:isMultiChangeInsert)
	if v:version == 703 && has('patch225') || v:version == 704 && ! has('patch261')
	    " XXX: Vim inserts \n == ^@ literally when the :s_c confirm flag is
	    " given. Convert to \r to work around this.
	    let s:newText = substitute(s:newText, '\n', '\r', 'g')
	endif
    endif
"****D echomsg '****' string(s:insertStartPos) string(getpos("'[")) string(getpos("']")) string(@.) l:hasAbortedInsert l:isMultiChangeInsert
"****D echomsg '**** subst' string(a:search) string(@.) string(s:newText)
    " For :substitute, we need to convert newlines in both parts (differently).
    let l:search = a:search
    let l:replace = a:replace


    " To turn the change and following substitutions into a single change, first
    " undo the deletion and insertion. (I couldn't get them combined with
    " :undojoin across the :startinsert.)
    " This also solves the special case when the changed text is contained in
    " s:newText; without the undo, we would need to avoid re-applying the
    " substitution over the just changed part of the line.
    if ! l:hasAbortedInsert
	execute 'silent undo' s:originalChangeNr | " undo the insertion of s:newText
    endif
    silent undo " the deletion of the changed text


    if exists('s:SubstitutionHook')
	" Allow manipulation of the substitution arguments to facilitate easy
	" reuse, especially for a similar SmartCase substitution. We must do
	" this here on the search and replace parts (and not on the final
	" s:substitution), because we need l:search for the s:CountMatches()
	" check before the actual substitution.
	let [l:search, l:replace] =  call(s:SubstitutionHook, [l:search, l:replace, s:range])
    endif


    let l:locationRestriction = ''
    let s:locationRestriction = ''
    let s:isBeyondLineSubstitution = 1
    if s:range ==# 'line'
	if ! s:isVisualMode && ingo#search#buffer#IsKeywordMatch(l:search, l:changeStartVirtCol)
	    " When the changed text is surrounded by keyword boundaries, only
	    " perform keyword replacements to avoid replacing other matches
	    " inside keywords (e.g. "in" inside "ring").
	    let l:search = '\<' . l:search . '\>'
	endif

	" Check whether more than all s:count / one substitution can be made in
	" the line to determine whether the substitution should be applied to
	" the line or beyond. (Unless the special
	" g:ChangeGlobally_LimitToCurrentLineCount is given.)
	let s:isBeyondLineSubstitution = (s:isForceGlobal || (
	\   (g:ChangeGlobally_LimitToCurrentLineCount != 0 && s:count == g:ChangeGlobally_LimitToCurrentLineCount) ?
	\       (s:CountMatches(l:search) == 1) :
	\       (s:count ? s:count : 2) > s:CountMatches(l:search)
	\   )
	\)

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

	let s:substitution = ['', l:search, '', '/', l:replace, '/', 'g' . (s:isConfirm ? 'c' : '')]

	" Note: The line may have been split into multiple lines by the editing;
	" use '[, '] instead of the . range.
	let l:range = (s:isBeyondLineSubstitution ? l:beyondLineRange : "'[,']")
    elseif s:range ==# 'buffer'
	if s:isDelete
	    " Keep the trailing newline so that the entire line(s) are deleted
	    " without leaving an empty line behind.
	    let s:substitution = ['^', l:search, '/', l:replace, '/', (s:isConfirm ? 'c' : '')]
	else
	    " We need to remove the trailing newline in the search pattern and
	    " anchor the search to the beginning and end of a line, so that only
	    " entire lines are substituted. Were we to alternatively append a \r
	    " to the replacement, the next line would be involved and the cursor
	    " misplaced.
	    let s:substitution = ['^', substitute(l:search, '\\n$', '', ''), '\$', '/', l:replace, '/', (s:isConfirm ? 'c' : '')]
	endif

	let l:range = (s:count ? '.,$' : '%')
    elseif s:range ==# 'area'
	let s:substitution = [l:search, '/', l:replace, '/', 'g' . (s:isConfirm ? 'c' : '')]
	let l:range = '%'
    else
	throw 'ASSERT: Invalid s:range: ' . string(s:range)
    endif


    " Note: Only part of the location restriction (without the line restriction)
    " applies to repeats, so it's not included in s:substitution.
    if s:Substitute(l:range, l:locationRestriction, s:substitution) <= 1
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
    endif


    " Do not store the [count] here; it is invalid / empty due to the autocmd
    " invocation here, anyway. But allow specifying a custom [count] on
    " repetition (which would be disallowed by passing -1).
    silent! call       repeat#set(s:repeatMapping)
    silent! call visualrepeat#set(s:visualrepeatMapping)
endfunction

function! s:IndividualSubstitute( locationRestriction, substitutionArguments )
    let l:count = s:Substitute('.', a:locationRestriction, a:substitutionArguments)
    let s:individualReplace.count += l:count
    let s:individualReplace.lines += (l:count ? 1 : 0)
endfunction
function! ChangeGlobally#Repeat( isVisualMode, repeatMapping, visualrepeatMapping )
    " Re-apply the previous substitution (without new insert mode) to the visual
    " selection, [count] next lines, or the range of the previous substitution.
    if a:isVisualMode
	let l:range = "'<,'>"
	if visualmode() ==# "\<C-v>"
	    " Special handling for blockwise selection:
	    " - With buffer range, match not only complete lines (they probably
	    "   aren't fully selected), just the text itself.
	    let s:substitution[0] = ''
	    let s:substitution[2] = ''
	    " - Drop the location restriction to after certain columns; they may
	    "   not even fall into the selected block.
	    let s:locationRestriction = ''
	    " Likewise, drop the [N] times limit.
	    let s:count = 0
	    " - Apply within the entire selected block.
	    "   For \%V to work on a zero-width block selection with :set
	    "   selection=exclusive, a special case must be applied.
	    call ingo#selection#patternmatch#AdaptEmptySelection()
	    "   Special case must be taken to when the match ends at the end of
	    "   the visual selection, as \%V is a zero-width pattern.
	    if s:substitution[1][0:2] !=# '\%V'
		let s:substitution[1] = '\%V' . s:substitution[1] . '\%(\%V\.\)\@<='
	    endif
	    " All these modifications are done to the persisted variables, so
	    " the blockwise repeat could be cleverly employed to remove certain
	    " change restrictions for following repeats of different kinds.
	endif
    elseif v:count1 > 1
	" Avoid "E16: invalid range" when a too large [count] was given.
	let l:range = (line('.') + v:count - 1 < line('$') ? '.,.+'.(v:count1 - 1) : '.,$')
    else
	let l:range = (s:range ==# 'line' ?
	\   (s:isBeyondLineSubstitution ?
	\   '.,$' :
	\   ''
	\   ) :
	\   '%'
	\)
    endif

    try
	if s:count && s:range ==# 'line' && ! s:isBeyondLineSubstitution
	    " When this is a substitution inside a line, and the number of
	    " matches is restricted, we need to apply the substitution to each
	    " line separately in order to reset s:lastReplaceCnt. Otherwise, the
	    " substitution count would peter out on the first line already, and
	    " any repeat count would be without effect.
	    let s:individualReplace = {'count': 0, 'lines': 0}
		" Note: Use :silent to avoid the intermediate reporting.
		silent execute l:range 'call s:IndividualSubstitute(s:locationRestriction, s:substitution)'

		" And do the reporting on the accummulated statistics later.
		call s:Report(s:individualReplace.count, s:individualReplace.lines)
	    unlet s:individualReplace
	else
	    if s:Substitute(l:range, s:locationRestriction, s:substitution) == 0
		execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	    endif
	endif
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#msg#VimExceptionMsg()
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
    endtry

    silent! call       repeat#set(a:repeatMapping)
    silent! call visualrepeat#set(a:visualrepeatMapping)
endfunction

function! ChangeGlobally#VisualMode()
    let l:keys = "1v\<Esc>"
    silent! let l:keys = visualrepeat#reapply#VisualMode(0)
    return l:keys
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
