" Copyright (C) 2012 Alfredo Di Napoli
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.
"
" Basic init {{{1

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

if !has("python")
  finish
endif

if !executable("tmux")
  finish
endif

" Default variables
" See TODO
if !exists("g:cumino_default_terminal")
  let g:cumino_default_terminal = "xterm"
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


python << EOF
import vim
import os
import subprocess

def write_to_buffer():
  cumino_buff = vim.eval("g:cumino_buffer_location")
  selected_lines = vim.eval("g:selected_text")
  selected_lines = discard_function_declaration(selected_lines)
  selected_lines = append_let_if_function(selected_lines)
  selected_lines = wrap_if_multiline(selected_lines)

  f = open(cumino_buff, "w")

  for line in selected_lines:
    f.write(line)
    f.write(os.linesep)

  f.close()

def discard_function_declaration(lines):
  if contains_function_declaration(lines[0]):
    return lines[1:]
  return lines

def contains_function_declaration(line):
  return line.split(" ")[1] == "::"

def append_let_if_function(lines):

  #For now the dict will be created on-the-fly here.
  #Potentially very slow.

  not_prefixable_keywords = [
    "import", "data", "instance",
    "class", "type", "{-#"
  ]

  is_prefixable = lines[0].split(" ")[0] not in not_prefixable_keywords
  if is_prefixable:
    # We must also ident every other line that follows
    lines[0] = "let " + lines[0]
    for idx in range(1,len(lines)):
      lines[idx] = "    " + lines[idx]

  return lines

def line_starts_with(line, keyword):
  return keyword == line.split(" ")[0]

def wrap_if_multiline(lines):
  # Decide whether wrapping the line with :{ :} or not.
  # Some multilines, for example imports, don't require multiline
  # wrapping
  if len(lines) > 1 and not line_starts_with(lines[0], "import"):
    return [":{"] + lines + [":}"]
  return lines

def cumino_eval_visual():
  write_to_buffer()
  send_buffer_to_tmux()

def send_buffer_to_tmux():
  cumino_buff = vim.eval("g:cumino_buffer_location")
  subprocess.call(["tmux", "load-buffer", cumino_buff ])
  subprocess.call(["tmux", "pasteb", "-t", "cumino"])

def cumino_show_type_under_the_cursor():
  function_name = vim.eval("@z")
  write_to_buffer_raw(":t " + function_name)
  send_buffer_to_tmux()

def cumino_send_to_ghci():
  expr = vim.eval("cmd")
  write_to_buffer_raw(expr)
  send_buffer_to_tmux()

def write_to_buffer_raw(content):
  """
  Same of write_buffer, except that
  write @content without checking it.
  """
  cumino_buff = vim.eval("g:cumino_buffer_location")
  f = open(cumino_buff, "w")

  f.write(content)
  f.write(os.linesep)

  f.close()

def cumino_kill():
  subprocess.call(["tmux", "kill-session", "-t", "cumino"])

EOF

"Connect to repl
fun! CuminoConnect()

  " Allow nested tmux sessions.
  let $TMUX=""

  if CuminoSessionExists()
    "Attach to an already running session
    echo "Connecting to an already running cumino session..."

    if (g:cumino_default_terminal == "urxvt")
      call system(g:cumino_default_terminal ." -e -sh -c \"tmux attach-session -t cumino\" &")
    else
      call system(g:cumino_default_terminal ." -e \"tmux attach-session -t cumino\" &")
    endif

    echo "Connected."

  else

    "Change the cumino owner to be this one
    let g:cumino_owner = getpid()
    echo "Starting a new cumino session..."
    let cmd = g:cumino_default_terminal

    if (g:cumino_default_terminal == "urxvt")
      let cmd .= " -e sh -c \"tmux new-session -s cumino "
    else
      let cmd .= " -e \"tmux new-session -s cumino "
    endif

    let sandbox = GetSandboxActivationStringIfPresent()
    let cmd .= "'".sandbox."ghci ". g:cumino_ghci_args ."'\" &"
    call system(cmd)

  endif
endfun

fun! GetSandboxActivationStringIfPresent()

  if($HSENV != "" && g:cumino_use_hsenv)
    return "export GHC_PACKAGE_PATH=" . $GHC_PACKAGE_PATH . " && "
  else
    return ""
  endif

endfun

fun! CuminoSessionExists()
  let w:sessions = system("tmux list-sessions 2>&1 | grep cumino")
  if (w:sessions != "")
      return 1
  else
    return 0
  endif
endfun

fun! <SID>CuminoEvalBuffer()

  let b:buffer_name = expand("%:p")
  let module_already_loaded = get(g:cumino_module_loaded, b:buffer_name)
  if (!module_already_loaded)
    let b:use_cmd = ":load \"". b:buffer_name ."\""
  else
    let b:use_cmd = ":r"
  endif
  call system("echo \"". escape(b:use_cmd,"\"") ."\" > ". g:cumino_buffer_location)
  if CuminoSessionExists()
    call system("tmux load-buffer ". g:cumino_buffer_location ."; tmux pasteb -t cumino")
    let g:cumino_module_loaded[expand("%:p")] = 1
  endif
endfun

function! s:NumSort(a, b)
    return a:a>a:b ? 1 : a:a==a:b ? 0 : -1
endfunction

function! s:GetVisualSelection()
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  return lines
endfunction

fun! <SID>CuminoEvalVisual() range
  if CuminoSessionExists()
    let g:selected_text = s:GetVisualSelection()
    python cumino_eval_visual()
  endif
endfun

fun! <SID>CuminoShowTypeUnderTheCursor()
  if CuminoSessionExists()
    normal! "zyw
    python cumino_show_type_under_the_cursor()
  endif
endfun

fun! <SID>CuminoSendToGhci()
  if CuminoSessionExists()
    call inputsave()
    let cmd = input('Expr?: ')
    call inputrestore()
    python cumino_send_to_ghci()
  endif
endfun

fun! CuminoCloseSession()
  if CuminoSessionExists()
    if g:cumino_owner == getpid()
      python cumino_kill()
    endif
  endif
endfun


" s:LogDebugMessage() {{{2
function! s:LogDebugMessage(msg) abort
    if s:debug
        let s:debug_file = 'cuminodebug.log'
        execute 'redir >> ' . s:debug_file
        silent echon strftime('%H:%M:%S') . ': ' . a:msg . "\n"
        redir END
    endif
endfunction


" Public Interface:
"

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
"
" Override internal Mnemonics, e.g.
" map <unique> <Leader>hcc Cumino#CuminoConnect()
noremap <unique> <Plug>CuminoConnect
      \ :call <SID>CuminoConnect()<RETURN>
noremap <unique> <Plug>CuminoEvalBuffer
      \ :call <SID>CuminoEvalBuffer()<RETURN>
noremap <unique> <Plug>CuminoEvalVisual
      \ :call <SID>CuminoEvalVisual()<RETURN>
noremap <unique> <Plug>CuminoShowTypeUnderTheCursor
      \ :call <SID>CuminoShowTypeUnderTheCursor()<RETURN>
noremap <unique> <Plug>CuminoSendToGhci
      \ :call <SID>CuminoSendToGhci()<RETURN>


" Kill cumino before exiting Vim
autocmd VimLeavePre * call CuminoCloseSession()

" vim:sw=2
