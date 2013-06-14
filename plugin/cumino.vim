" ============================================================================
" File: cumino.vim
" Description: vim plugin to call tmux
" Maintainer: Alfredo Di Napoli <?@?.com>
" License: ??
" Notes: ??
"
" ============================================================================


if v:version < 700
    echohl WarningMsg
    echomsg 'Cumino: Vim version is too old, Cumino requires at least 7.0'
    echohl None
    finish
endif

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

if !has("python") && !executable("python")
  finish
endif

if !executable("tmux")
  finish
endif

" Default variables
" See TODO
if !exists("g:cumino_default_terminal")
  let g:cumino_default_terminal = "xterm"
  if executable("urxvt")
    let g:cumino_default_terminal = "urxvt"
  endif
endif

if !exists("g:cumino_buffer_location")
  let g:cumino_buffer_location =
        \ substitute(system("echo $HOME"), "\n", "", "g") . "/.cumino.buff"
endif

if !exists("g:cumino_ghci_args")
  let g:cumino_ghci_args = ""
endif

if !exists("g:cumino_use_hsenv")
  let g:cumino_use_hsenv = 1
endif

" Used to infer whether call :load or simply :r
let g:cumino_module_loaded = {}


" Public Interface:
"

" Commands {{{1
command! -nargs=0 -bar CuminoConnect
            \ call cumino#CuminoConnect()
command! -nargs=0 -bar CuminoEvalBuffer
            \ call cumino#CuminoEvalBuffer()
command! -nargs=0 -bar CuminoEvalVisual
            \ call cumino#CuminoEvalVisual()
command! -nargs=0 -bar CuminoShowTypeUnderTheCursor
            \ call cumino#CuminoShowTypeUnderTheCursor()
command! -nargs=0 -bar CuminoSendToGhci
            \ call cumino#CuminoSendToGhci()


" Mnemonic: cumino Connect
"
if !hasmapto('<Plug>CuminoConnect')
  map <unique> <LocalLeader>cc <Plug>CuminoConnect
endif

" Mnemonic: cumino (Eval) Buffer
"
if !hasmapto('<Plug>CuminoEvalBuffer')
  map <unique> <LocalLeader>cb <Plug>CuminoEvalBuffer
endif

" Mnemonic: cumino (Eval) Visual (Selection)
"
if !hasmapto('<Plug>CuminoEvalVisual')
  map <unique> <LocalLeader>cv <Plug>CuminoEvalVisual
endif

" Mnemonic: cumino (Show) Type
"
if !hasmapto('<Plug>CuminoShowTypeUnderTheCursor')
  map <unique> <LocalLeader>ct <Plug>CuminoShowTypeUnderTheCursor
endif

" Mnemonic: cumino Send
"
if !hasmapto('<Plug>CuminoSendToGhci')
  map <unique> <LocalLeader>cs <Plug>CuminoSendToGhci
endif


" Global (Mnemonic) Maps:
" {{{1
noremap <unique> <silent> <Plug>CuminoConnect
            \ :CuminoConnect<CR>
      ""\ :call cumino#CuminoConnect()<RETURN>
noremap <unique> <silent> <Plug>CuminoEvalBuffer
            \ :CuminoEvalBuffer<CR>
      ""\ :call <SID>CuminoEvalBuffer()<RETURN>
noremap <unique> <silent> <Plug>CuminoEvalVisual
            \ :CuminoEvalVisual<CR>
      ""\ :call <SID>CuminoEvalVisual()<RETURN>
noremap <unique> <silent> <Plug>CuminoShowTypeUnderTheCursor
            \ :CuminoShowTypeUnderTheCursor<CR>
      ""\ :call <SID>CuminoShowTypeUnderTheCursor()<RETURN>
noremap <unique> <silent> <Plug>CuminoSendToGhci
            \ :CuminoSendToGhci<CR>
      ""\ :call <SID>CuminoSendToGhci()<RETURN>


" Kill cumino before exiting Vim
autocmd VimLeavePre * call <SID>CuminoCloseSession()

" vim: set et sts=4 sw=4:
