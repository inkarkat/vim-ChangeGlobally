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

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_ChangeGlobally') || (v:version < 700)
    finish
endif
let g:loaded_ChangeGlobally = 1
let s:save_cpo = &cpo
set cpo&vim

nnoremap <silent> <expr> <Plug>(ChangeGlobally) ChangeGlobally#OperatorExpression()
if ! hasmapto('<Plug>(ChangeGlobally)', 'n')
    nmap gc <Plug>(ChangeGlobally)
endif

vnoremap <silent> <Plug>(ChangeGlobally) :<C-u>call setline('.', getline('.'))<Bar>call ChangeGlobally#SetRegister()<Bar>call ChangeGlobally#Operator(visualmode())<CR>
if ! hasmapto('<Plug>(ChangeGlobally)', 'v')
    xmap gc <Plug>(ChangeGlobally)
endif



nnoremap <silent> <Plug>(ChangeGloballyRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#Repeat(0)<CR>

vnoremap <silent> <Plug>(ChangeGloballyVisualRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\call ChangeGlobally#Repeat(1)<CR>

" A normal-mode repeat of the visual mapping is triggered by repeat.vim. It
" establishes a new selection at the cursor position, of the same mode and size
" as the last selection.
"   If [count] is given, the size is multiplied accordingly. This has the side
"   effect that a repeat with [count] will persist the expanded size, which is
"   different from what the normal-mode repeat does (it keeps the scope of the
"   original command).
nnoremap <silent> <Plug>(ChangeGloballyVisualRepeat)
\ :<C-u>call setline('.', getline('.'))<Bar>
\execute 'normal!' v:count1 . 'v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : ''). "\<lt>Esc>"<Bar>
\call ChangeGlobally#Repeat(1)<CR>

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
