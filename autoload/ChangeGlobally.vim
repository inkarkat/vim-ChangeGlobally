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
" Copyright: (C) 2012-2014 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.21.018	23-Apr-2014	Add proper version guard for the \n with :s_c
"				flag workaround after finding the precise
"				offending patch and having a patch that fixes
"				it.
"   1.21.017	23-Apr-2014	Make g:ChangeGlobally_ConfirmCount have
"				precedence over
"				g:ChangeGlobally_GlobalCountThreshold; as the
"				former may lie inside the latter.
"   1.21.016	22-Apr-2014	FIX: Disable global substitution when
"				g:ChangeGlobally_GlobalCountThreshold is 0, as
"				is documented.
"				ENH: Confirm each replacement via :s_c flag when
"				a special g:ChangeGlobally_ConfirmCount is
"				given.
"   1.20.015	23-Jul-2013	Move ingointegration#GetText() into
"				ingo-library.
"   1.20.014	14-Jun-2013	Use ingo/msg.vim.
"   1.20.013	06-Jun-2013	Simplify \%V end-match pattern.
"   1.20.012	23-May-2013	For \%V to work on a zero-width block selection
"				with :set selection=exclusive, a special case
"				(provided by the ingo-library) must be applied.
"   1.20.011	19-Apr-2013	ENH: Special handling for repeat on blockwise
"				selection that makes more sense.
"				Separate components of a:substitutionArguments
"				into a List that is join()ed together in
"				s:Substitute().
"				Stop duplicating s:count into l:replace and
"				instead access directly from
"				ChangeGlobally#CountedReplace().
"				Drop unnecessary empty check for s:substitution.
"   1.20.010	18-Apr-2013	Add ChangeGlobally#VisualMode() wrapper around
"				visualrepeat#reapply#VisualMode().
"   1.11.009	10-Apr-2013	Move s:IsKeywordMatch() into ingo-library.
"   1.11.008	22-Mar-2013	Autocmds may interfere with the plugin when they
"				temporarily leave insert mode (i_CTRL-O) or
"				create an undo point (i_CTRL-G_u). Disable them
"				until the user is done inserting.
"   1.11.007	21-Mar-2013	Avoid changing the jumplist.
"   1.10.006	19-Jan-2013	Use change number instead of the flaky
"				comparison with captured previous inserted text.
"				ENH: Handle undo points created during
"				insertion: Undo the whole insertion sequence (by
"				using :undo with the original change number) and
"				substitute the entire captured insertion, not
"				just the last part, by detecting a multi-change
"				insert and using the original start position
"				instead of the start change mark.
"   1.01.005	19-Jan-2013	BUG: Linewise changes (gcc) causes beep instead
"				of substitution. The refactoring for
"				ChangeGloballySmartCase.vim moved \V\C into
"				l:search, so the start-of-line atom that comes
"				before it must be written as ^, not \^.
"   1.00.004	25-Sep-2012	Add g:ChangeGlobally_GlobalCountThreshold
"				configuration.
"				Merge ChangeGlobally#SetCount() and
"				ChangeGlobally#SetRegister() into
"				ChangeGlobally#SetParameters() and pass in
"				visual mode flag.
"				CHG: Do not check for keyword boundaries for the
"				visual mode mapping; this is consistent with my
"				custom visual-mode * mapping and it can be used
"				to turn off the keyword substitution when it is
"				not desired.
"				Inject the [visual]repeat mappings from the
"				original mappings (via
"				ChangeGlobally#SetParameters()) instead of
"				hard-coding them in the functions, so that
"				the functions can be re-used for similar
"				(SmartCase) substitutions.
"				Allow manipulation of the substitution arguments
"				via s:SubstitutionHook to facilitate easy reuse,
"				especially for a similar SmartCase substitution.
"	003	21-Sep-2012	ENH: Use [count] before the operator and in
"				visual mode to specify the number of
"				substitutions that should be made.
"				Add ChangeGlobally#SetParameters() to record it.
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
"				ENH: When the changed text is surrounded by
"				keyword boundaries, make the substitution for
"				s/\<changedText\>/ to avoid false matches.
"				Always perform a case-sensitive match (/\C/),
"				regardless of 'ignorecase'.
"				ENH: Beep when no additional substitutions have
"				been made.
"	002	01-Sep-2012	Switch from CompleteHelper#ExtractText() to
"				ingointegration#GetText().
"	001	28-Aug-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ChangeGlobally#SetParameters( count, isVisualMode, repeatMapping, visualrepeatMapping, ... )
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
function! s:ArmInsertMode()
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
	autocmd! InsertLeave * call ChangeGlobally#UnarmInsertMode() | call ChangeGlobally#Substitute()
    augroup END
