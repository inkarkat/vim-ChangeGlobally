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

" Change moved-over text / selection globally.

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



" Change current word / WORD / selection / moved-over text over the moved-over area.

nnoremap <silent> <expr> <SID>(ChangeWholeWordOperator) ChangeGlobally#OperatorExpression('ChangeGlobally#WholeWordSourceOperatorTarget')
nnoremap <silent> <script> <Plug>(ChangeWholeWordOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeAreaCannotRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWholeWordOperator)
if ! hasmapto('<Plug>(ChangeWholeWordOperator)', 'n')
    nmap gc* <Plug>(ChangeWholeWordOperator)
endif
nnoremap <silent> <script> <Plug>(DeleteWholeWordOperator) :<C-u>call ChangeGlobally#SetParameters(1, v:count, 0, "\<lt>Plug>(ChangeAreaRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWholeWordOperator)
if ! hasmapto('<Plug>(DeleteWholeWordOperator)', 'n')
    nmap gx* <Plug>(DeleteWholeWordOperator)
endif

nnoremap <silent> <expr> <SID>(ChangeWordOperator) ChangeGlobally#OperatorExpression('ChangeGlobally#WordSourceOperatorTarget')
nnoremap <silent> <script> <Plug>(ChangeWordOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeAreaCannotRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWordOperator)
if ! hasmapto('<Plug>(ChangeWordOperator)', 'n')
    nmap gcg* <Plug>(ChangeWordOperator)
endif
nnoremap <silent> <script> <Plug>(DeleteWordOperator) :<C-u>call ChangeGlobally#SetParameters(1, v:count, 0, "\<lt>Plug>(ChangeAreaRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWordOperator)
if ! hasmapto('<Plug>(DeleteWordOperator)', 'n')
    nmap gxg* <Plug>(DeleteWordOperator)
endif

nnoremap <silent> <expr> <SID>(ChangeWholeWORDOperator) ChangeGlobally#OperatorExpression('ChangeGlobally#WholeWORDSourceOperatorTarget')
nnoremap <silent> <script> <Plug>(ChangeWholeWORDOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeAreaCannotRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWholeWORDOperator)
if ! hasmapto('<Plug>(ChangeWholeWORDOperator)', 'n')
    nmap gc<A-8> <Plug>(ChangeWholeWORDOperator)
endif
nnoremap <silent> <script> <Plug>(DeleteWholeWORDOperator) :<C-u>call ChangeGlobally#SetParameters(1, v:count, 0, "\<lt>Plug>(ChangeAreaRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWholeWORDOperator)
if ! hasmapto('<Plug>(DeleteWholeWORDOperator)', 'n')
    nmap gx<A-8> <Plug>(DeleteWholeWORDOperator)
endif

nnoremap <silent> <expr> <SID>(ChangeWORDOperator) ChangeGlobally#OperatorExpression('ChangeGlobally#WORDSourceOperatorTarget')
nnoremap <silent> <script> <Plug>(ChangeWORDOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeAreaCannotRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWORDOperator)
if ! hasmapto('<Plug>(ChangeWORDOperator)', 'n')
    nmap gcg<A-8> <Plug>(ChangeWORDOperator)
endif
nnoremap <silent> <script> <Plug>(DeleteWORDOperator) :<C-u>call ChangeGlobally#SetParameters(1, v:count, 0, "\<lt>Plug>(ChangeAreaRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeWORDOperator)
if ! hasmapto('<Plug>(DeleteWORDOperator)', 'n')
    nmap gxg<A-8> <Plug>(DeleteWORDOperator)
endif


nnoremap <silent> <expr> <SID>(ChangeOperatorOperator) ChangeGlobally#OperatorExpression('ChangeGlobally#OperatorSourceOperatorTarget')
nnoremap <silent> <script> <Plug>(ChangeOperatorOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeAreaCannotRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeOperatorOperator)
if ! hasmapto('<Plug>(ChangeOperatorOperator)', 'n')
    nmap <Leader>gc <Plug>(ChangeOperatorOperator)
endif
nnoremap <silent> <script> <Plug>(DeleteOperatorOperator) :<C-u>call ChangeGlobally#SetParameters(1, v:count, 0, "\<lt>Plug>(ChangeAreaRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeOperatorOperator)
if ! hasmapto('<Plug>(DeleteOperatorOperator)', 'n')
    nmap <Leader>gx <Plug>(DeleteOperatorOperator)
endif

nnoremap <silent> <expr> <SID>(ChangeSelectionOperator) ChangeGlobally#OperatorExpression('ChangeGlobally#SelectionSourceOperatorTarget')
vnoremap <silent> <script> <Plug>(ChangeSelectionOperator) :<C-u>call ChangeGlobally#SetParameters(0, v:count, 0, "\<lt>Plug>(ChangeAreaCannotRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeSelectionOperator)
if ! hasmapto('<Plug>(ChangeSelectionOperator)', 'v')
    xmap <Leader>gc <Plug>(ChangeSelectionOperator)
endif
vnoremap <silent> <script> <Plug>(DeleteSelectionOperator) :<C-u>call ChangeGlobally#SetParameters(1, v:count, 0, "\<lt>Plug>(ChangeAreaRepeat)", "\<lt>Plug>(ChangeAreaVisualRepeat)")<CR><SID>(ChangeSelectionOperator)
if ! hasmapto('<Plug>(DeleteSelectionOperator)', 'v')
    xmap <Leader>gx <Plug>(DeleteSelectionOperator)
endif


" Vim is able to repeat the g@ on its own; however, we need to re-use the
" previous source text and just repeat the substitute on the new area, so a
" different opfunc just runs pieces of the logic.
nnoremap <silent> <Plug>(ChangeAreaRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\let &opfunc = 'ChangeGlobally#RepeatOperatorTarget'<Bar>normal! .<CR>
" Unfortunately, this only works for delete; for change, the text editing itself
" is the last command that gets repeated; the original {motion} got lost. All we
" can do is thwart the native repeat (i.e. insert of the text at the current
" position) and give a hint.
nnoremap <silent> <Plug>(ChangeAreaCannotRepeat)
\ :execute "normal! \<lt>C-\>\<lt>C-n>\<lt>Esc>"<Bar>
\echomsg 'Cannot repeat on the same {motion}' . (exists('g:loaded_visualrepeat') && g:loaded_visualrepeat ? '; select the new target area and repeat from visual mode instead' : '')<CR>
" Repeat in visual mode applies the same substitution to the selection.
vnoremap <silent> <Plug>(ChangeAreaVisualRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#VisualRepeat()<CR>
" After a visual mode repeat has been made, normal mode repeats target a
" same-sized selection at the current position.
nnoremap <silent> <Plug>(ChangeAreaVisualRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\execute 'normal!' ChangeGlobally#VisualMode()<Bar>
\call ChangeGlobally#VisualRepeat()<CR>

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
