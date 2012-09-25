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


"- mappings --------------------------------------------------------------------

nnoremap <silent> <expr> <SID>(ChangeGloballyOperator) ChangeGlobally#OperatorExpression()
nnoremap <silent> <script> <Plug>(ChangeGloballyOperator) :<C-u>call ChangeGlobally#SetParameters(v:count, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR><SID>(ChangeGloballyOperator)
if ! hasmapto('<Plug>(ChangeGloballyOperator)', 'n')
    nmap gc <Plug>(ChangeGloballyOperator)
endif
nnoremap <silent> <Plug>(ChangeGloballyLine)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(0, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>
\call ChangeGlobally#Operator('V')<CR>
if ! hasmapto('<Plug>(ChangeGloballyLine)', 'n')
    nmap gcc <Plug>(ChangeGloballyLine)
endif

vnoremap <silent> <Plug>(ChangeGloballyVisual)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(v:count, 1, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\call ChangeGlobally#Operator(visualmode())<CR>
if ! hasmapto('<Plug>(ChangeGloballyVisual)', 'v')
    xmap gc <Plug>(ChangeGloballyVisual)
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
\execute 'normal!' v:count1 . 'v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : ''). "o\<lt>Esc>"<Bar>
\call ChangeGlobally#Repeat(1, "\<lt>Plug>(ChangeGloballyVisualRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR>

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
