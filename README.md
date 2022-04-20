# vim-notification

Message notification system for Vim

![](https://raw.githubusercontent.com/mattn/vim-notification/main/doc/screenshot.gif)

## Usage

```vim
call notification#show('Hello World')
```

```vim
call nofitication#show(#{
\  text: 'Hello World',
\})
```

If you want to specify waiting time to stay the notification on screen:

```vim
call nofitication#show(#{
\  text: 'Hello World',
\  wait: 300,
\})
```

To handle clicked/closed event:

```vim
function! s:my_clicked(data) abort
  echo a:data
endfunction

call nofitication#show(#{
\  text: 'Hello World',
\  clicked: function('s:my_clicked', ['Hi!']),
\})
```

## Installation

For [vim-plug](https://github.com/junegunn/vim-plug) plugin manager:

```vim
Plug 'mattn/vim-notification'
```

## License

MIT

## Author

Yasuhiro Matsumoto (a.k.a. mattn)
