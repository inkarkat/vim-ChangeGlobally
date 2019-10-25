" ChangeGlobally.vim: Change {motion} text and repeat the substitution.
"
" DEPENDENCIES:
"   - ChangeGlobally.vim autoload script
"
" Copyright: (C) 2012-2019 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>

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

nnoremap <silent> <expr> <SID>(ChangeGloballyOperator) ChangeGlobally#OperatorExpression('ChangeGlobally#SourceOperator')
nnoremap <silent> <script> <Plug>(ChangeGloballyOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<CR><SID>(ChangeGloballyOperator)
if ! hasmapto('<Plug>(ChangeGloballyOperator)', 'n')
    nmap gc <Plug>(ChangeGloballyOperator)
endif
nnoremap <silent> <Plug>(ChangeGloballyLine)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(0, 0, 0, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>
\call ChangeGlobally#SourceOperator('V')<CR>
if ! hasmapto('<Plug>(ChangeGloballyLine)', 'n')
    nmap gcc <Plug>(ChangeGloballyLine)
endif

vnoremap <silent> <Plug>(ChangeGloballyVisual)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(0, v:count, 1, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\call ChangeGlobally#SourceOperator(visualmode())<CR>
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
\call ChangeGlobally#SourceOperator('V')<CR>
if ! hasmapto('<Plug>(DeleteGloballyLine)', 'n')
    nmap gxx <Plug>(DeleteGloballyLine)
endif

vnoremap <silent> <Plug>(DeleteGloballyVisual)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#SetParameters(1, v:count, 1, "\<lt>Plug>(ChangeGloballyRepeat)", "\<lt>Plug>(ChangeGloballyVisualRepeat)")<Bar>
\call ChangeGlobally#SourceOperator(visualmode())<CR>
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
