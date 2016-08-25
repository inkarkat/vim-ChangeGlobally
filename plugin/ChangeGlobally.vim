" ChangeGlobally.vim: Change {motion} text and repeat the substitution.
"
" DEPENDENCIES:
"   - ChangeGlobally.vim autoload script
"
" Copyright: (C) 2012-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.31.007	26-Aug-2016	Add g:ChangeGlobally_LimitToCurrentLineCount
"				configuration.
"   1.30.006	16-Jun-2014	ENH: Implement global delete as a specialization
"				of an empty change.
"				Add a:isDelete flag to
"				ChangeGlobally#SetParameters().
"				Define duplicate delete mappings, with a default
"				mapping to gx instead of gc.
"   1.21.005	22-Apr-2014	Add g:ChangeGlobally_ConfirmCount configuration.
"   1.20.004	18-Apr-2013	Use optional visualrepeat#reapply#VisualMode()
"				for normal mode repeat of a visual mapping.
"				When supplying a [count] on such repeat of a
"				previous linewise selection, now [count] number
"				of lines instead of [count] times the original
"				selection is used.
"   1.00.003	25-Sep-2012	Add g:ChangeGlobally_GlobalCountThreshold
"				configuration.
"				Merge ChangeGlobally#SetCount() and
"				ChangeGlobally#SetRegister() into
"				ChangeGlobally#SetParameters() and pass in
"				visual mode flag.
"				Inject the [visual]repeat mappings from the
"				original mappings (via
"				ChangeGlobally#SetParameters()) instead of
"				hard-coding them in the functions, so that
"				the functions can be re-used for similar
"				(SmartCase) substitutions.
"	002	21-Sep-2012	ENH: Use [count] before the operator and in
"				visual mode to specify the number of
"				substitutions that should be made.
"				Call ChangeGlobally#SetCount() to record it.
"	001	28-Aug-2012	file creation

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_ChangeGlobally') || (v:version < 700)
    finish
endif
let g:loaded_ChangeGlobally = 1
let s:save_cpo = &cpo
set cpo&vim

"- configuration ---------------------------------------------------------------

if ! exists('g:ChangeGlobally_GlobalCountThreshold')
    let g:ChangeGlobally_GlobalCountThreshold = 999
endif
if ! exists('g:ChangeGlobally_ConfirmCount')
    let g:ChangeGlobally_ConfirmCount = 888
endif
if ! exists('g:ChangeGlobally_LimitToCurrentLineCount')
    let g:ChangeGlobally_LimitToCurrentLineCount = 99
endif


"- mappings --------------------------------------------------------------------

nnoremap <silent> <expr> <SID>(ChangeGloballyOperator) ChangeGlobally#OperatorExpression()
nnoremap <silent> <script> <Plug>(ChangeGloballyOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR><SID>(ChangeGloballyOperator)
if ! hasmapto('<Plug>(ChangeGloballyOperator)', 'n')
    nmap gc <Plug>(ChangeGloballyOperator)
endif
nnoremap <silent> <Plug>(ChangeGloballyLine)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(0, 0, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>
\call ChangeGlobally#Operator('V')<CR>
if ! hasmapto('<Plug>(ChangeGloballyLine)', 'n')
    nmap gcc <Plug>(ChangeGloballyLine)
endif

vnoremap <silent> <Plug>(ChangeGloballyVisual)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(0, v:count, 1, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\call ChangeGlobally#Operator(visualmode())<CR>
if ! hasmapto('<Plug>(ChangeGloballyVisual)', 'x')
    xmap gc <Plug>(ChangeGloballyVisual)
endif



nnoremap <silent> <script> <Plug>(DeleteGloballyOperator) :<C-u>call ChangeGlobally#SetParameters(1, v:count, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR><SID>(ChangeGloballyOperator)
if ! hasmapto('<Plug>(DeleteGloballyOperator)', 'n')
    nmap gx <Plug>(DeleteGloballyOperator)
endif
nnoremap <silent> <Plug>(DeleteGloballyLine)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(1, 0, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>
\call ChangeGlobally#Operator('V')<CR>
if ! hasmapto('<Plug>(DeleteGloballyLine)', 'n')
    nmap gxx <Plug>(DeleteGloballyLine)
endif

vnoremap <silent> <Plug>(DeleteGloballyVisual)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(1, v:count, 1, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\call ChangeGlobally#Operator(visualmode())<CR>
if ! hasmapto('<Plug>(DeleteGloballyVisual)', 'x')
    xmap gx <Plug>(DeleteGloballyVisual)
endif



nnoremap <silent> <Plug>(ChangeGloballyRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#Repeat(0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR>

vnoremap <silent> <Plug>(ChangeGloballyVisualRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#Repeat(1, "\<lt>Plug>(ChangeGloballyVisualRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR>

" A normal-mode repeat of the visual mapping is triggered by repeat.vim. It
" establishes a new selection at the cursor position, of the same mode and size
" as the last selection.
" Note: The cursor is placed back at the beginning of the selection (via "o"),
" so in case the repeat substitutions fails, the cursor will stay at the current
" position instead of moving to the end of the selection.
" If [count] is given, the size is multiplied accordingly. This has the side
" effect that a repeat with [count] will persist the expanded size, which is
" different from what the normal-mode repeat does (it keeps the scope of the
" original command).
nnoremap <silent> <Plug>(ChangeGloballyVisualRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\execute 'normal!' ChangeGlobally#VisualMode()<Bar>
\call ChangeGlobally#Repeat(1, "\<lt>Plug>(ChangeGloballyVisualRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR>

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
