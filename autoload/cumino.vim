" ============================================================================
" File: cumino.vim
" Description: vim plugin to call tmux
" Maintainer: Alfredo Di Napoli <?@?.com>
" License: ??
" Notes: ??
"
" ============================================================================


let python_module =
            \ fnameescape(globpath(&runtimepath, 'autoload/cumino.py'))
exe 'pyfile ' . python_module


" Connect to repl
fun! cumino#CuminoConnect()
"{{{

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
"}}}

fun! GetSandboxActivationStringIfPresent()
"{{{

  if($HSENV != "" && g:cumino_use_hsenv)
    return "export GHC_PACKAGE_PATH=" . $GHC_PACKAGE_PATH . " && "
  else
    return ""
  endif

endfun
"}}}

fun! CuminoSessionExists()
"{{{

  let w:sessions = system("tmux list-sessions 2>&1 | grep cumino")
  if (w:sessions != "")
      return 1
  else
    return 0
  endif
endfun
"}}}

fun! cumino#CuminoEvalBuffer()
"{{{

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
"}}}

function! cumino#NumSort(a, b)
"{{{

    return a:a>a:b ? 1 : a:a==a:b ? 0 : -1
endfunction
"}}}

function! cumino#GetVisualSelection()
"{{{

  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  return lines
endfunction
"}}}

fun! cumino#CuminoEvalVisual() range
"{{{

  if CuminoSessionExists()
    let g:selected_text = cumino#GetVisualSelection()
    python cumino_eval_visual()
  endif
endfun
"}}}

fun! cumino#CuminoShowTypeUnderTheCursor()
"{{{

  if CuminoSessionExists()
    normal! "zyw
    python cumino_show_type_under_the_cursor()
  endif
endfun
"}}}

fun! cumino#CuminoSendToGhci()
"{{{

  if CuminoSessionExists()
    call inputsave()
    let cmd = input('Expr?: ')
    call inputrestore()
    python cumino_send_to_ghci()
  endif
endfun
"}}}

fun! cumino#CuminoCloseSession()
"{{{

  if CuminoSessionExists()
    if g:cumino_owner == getpid()
      python cumino_kill()
    endif
  endif
endfun
"}}}

" vim: set et sts=4 sw=4:
