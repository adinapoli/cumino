" Copyright (C) 2013 Alfredo Di Napoli
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
if !exists("g:cumino_swap_on_load")
  let g:cumino_swap_on_load = 1
endif

if !exists("g:cumino_buffer_location")
  let g:cumino_buffer_location = substitute(system("echo $HOME"), "\n", "", "g") . "/.cumino.buff"
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
  subprocess.call(["tmux", "kill-window", "-t", "cumino"])

def cumino_swap():
  subprocess.call(["tmux", "swap-window", "-d", "-s", "2", "-t", "cumino"])

EOF

"Connect to repl
fun! CuminoConnect()

  echo "Starting a new cumino session..."

  let cmd = "tmux new-window -n cumino "

  let sandbox = GetSandboxActivationStringIfPresent()
  let cmd .= "'".sandbox."ghci ". g:cumino_ghci_args ."'"
  call system(cmd)

  if(g:cumino_swap_on_load)
    python cumino_swap()
  endif

  "Every time we reload a tmux window, modules must be
  "reloaded.
  let g:cumino_module_loaded[expand("%:p")] = 0
  echo "Cumino session started."

endfun

fun! GetSandboxActivationStringIfPresent()

  if($HSENV != "" && g:cumino_use_hsenv)
    return "export GHC_PACKAGE_PATH=" . $HSENV . "/.hsenv/ghc_pkg_db && "
  else
    return ""
  endif

endfun


fun! CuminoEvalBuffer()

  let b:buffer_name = expand("%:p")
  let module_already_loaded = get(g:cumino_module_loaded, b:buffer_name)
  if (!module_already_loaded)
    let b:use_cmd = ":load \"". b:buffer_name ."\""
  else
    let b:use_cmd = ":r"
  endif
  call system("echo \"". escape(b:use_cmd,"\"") ."\" > ". g:cumino_buffer_location)
  call system("tmux load-buffer ". g:cumino_buffer_location ."; tmux pasteb -t cumino")
  let g:cumino_module_loaded[expand("%:p")] = 1
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

fun! CuminoEvalVisual() range
  let g:selected_text = s:GetVisualSelection()
  python cumino_eval_visual()
endfun

fun! CuminoShowTypeUnderTheCursor()
  normal! "zyw
  python cumino_show_type_under_the_cursor()
endfun

fun! CuminoSendToGhci()
  call inputsave()
  let cmd = input('Expr?: ')
  call inputrestore()
  python cumino_send_to_ghci()
endfun

fun! CuminoCloseSession()
    python cumino_kill()
endfun

fun! CuminoSwap()
  " By default, swap the second window to be the cumino one.
  python cumino_swap()
endfun

"Mnemonic: cumino Connect
map <LocalLeader>cc :call CuminoConnect()<RETURN>

"Mnemonic: cumino (Eval) Buffer
map <LocalLeader>cb :call CuminoEvalBuffer()<RETURN>

"Mnemonic: cumino (Eval) Visual (Selection)
map <LocalLeader>cv :call CuminoEvalVisual()<RETURN>

"Mnemonic: cumino (Show) Type
map <LocalLeader>ct :call CuminoShowTypeUnderTheCursor()<RETURN>

"Mnemonic: cumino Send
map <LocalLeader>cs :call CuminoSendToGhci()<RETURN>

"Mnemonic: cumino s(W)ap
map <LocalLeader>cw :call CuminoSwap()<RETURN>

"Kill cumino before exiting Vim
autocmd VimLeavePre * call CuminoCloseSession()

" vim:sw=2
