" ChangeGlobally.vim: Change {motion} text and repeat the substitution.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"   - repeat.vim (vimscript #2136) plugin (optional)
"   - visualrepeat.vim (vimscript #3848) plugin (optional)
"
" Copyright: (C) 2012-2020 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! ChangeGlobally#SetParameters( isDelete, count, isVisualMode, repeatMapping, visualrepeatMapping, ... )
    let s:pos = getpos('.')
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
function! s:GetChangedText( command ) abort
    " Need special case for "_ to still obtain the deleted text (without
    " permanently clobbering the register).
    if s:register ==# '_'
	return ingo#register#KeepRegisterExecuteOrFunc('execute "normal! ' . a:command . '" | return getreg("\"")')
    else
	execute 'normal! "' . s:register . a:command
	return getreg(s:register)
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
    let l:changedText = s:GetChangedText(s:isDelete ? 'y' : (s:range ==# 'line' ? 'd' : "s$\<BS>\<Esc>"))

    let l:search = '\C' . ingo#regexp#EscapeLiteralText(l:changedText, '/')
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

	call s:OperatorFinally()
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
function! s:GoToSource( sourcePattern ) abort
    if empty(a:sourcePattern)
	" Assume visual selection.
	let [l:lnum, l:col] = ingo#selection#GetExclusiveEndPos()[1:2]
	return [1, (len(getline(l:lnum)) == l:col - 1)]
    endif

    call setpos('.', s:pos)
    " Like * and <cword>, search forward within the current line if not yet on
    " the source.
    if search(a:sourcePattern, 'cW', line('.')) > 0
	return [1, (search('\%#' . a:sourcePattern . '\+$', 'cnW', line('.')) > 0)]
    else
	return [0, 0]
    endif
endfunction
function! ChangeGlobally#WholeWordSourceOperatorTarget( type )
    call s:GivenSourceOperatorTarget('\k', 'iw', function('ingo#regexp#MakeWholeWordSearch'), a:type)
endfunction
function! ChangeGlobally#WordSourceOperatorTarget( type )
    call s:GivenSourceOperatorTarget('\k', 'iw', '', a:type)
endfunction
function! ChangeGlobally#WholeWORDSourceOperatorTarget( type )
    call s:GivenSourceOperatorTarget('\S', 'iW', function('ingo#regexp#MakeWholeWORDSearch'), a:type)
endfunction
function! ChangeGlobally#WORDSourceOperatorTarget( type )
    call s:GivenSourceOperatorTarget('\S', 'iW', '', a:type)
endfunction
function! ChangeGlobally#OperatorSourceOperatorTarget( type )
    " Record the {motion} (don't use visual mode; that would prevent the user
    " from using "gv" as the target operator!), then follow the path of changing
    " / deleting the selected text in {motion} text.
    if a:type ==# 'block'
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    endif
    let s:sourceArea = [getpos("'[")[1:2], getpos("']")[1:2], (a:type ==# 'char' ? 'v' : 'V')]

    " The {source-motion} changed the cursor position, but we want the
    " {target-motion} to start from the original one. Fortunately, that already
    " got recorded so we can jump back to it.
    call setpos('.', s:pos)

    " Query the second {target-motion} now. We have to use feedkeys() for that.
    let &opfunc = 'ChangeGlobally#AreaSourceOperatorTarget'
    call feedkeys('g@', 'ni')
endfunction
function! ChangeGlobally#AreaSourceOperatorTarget( type ) abort
    call call('cursor', s:sourceArea[0])
    silent! execute 'normal!' s:sourceArea[2]
    call call('cursor', s:sourceArea[1])
    silent! execute 'normal!' (s:sourceArea[2] ==# 'v' && &selection ==# 'exclusive' ? 'l' : '') . "\<C-\>\<C-n>"
    unlet s:sourceArea

    call ChangeGlobally#SelectionSourceOperatorTarget(a:type)
endfunction
function! ChangeGlobally#SelectionSourceOperatorTarget( type )
    call s:GivenSourceOperatorTarget('', ":normal! gv\<CR>", '', a:type)
endfunction
function! s:GivenSourceOperatorTarget( sourcePattern, sourceTextObject, SourceToPatternFuncref, type )
    let s:range = 'area'
    let s:area = ingo#change#virtcols#Get(a:type)
    let [l:isFound, l:isAtEndOfLine] = s:GoToSource(a:sourcePattern)
    if ! l:isFound
	call ingo#msg#ErrorMsg('No string under cursor')
	call s:OperatorFinally()
	return
    endif

    let l:changedText = s:GetChangedText((s:isDelete ? 'y': 'd') . a:sourceTextObject)
    let l:search = '\C' . ingo#regexp#EscapeLiteralText(l:changedText, '/')
    if ! empty(a:SourceToPatternFuncref)
	let l:search = call(a:SourceToPatternFuncref, [l:changedText, l:search])
    endif

    " Only apply the substitution [count] times within the area covered by
    " {[target-]motion}. For that, we also need a replace-expression here.
    " As we need to do the evaluation and actual replacement in two stages, and
    " the hook can only inspect the l:replace value, pass the second stage as a
    " quoted argument.
    let l:replace = '\=ChangeGlobally#CountedAreaReplace("ChangeGlobally#AreaReplaceSecondPass()")'

    if s:isDelete
	" For a global deletion, we don't need to set up and go to insert mode;
	" just record what got deleted, and reapply that.

	" Not needed for deletion.
	let s:originalChangeNr = -1
	let s:insertStartPos = [0,0]

	call s:OperatorFinally()
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
function! ChangeGlobally#RepeatOperatorTarget( type )
    let s:range = 'area'
    let s:area = ingo#change#virtcols#Get(a:type)

    let l:range = s:area.startLnum . ',' . s:area.endLnum
    if s:Substitute(l:range, s:locationRestriction, s:substitution) == 0
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
    endif
endfunction
function! ChangeGlobally#VisualRepeat()
    let s:range = 'area'
    let s:area = ingo#selection#virtcols#Get()

    let l:range = s:area.startLnum . ',' . s:area.endLnum
    if s:Substitute(l:range, s:locationRestriction, s:substitution) == 0
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
    endif

    " From now on, normal mode repeat does not target the g@ area, but a
    " same-sized visual selection. To obtain that, we have to change the repeat
    " mapping.
    silent! call repeat#set("\<Plug>(ChangeAreaVisualRepeat)")
endfunction
function! ChangeGlobally#OperatorExpression( opfunc )
    let s:save_visualarea = [getpos("'<"), getpos("'>"), visualmode()]
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
function! s:OperatorFinally() abort
    if exists('s:save_visualarea')
	call call('ingo#selection#Set', s:save_visualarea)
	unlet s:save_visualarea
    endif
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
    let s:lastReplacementDecisions = []
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
function! s:IsInsideArea( lnum, startVirtCol, endVirtCol ) abort
    if s:area.mode ==# 'v'
	return
	\   (a:lnum > s:area.startLnum && a:lnum < s:area.endLnum) ||
	\   (a:lnum == s:area.startLnum && a:startVirtCol >= s:area.startVirtCol) ||
	\   (a:lnum == s:area.endLnum && a:endVirtCol <= s:area.effectiveEndVirtCol)
    elseif s:area.mode ==# 'V'
	return (a:lnum >= s:area.startLnum && a:lnum <= s:area.endLnum)
    else
	return
	\   (a:lnum >= s:area.startLnum && a:lnum <= s:area.endLnum) &&
	\   (a:startVirtCol >= s:area.startVirtCol && a:endVirtCol <= s:area.effectiveEndVirtCol)
    endif
endfunction
function! ChangeGlobally#CountedAreaReplace( ... )
    if (! s:count || s:lastReplaceCnt < s:count) &&
    \   s:IsInsideArea(line('.'), virtcol('.'), virtcol('.') + ingo#compat#strdisplaywidth(submatch(0), virtcol('.') - 1) - 1)
	let s:lastReplaceCnt += 1
	let s:lastReplacementLnum = line('.')
	let s:lastReplacementLines[line('.')] = 1

	" Doing the replacement now would affect all further area inclusion
	" tests. Therefore, just record the decision now and do the actual
	" replacement in a second pass in
	" ChangeGlobally#AreaReplaceSecondPass().
	call add(s:lastReplacementDecisions, 1)
    else
	call add(s:lastReplacementDecisions, 0)
    endif
    return submatch(0)
endfunction
function! ChangeGlobally#AreaReplaceSecondPass() abort
    return (remove(s:lastReplacementDecisions, 0) ? s:newText : submatch(0))
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
    if s:count || s:range ==# 'area'
	" It would be nice if we could abort the :substitution when the
	" s:lastReplaceCnt has been reached. Unfortunately, throwing an
	" exception from ChangeGlobally#CountedReplace() will still substitute
	" with an empty string, so we cannot use that. Instead, we have the line
	" number recorded and jump back to the line with the last substitution.
	" Because of this, the "N substitutions on M lines" will also be wrong.
	" We have to suppress the original message and emulate that, too.
	silent execute l:substitutionCommand

	if s:lastReplaceCnt > 0 && a:substitutionArguments[4] =~# '=ChangeGlobally#CountedAreaReplace('
	    " The area replacement only records the locations on the first pass,
	    " to avoid modifying the size of the area. (We cannot use the trick
	    " of doing the replacements from last to first with :substitute.)
	    " Do the replacements only in a second pass (this time without the
	    " :s_c confirm flag).
	    let l:secondPassSubstitutionArguments = copy(a:substitutionArguments)
	    " Extract the dummy quoted function call (that is ignored by
	    " ChangeGlobally#CountedAreaReplace(), but needs to be passed so
	    " that the hook can replace it) and call that one now.
	    let l:secondPassSubstitutionArguments[4] = '\=' . matchstr(l:secondPassSubstitutionArguments[4], '^.*(\([''"]\)\zs.*\ze\1)$')
	    let l:secondPassSubstitutionArguments[-1] = ingo#str#trd(l:secondPassSubstitutionArguments[-1], 'c')
	    let l:substitutionCommand = a:range . 'substitute/' . a:localRestriction . join(l:secondPassSubstitutionArguments, '') . 'e'
	    silent execute l:substitutionCommand
	endif

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

	" To turn the change and following substitutions into a single change,
	" first undo the deletion and insertion. (I couldn't get them combined
	" with :undojoin across the :startinsert.)
	" This also solves the special case when the changed text is contained
	" in s:newText; without the undo, we would need to avoid re-applying the
	" substitution over the just changed part of the line.
	if ! l:hasAbortedInsert
	    execute 'silent undo' s:originalChangeNr | " undo the insertion of s:newText
	endif
	silent undo " the deletion of the changed text
    endif
"****D echomsg '****' string(s:insertStartPos) string(getpos("'[")) string(getpos("']")) string(@.)
"****D echomsg '**** subst' string(a:search) string(@.) string(s:newText)
    " For :substitute, we need to convert newlines in both parts (differently).
    let l:search = a:search
    let l:replace = a:replace

    call s:OperatorFinally()


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
	    let s:substitution = ['^', substitute(l:search, '\\n$', '', ''), '$', '/', l:replace, '/', (s:isConfirm ? 'c' : '')]
	endif

	let l:range = (s:count ? '.,$' : '%')
    elseif s:range ==# 'area'
	let s:substitution = ['', l:search, '', '/', l:replace, '/', 'g' . (s:isConfirm ? 'c' : '')]
	let l:range = s:area.startLnum . ',' . s:area.endLnum
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
