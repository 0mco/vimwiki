" vim:tabstop=2:shiftwidth=2:expandtab:foldmethod=marker:textwidth=79
" Vimwiki plugin file
" Home: https://github.com/vimwiki/vimwiki/
" GetLatestVimScripts: 2226 1 :AutoInstall: vimwiki

if exists("g:loaded_vimwiki") || &cp
  finish
endif
let g:loaded_vimwiki = 1

let s:old_cpo = &cpo
set cpo&vim


" this is called when the cursor leaves the buffer
function! s:setup_buffer_leave() "{{{
  " don't do anything if it's not managed by Vimwiki (that is, when it's not in
  " a registered wiki and not a temporary wiki)
  if vimwiki#vars#get_bufferlocal('wiki_nr') == -1
    return
  endif

  let &autowriteall = s:vimwiki_autowriteall_saved

  if vimwiki#vars#get_global('menu') != ""
    exe 'nmenu disable '.vimwiki#vars#get_global('menu').'.Table'
  endif
endfunction "}}}


" create a new temporary wiki for the current buffer
function! s:create_temporary_wiki()
  let current_file = vimwiki#path#current_file()
  let path = vimwiki#path#directory(current_file)
  let ext = '.'.vimwiki#path#extension(current_file)

  let syntax_mapping = vimwiki#vars#get_global('ext2syntax')
  if has_key(syntax_mapping, ext)
    let syntax = syntax_mapping[ext]
  else
    let syntax = vimwiki#vars#get_wikilocal_default('syntax')
  endif

  let new_temp_wiki_settings = {'path': path,
        \ 'ext': ext,
        \ 'syntax': syntax,
        \ }

  call vimwiki#vars#add_temporary_wiki(new_temp_wiki_settings)
endfunction


" this is called when Vim opens a new buffer with a known wiki extension
function! s:setup_new_wiki_buffer() "{{{
  let wiki_nr = vimwiki#vars#get_bufferlocal('wiki_nr')
  if wiki_nr == -1    " it's not in a known wiki directory
    if vimwiki#vars#get_global('global_ext')
      call s:create_temporary_wiki()
    else
      " the user does not want a temporary wiki, so do nothing
      return
    endif
  endif

  " this makes that ftplugin/vimwiki.vim is sourced
  set filetype=vimwiki

  " to force a rescan of the filesystem which may have changed
  " and update VimwikiLinks syntax group that depends on it;
  " 'fs_rescan' indicates that setup_filetype() has not been run
  if vimwiki#vars#get_bufferlocal('fs_rescan') == 1 && vimwiki#vars#get_wikilocal('maxhi')
    set syntax=vimwiki
  endif
  call vimwiki#vars#set_bufferlocal('fs_rescan', 1)
endfunction "}}}


" this is called when the cursor enters the buffer
function! s:setup_buffer_enter() "{{{
  " don't do anything if it's not managed by Vimwiki (that is, when it's not in
  " a registered wiki and not a temporary wiki)
  if vimwiki#vars#get_bufferlocal('wiki_nr') == -1
    return
  endif

  let s:vimwiki_autowriteall_saved = &autowriteall
  let &autowriteall = vimwiki#vars#get_global('autowriteall')

  if &filetype == ''
    set filetype=vimwiki
  elseif &syntax ==? 'vimwiki'
    " to force a rescan of the filesystem which may have changed
    " and update VimwikiLinks syntax group that depends on it;
    " 'fs_rescan' indicates that setup_filetype() has not been run
    if vimwiki#vars#get_bufferlocal('fs_rescan') == 1 && vimwiki#vars#get_wikilocal('maxhi')
      set syntax=vimwiki
    endif
    call vimwiki#vars#set_bufferlocal('fs_rescan', 1)
  endif

  " The settings foldmethod, foldexpr and foldtext are local to window. Thus in
  " a new tab with the same buffer folding is reset to vim defaults. So we
  " insist vimwiki folding here.
  let foldmethod = vimwiki#vars#get_global('folding')
  if foldmethod ==? 'expr'
    setlocal foldmethod=expr
    setlocal foldexpr=VimwikiFoldLevel(v:lnum)
    setlocal foldtext=VimwikiFoldText()
  elseif foldmethod ==? 'list' || foldmethod ==? 'lists'
    setlocal foldmethod=expr
    setlocal foldexpr=VimwikiFoldListLevel(v:lnum)
    setlocal foldtext=VimwikiFoldText()
  elseif foldmethod ==? 'syntax'
    setlocal foldmethod=syntax
    setlocal foldtext=VimwikiFoldText()
  else
    setlocal foldmethod=manual
    normal! zE
  endif

  " And conceal level too.
  if vimwiki#vars#get_global('conceallevel') && exists("+conceallevel")
    let &conceallevel = vimwiki#vars#get_global('conceallevel')
  endif

  " lcd as well
  if vimwiki#vars#get_global('auto_chdir')
    exe 'lcd' vimwiki#path#to_string(vimwiki#vars#get_wikilocal('path'))
  endif

  " Set up menu
  if vimwiki#vars#get_global('menu') !=# ''
    exe 'nmenu enable '.vimwiki#vars#get_global('menu').'.Table'
  endif
