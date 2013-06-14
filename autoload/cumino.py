# ============================================================================
# File: cumino.py
# Description: vim plugin to call tmux
# Maintainer: Alfredo Di Napoli <?@?.com>
# License: ??
# Notes: ???
#
# ============================================================================

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