endfunction
function! ChangeGlobally#UnarmInsertMode()
    autocmd! ChangeGlobally

    if exists('s:save_eventignore')
	let &eventignore = s:save_eventignore
	unlet s:save_eventignore
    endif
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
    let l:deleteCommand = (s:range ==# 'line' ? 'd' : "s$\<BS>\<Esc>")

    " TODO: Special case for "_
    execute 'normal! "' . s:register . l:deleteCommand

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
    call s:ArmInsertMode()
endfunction
function! ChangeGlobally#OperatorExpression()
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
function! ChangeGlobally#Substitute()
    let l:changeStartVirtCol = virtcol("'[") " Need to save this, both :undo and the check substitution will set the column to 1.

    let l:hasAbortedInsert = changenr() <= s:originalChangeNr
    let l:isMultiChangeInsert = (changenr() > s:originalChangeNr + 1)
"****D echomsg '****' string(s:insertStartPos) string(getpos("'[")) string(getpos("']")) string(@.) l:hasAbortedInsert l:isMultiChangeInsert
    let l:changedText = getreg(s:register)
    let s:newText = s:GetInsertion(s:range, l:isMultiChangeInsert)
    if v:version == 703 && has('patch225') || v:version == 704 && ! has('patch261')
	" XXX: Vim inserts \n == ^@ literally when the :s_c confirm flag is
	" given. Convert to \r to work around this.
	let s:newText = substitute(s:newText, '\n', '\r', 'g')
    endif
"****D echomsg '**** subst' string(l:changedText) string(@.) string(s:newText)
    " For :substitute, we need to convert newlines in both parts (differently).
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


    " To turn the change and following substitutions into a single change, first
    " undo the deletion and insertion. (I couldn't get them combined with
    " :undojoin across the :startinsert.)
    " This also solves the special case when l:changedText is contained in
    " s:newText; without the undo, we would need to avoid re-applying the
    " substitution over the just changed part of the line.
    if ! l:hasAbortedInsert
	execute 'silent undo' s:originalChangeNr | " undo the insertion of s:newText
    endif
    silent undo " the deletion of l:changedText


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
    if s:range ==# 'line'
	if ! s:isVisualMode && ingo#search#buffer#IsKeywordMatch(l:changedText, l:changeStartVirtCol)
	    " When the changed text is surrounded by keyword boundaries, only
	    " perform keyword replacements to avoid replacing other matches
	    " inside keywords (e.g. "in" inside "ring").
	    let l:search = '\<' . l:search . '\>'
	endif

	" Check whether more than one substitution can be made in the line to
	" determine whether the substitution should be applied to the line or
	" beyond.
	let l:isBeyondLineSubstitution = (s:isForceGlobal || s:CountMatches(l:search) == 1)

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
	let l:range = (l:isBeyondLineSubstitution ? l:beyondLineRange : "'[,']")
    elseif s:range ==# 'buffer'
	" We need to remove the trailing newline in the search pattern and
	" anchor the search to the beginning and end of a line, so that only
	" entire lines are substituted. Were we to alternatively append a \r to
	" the replacement, the next line would be involved and the cursor
	" misplaced.
	let s:substitution = ['^', substitute(l:search, '\\n$', '', ''), '\$', '/', l:replace, '/', (s:isConfirm ? 'c' : '')]

	let l:range = (s:count ? '.,$' : '%')
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
	let l:range = (s:range ==# 'line' ? '' : '%')
    endif

    try
	if s:count && s:range ==# 'line'
	    " When we this is substitution inside a line, and the number of
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
    catch /^Vim\%((\a\+)\)\=:E/
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