endfunction "}}}

function! s:setup_cleared_syntax() "{{{ highlight groups that get cleared
  " on colorscheme change because they are not linked to Vim-predefined groups
  hi def VimwikiBold term=bold cterm=bold gui=bold
  hi def VimwikiItalic term=italic cterm=italic gui=italic
  hi def VimwikiBoldItalic term=bold cterm=bold gui=bold,italic
  hi def VimwikiUnderline gui=underline
  if vimwiki#vars#get_global('hl_headers') == 1
    for i in range(1,6)
      execute 'hi def VimwikiHeader'.i.' guibg=bg guifg='.vimwiki#vars#get_global('hcolor_guifg_'.&bg)[i-1].' gui=bold ctermfg='.vimwiki#vars#get_global('hcolor_ctermfg_'.&bg)[i-1].' term=bold cterm=bold' 
    endfor
  endif
endfunction "}}}


function! s:vimwiki_get_known_extensions() " {{{
  " Getting all extensions that different wikis could have
  let extensions = {}
  for idx in range(vimwiki#vars#number_of_wikis())
    let ext = vimwiki#vars#get_wikilocal('ext', idx)
    let extensions[ext] = 1
  endfor
  " append extensions from g:vimwiki_ext2syntax
  for ext in keys(vimwiki#vars#get_global('ext2syntax'))
    let extensions[ext] = 1
  endfor
  return keys(extensions)
endfunction " }}}

" }}}


" Initialization of Vimwiki starts here. Make sure everything below does not
" cause autoload/base to be loaded

call vimwiki#vars#init()

" CALLBACK functions "{{{
" User can redefine it.
if !exists("*VimwikiLinkHandler") "{{{
  function VimwikiLinkHandler(url)
    return 0
  endfunction
endif "}}}

if !exists("*VimwikiLinkConverter") "{{{
  function VimwikiLinkConverter(url, source, target)
    " Return the empty string when unable to process link
    return ''
  endfunction
endif "}}}

if !exists("*VimwikiWikiIncludeHandler") "{{{
  function! VimwikiWikiIncludeHandler(value) "{{{
    return ''
  endfunction "}}}
endif "}}}
" CALLBACK }}}


" AUTOCOMMANDS for all known wiki extensions {{{

let s:known_extensions = s:vimwiki_get_known_extensions()

if index(s:known_extensions, '.wiki') > -1
  augroup filetypedetect
    " clear FlexWiki's stuff
    au! * *.wiki
  augroup end
endif

augroup vimwiki
  autocmd!
  for s:ext in s:known_extensions
    exe 'autocmd BufEnter *'.s:ext.' call s:setup_buffer_enter()'
    exe 'autocmd BufNewFile,BufRead *'.s:ext.' call s:setup_new_wiki_buffer()'
    exe 'autocmd BufLeave *'.s:ext.' call s:setup_buffer_leave()'
    exe 'autocmd ColorScheme *'.s:ext.' call s:setup_cleared_syntax()'
    " Format tables when exit from insert mode. Do not use textwidth to
    " autowrap tables.
    if vimwiki#vars#get_global('table_auto_fmt')
      exe 'autocmd InsertLeave *'.s:ext.' call vimwiki#tbl#format(line("."))'
      exe 'autocmd InsertEnter *'.s:ext.' call vimwiki#tbl#reset_tw(line("."))'
    endif
  endfor
augroup END
"}}}

" COMMANDS {{{
command! VimwikiUISelect call vimwiki#base#ui_select()
" XXX: why not using <count> instead of v:count1?
" See Issue 324.
command! -count=1 VimwikiIndex
      \ call vimwiki#base#goto_index(v:count1)
command! -count=1 VimwikiTabIndex
      \ call vimwiki#base#goto_index(v:count1, 1)

command! -count=1 VimwikiDiaryIndex
      \ call vimwiki#diary#goto_diary_index(v:count1)
command! -count=1 VimwikiMakeDiaryNote
      \ call vimwiki#diary#make_note(v:count1)
command! -count=1 VimwikiTabMakeDiaryNote
      \ call vimwiki#diary#make_note(v:count1, 1)
command! -count=1 VimwikiMakeYesterdayDiaryNote
      \ call vimwiki#diary#make_note(v:count1, 0, vimwiki#diary#diary_date_link(localtime() - 60*60*24))

command! VimwikiDiaryGenerateLinks
      \ call vimwiki#diary#generate_diary_section()
"}}}

" MAPPINGS {{{
let s:map_prefix = vimwiki#vars#get_global('map_prefix')

if !hasmapto('<Plug>VimwikiIndex')
  exe 'nmap <silent><unique> '.s:map_prefix.'w <Plug>VimwikiIndex'
endif
nnoremap <unique><script> <Plug>VimwikiIndex :VimwikiIndex<CR>

if !hasmapto('<Plug>VimwikiTabIndex')
  exe 'nmap <silent><unique> '.s:map_prefix.'t <Plug>VimwikiTabIndex'
endif
nnoremap <unique><script> <Plug>VimwikiTabIndex :VimwikiTabIndex<CR>

if !hasmapto('<Plug>VimwikiUISelect')
  exe 'nmap <silent><unique> '.s:map_prefix.'s <Plug>VimwikiUISelect'
endif
nnoremap <unique><script> <Plug>VimwikiUISelect :VimwikiUISelect<CR>

if !hasmapto('<Plug>VimwikiDiaryIndex')
  exe 'nmap <silent><unique> '.s:map_prefix.'i <Plug>VimwikiDiaryIndex'
endif
nnoremap <unique><script> <Plug>VimwikiDiaryIndex :VimwikiDiaryIndex<CR>

if !hasmapto('<Plug>VimwikiDiaryGenerateLinks')
  exe 'nmap <silent><unique> '.s:map_prefix.'<Leader>i <Plug>VimwikiDiaryGenerateLinks'
endif
nnoremap <unique><script> <Plug>VimwikiDiaryGenerateLinks :VimwikiDiaryGenerateLinks<CR>

if !hasmapto('<Plug>VimwikiMakeDiaryNote')
  exe 'nmap <silent><unique> '.s:map_prefix.'<Leader>w <Plug>VimwikiMakeDiaryNote'
endif
nnoremap <unique><script> <Plug>VimwikiMakeDiaryNote :VimwikiMakeDiaryNote<CR>

if !hasmapto('<Plug>VimwikiTabMakeDiaryNote')
  exe 'nmap <silent><unique> '.s:map_prefix.'<Leader>t <Plug>VimwikiTabMakeDiaryNote'
endif
nnoremap <unique><script> <Plug>VimwikiTabMakeDiaryNote
      \ :VimwikiTabMakeDiaryNote<CR>

if !hasmapto('<Plug>VimwikiMakeYesterdayDiaryNote')
  exe 'nmap <silent><unique> '.s:map_prefix.'<Leader>y <Plug>VimwikiMakeYesterdayDiaryNote'
endif
nnoremap <unique><script> <Plug>VimwikiMakeYesterdayDiaryNote
      \ :VimwikiMakeYesterdayDiaryNote<CR>

"}}}

" MENU {{{
function! s:build_menu(topmenu)
  for idx in range(vimwiki#vars#number_of_wikis())
    let norm_path = vimwiki#path#to_string(vimwiki#vars#get_wikilocal('path', idx))
    let norm_path = escape(norm_path, '\ .')
    execute 'menu '.a:topmenu.'.Open\ index.'.norm_path.
          \ ' :call vimwiki#base#goto_index('.idx.')<CR>'
    execute 'menu '.a:topmenu.'.Open/Create\ diary\ note.'.norm_path.
          \ ' :call vimwiki#diary#make_note('.idx.')<CR>'
  endfor
endfunction

function! s:build_table_menu(topmenu)
  exe 'menu '.a:topmenu.'.-Sep- :'
  exe 'menu '.a:topmenu.'.Table.Create\ (enter\ cols\ rows) :VimwikiTable '
  exe 'nmenu '.a:topmenu.'.Table.Format<tab>gqq gqq'
  exe 'nmenu '.a:topmenu.'.Table.Move\ column\ left<tab><A-Left> :VimwikiTableMoveColumnLeft<CR>'
  exe 'nmenu '.a:topmenu.'.Table.Move\ column\ right<tab><A-Right> :VimwikiTableMoveColumnRight<CR>'
  exe 'nmenu disable '.a:topmenu.'.Table'
endfunction


if !empty(vimwiki#vars#get_global('menu'))
  call s:build_menu(vimwiki#vars#get_global('menu'))
  call s:build_table_menu(vimwiki#vars#get_global('menu'))
endif
" }}}

" CALENDAR Hook "{{{
if vimwiki#vars#get_global('use_calendar')
  let g:calendar_action = 'vimwiki#diary#calendar_action'
  let g:calendar_sign = 'vimwiki#diary#calendar_sign'
endif
"}}}


let &cpo = s:old_cpo
