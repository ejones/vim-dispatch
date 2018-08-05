" dispatch.vim terminal strategy
" Adapted from https://github.com/tpope/vim-dispatch/commit/140a3472309d1c49e9b429656b2e223acfc8ed12

if exists('g:autoloaded_dispatch_terminal')
  finish
endif
let g:autoloaded_dispatch_terminal = 1

if !exists('s:waiting')
  let s:waiting = {}
endif

function! dispatch#terminal#handle(request) abort
  let request_supported = a:request.action ==# 'start' ||
        \ (a:request.action ==# 'make' && !a:request.background)

  if !has('terminal') || !request_supported
    return 0
  endif

  call dispatch#autowrite()

  let options = { 'exit_cb': function('s:exit'), 'term_name': a:request.title }

  if a:request.action ==# 'make'
    let options.term_finish = 'close'
  endif

  if a:request.action ==# 'make'
    let command = ('(' . a:request.expanded . '; echo ' .
        \ dispatch#status_var() . ' > ' . a:request.file . '.complete)' .
        \ dispatch#shellpipe(a:request.file))
  else
    let command = a:request.expanded
  endif

  let buf_id = term_start([&shell, &shellcmdflag, command], options)

  if a:request.action ==# 'make'
    wincmd J
    execute 'resize' get(g:, 'dispatch_quickfix_height', 10)
    wincmd p
  elseif a:request.background
    hide
  endif

  let job = term_getjob(buf_id)
  let a:request.pid = job_info(job).process
  let ch_id = ch_info(job_info(job).channel).id
  let s:waiting[ch_id] = a:request
  call writefile([a:request.pid], a:request.file . '.pid')
  let a:request.handler = 'terminal'

  return 1
endfunction

function! s:exit(job, status) abort
  let channel = job_getchannel(a:job)
  let ch_id = ch_info(channel).id
  let request = s:waiting[ch_id]
  if request.action ==# 'start'
    call writefile([a:status], request.file . '.complete')
  endif
  unlet! s:waiting[ch_id]
  if request.action ==# 'make'
    call dispatch#complete(request)
  endif
endfunction

function! dispatch#terminal#activate(pid) abort
  for buf in term_list()
    if job_info(term_getjob(buf)).process ==# a:pid
      let swb = &l:switchbuf
      try
        let &l:switchbuf = 'useopen,usetab'
        execute 'sbuffer' buf
      finally
        let &l:switchbuf = swb
      endtry
      return 1
    endif
  endfor
  return 0
endfunction
