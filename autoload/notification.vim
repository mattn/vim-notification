let s:notifications = get(s:, 'notifications', [])
let s:interval = get(g:, 'notification_interval', 50)

function! s:strwidthpart(str, width) abort
  let l:str = tr(a:str, "\t", ' ')
  let l:vcol = a:width + 2
  return matchstr(l:str, '.*\%<' . (l:vcol < 0 ? 0 : l:vcol) . 'v')
endfunction

function! s:truncate(str, width) abort
  if a:str =~# '^[\x00-\x7f]*$'
    return len(a:str) < a:width
          \ ? printf('%-' . a:width . 's', a:str)
          \ : strpart(a:str, 0, a:width)
  endif

  let l:ret = a:str
  let l:width = strwidth(a:str)
  if l:width > a:width
    let l:ret = s:strwidthpart(l:ret, a:width)
    let l:width = strwidth(l:ret)
  endif

  if l:width < a:width
    let l:ret .= repeat(' ', a:width - l:width)
  endif

  return l:ret
endfunction

function! notification#terminate() abort
  for l:n in s:notifications
    let l:winid = l:n[0]
    call popup_close(l:winid)
    call s:call_by_winid(l:winid, 'closed')
  endfor
endfunction

function! s:callback(timer) abort
  let l:drop = []
  let l:active = 0
  for l:n in s:notifications
    let [l:winid, l:options, l:context] = [l:n[0], l:n[1], l:n[2]]

    " calculate max width of the notification
    let l:width = max(map(copy(l:context.lines), 'min([strdisplaywidth(v:val), &columns - 4])'))

    " skip notifications which is still not located yet
    if !l:context.active
      continue
    endif
    let l:active += 1

    if l:context.count == 0 && &columns - l:options.col < l:width + 2
      " move left
      let l:options.col -= 1
    elseif l:context.count < l:context.wait
      " wait a while
      let l:context.count += s:interval
    elseif l:options.col < &columns - 1
      " move right
      let l:options.col += 1
    else
      " drop
      call popup_close(l:winid)
      call add(l:drop, l:winid)
      call s:call_by_winid(l:winid, 'closed')
      continue
    endif

    let l:bufnr = winbufnr(l:winid)
    let l:lines = map(copy(l:context.lines), {i, v -> s:truncate(v, min([&columns - l:options.col, l:width]))})
    call setbufline(l:bufnr, 1, l:lines)
    call popup_show(l:winid)
    call popup_setoptions(l:winid, l:options)
  endfor

  " remove notifications wiped out
  for l:v in l:drop
    let s:notifications = filter(s:notifications, 'l:v != v:val[0]')
  endfor

  " standby next notifications
  if l:active == 0
    let l:line = 2
    for l:n in s:notifications
      let l:n[1].line = l:line
      let l:line += 3 + len(l:n[2].lines)
      if l:line  >= &lines
        break
      endif
      let l:n[2].active = v:true
    endfor
  endif

  " start timer if still have to do
  if len(s:notifications) > 0
    call timer_start(s:interval, function('s:callback'))
  endif
endfunction

function! notification#show(arg) abort
  let l:option = type(a:arg) == type({}) ? a:arg : {'text': a:arg}
  let l:winid = popup_create(
  \  '', {
  \    'padding': [1,1,1,1],
  \    'hidden': v:true,
  \    'mapping': v:true,
  \    'title': get(l:option, 'title', '')
  \  })
  let l:lines = split(get(l:option, 'text', ''), '\n')
  if len(l:lines) > &lines - &cmdheight - 5
    let l:lines = l:lines[:&lines - &cmdheight - 5]
  endif

  " calculate position
  let l:line = 2
  if !empty(s:notifications) 
    let l:line = s:notifications[-1][1].line + len(s:notifications[-1][2].lines) + 3
  endif

  let l:opt = {'line': l:line, 'col': &columns}
  let l:ctx = {'lines': l:lines, 'count': 0, 'wait': get(l:option, 'wait', 5000), 'active': (l:line + 3 + len(l:lines)) < &lines}
  if has_key(l:option, 'clicked')
    let l:ctx.clicked = l:option.clicked
    call win_execute(l:winid, printf('nnoremap <silent> <LeftMouse> :call <SID>clicked(%d)<cr>', l:winid))
  endif
  if has_key(l:option, 'closed')
    let l:ctx.closed = l:option.closed
  endif
  let l:n = [l:winid, l:opt, l:ctx]
  call add(s:notifications, l:n)

  " start timer
  if len(s:notifications) == 1
    call timer_start(0, function('s:callback'))
  endif
endfunction

function! s:call_by_winid(winid, fun) abort
  for l:n in s:notifications
    if l:n[0] ==# a:winid
      let l:n[2].count = l:n[2].wait
      if has_key(l:n[2], a:fun)
        let l:F = l:n[2][a:fun]
        try
          call l:F()
        catch
        endtry
      endif
    endif
  endfor
endfunction

function! s:closed(winid) abort
  call s:call_by_winid(a:winid, 'closed')
endfunction

function! s:clicked(winid) abort
  call s:call_by_winid(a:winid, 'clicked')
endfunction
