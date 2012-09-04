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
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

if !has("python")
  finish
endif

" Default variables
if !exists("g:cumino_default_terminal")
  let g:cumino_default_terminal = "xterm"
endif

if !exists("g:cumino_buffer_location")
  let g:cumino_buffer_location = substitute(system("echo $PWD"), "\n", "", "g") . "/.cumino.buff"
endif

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
    "class", "type"
  ]

  is_prefixable = lines[0].split(" ")[0] not in not_prefixable_keywords
  if is_prefixable:
    lines[0] = "let " + lines[0]

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
  cumino_buff = vim.eval("g:cumino_buffer_location") 
  #First write the content of the visual selection in a buffer
  write_to_buffer()
  subprocess.call(["tmux", "load-buffer", cumino_buff ])
  subprocess.call(["tmux", "pasteb", "-t", "cumino"])

def cumino_kill():
  subprocess.call(["tmux", "kill-session", "-t", "cumino"])

EOF

"Connect to repl
fun! CuminoConnect()

  "Setup the Vim who own the cumino session. Only him
  "can shutdown cumino
  let g:cumino_owner = getpid()
  if CuminoSessionExists()
    "Attach to an already running session
    echo "Connecting to an already running cumino session..."
    call system(g:cumino_default_terminal ." -e \"tmux attach-session -t cumino\" &")
    echo "Connected."
  else
    "Change the cumino owner to be this one
    let g:cumino_owner = getpid()
    echo "Starting a new cumino session..."
    let a:cmd = g:cumino_default_terminal
    let a:cmd .= " -e \"tmux new-session -s cumino "
    let a:cmd .= "'ghci'\" &"
    call system(a:cmd)
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

fun! CuminoEvalBuffer()
  let b:buffer_name = expand("%:p")
  let b:use_cmd = ":load \"". b:buffer_name ."\""
  call system("echo \"". escape(b:use_cmd,"\"") ."\" > ". g:cumino_buffer_location)
  if CuminoSessionExists()
    call system("tmux load-buffer ". g:cumino_buffer_location ."; tmux pasteb -t cumino")
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

fun! CuminoEvalVisual()
  if CuminoSessionExists()
    let g:selected_text = s:GetVisualSelection()
    python cumino_eval_visual()
  endif
endfun

fun! CuminoCloseSession()
  if CuminoSessionExists()
    if g:cumino_owner == getpid()
      python cumino_kill()
    endif
  endif
endfun

"Mnemonic: cumino Connect
map <LocalLeader>cc :call CuminoConnect()<RETURN>

"Mnemonic: cumino (Eval) Buffer
map <LocalLeader>cb :call CuminoEvalBuffer()<RETURN>

"Mnemonic: cumino (Eval) Visual (Selection)
"This is an ugly hack to cancel the visual boundaries from
"the ex prompt. By default, when in visual mode and you press
" ":" Vim will fill the prompt with <','>, but we want to cancel
" those to avoid repeating the call for every line!
map <LocalLeader>cv :<BS><BS><BS><BS><BS>call CuminoEvalVisual()<RETURN>

"Kill cumino before exiting Vim
autocmd VimLeavePre * call CuminoCloseSession()<RETURN>

" vim:sw=2
