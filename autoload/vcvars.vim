" File:        autoload/vcvars.vim
" Author:      Akinori Hattori <hattya@gmail.com>
" Last Change: 2016-05-08
" License:     MIT License

let s:save_cpo = &cpo
set cpo&vim

let s:P = vital#vcvars#import('Process')
let s:FP = vital#vcvars#import('System.Filepath')

" Visual Studio
let s:vs = {
\  'key':  'VisualStudio\SxS\VS7',
\  '2010': '10.0',
\  '2012': '11.0',
\  '2013': '12.0',
\  '2015': '14.0',
\}

" Windows SDK
let s:vs_winsdk = {
\  '10.0': {
\    'key': 'Microsoft SDKs\Windows\v7.1',
\    'var': 'InstallationFolder',
\  },
\  '11.0': {
\    'key': 'Windows Kits\Installed Roots',
\    'var': 'KitsRoot',
\  },
\  '12.0': {
\    'key': 'Windows Kits\Installed Roots',
\    'var': 'KitsRoot81',
\  },
\  '14.0': {
\    'key': 'Windows Kits\Installed Roots',
\    'var': 'KitsRoot10',
\  },
\}

let s:vcvars = {}
let s:vars = {
\  'path':    [],
\  'include': [],
\  'lib':     [],
\  'libpath': [],
\}
let s:funcref = type(function('type'))

function! vcvars#call(expr, ver, ...) abort
  let vars = call('vcvars#get', [a:ver] + a:000)
  if empty(vars)
    return
  endif
  let path = $PATH
  let include = $INCLUDE
  let lib = $LIB
  let libpath = $LIBPATH
  try
    let sep = s:FP.path_separator()
    let $PATH = join(vars.path + [path], sep)
    let $INCLUDE = join(vars.include + [include], sep)
    let $LIB = join(vars.lib + [lib], sep)
    let $LIBPATH = join(vars.libpath + [libpath], sep)
    if type(a:expr) == s:funcref
      call a:expr()
    else
      execute a:expr
    endif
  finally
    let $PATH = path
    let $INCLUDE = include
    let $LIB = lib
    let $LIBPATH = libpath
  endtry
endfunction

function! vcvars#get(ver, ...) abort
  let ver = get(s:vs, a:ver, a:ver)
  let vsdir = get(s:query(s:vs.key), ver, '')
  if !isdirectory(vsdir)
    return {}
  endif
  if a:0
    if a:1 ==? 'x86'
      let arch = 'x86'
    elseif a:1 =~? '\v^%(x64|x86[_-]64|amd64)$'
      let arch = 'x64'
    else
      return {}
    endif
  else
    let arch = has('win64') ? 'x64' : 'x86'
  endif

  if !has_key(s:vcvars, ver)
    let s:vcvars[ver] = {}
  endif
  if !has_key(s:vcvars[ver], arch)
    let msvc = s:msvc(ver, arch, vsdir)
    if empty(msvc)
      return {}
    endif
    let winsdk = s:winsdk(ver, arch)
    if empty(winsdk)
      return {}
    endif
    let s:vcvars[ver][arch] = {
    \  'path':    msvc.path + winsdk.path,
    \  'include': msvc.include + winsdk.include,
    \  'lib':     msvc.lib + winsdk.lib,
    \  'libpath': msvc.libpath + winsdk.libpath,
    \}
  endif
  return s:vcvars[ver][arch]
endfunction

function! vcvars#clear() abort
  let s:vcvars = {}
endfunction

function! vcvars#list() abort
  return keys(s:query(s:vs.key))
endfunction

function! s:msvc(ver, arch, vsdir) abort
  let vcdir = s:FP.join(a:vsdir, 'VC')
  if !isdirectory(vcdir)
    return {}
  endif
  let vars = deepcopy(s:vars)

  if a:arch ==# 'x86'
    if filereadable(s:FP.join(vcdir, 'bin', 'cl.exe'))
      call add(vars.path, s:FP.join(vcdir, 'bin'))
    else
      return {}
    endif
  elseif a:arch ==# 'x64'
    if has('win64') && filereadable(s:FP.join(vcdir, 'bin', 'amd64', 'cl.exe'))
      call add(vars.path, s:FP.join(vcdir, 'bin', 'amd64'))
    elseif filereadable(s:FP.join(vcdir, 'bin', 'x86_amd64', 'cl.exe'))
      call extend(vars.path, [s:FP.join(vcdir, 'bin', 'x86_amd64'),
      \                       s:FP.join(vcdir, 'bin')])
    else
      return {}
    endif
  endif
  call extend(vars.path, [s:FP.join(a:vsdir, 'VCPackages'),
  \                       s:FP.join(a:vsdir, 'Common7', 'IDE'),
  \                       s:FP.join(a:vsdir, 'Common7', 'Tools')])

  for dir in [vcdir, s:FP.join(vcdir, 'atlmfc')]
    let inc = s:FP.join(dir, 'include')
    if isdirectory(inc)
      call add(vars.include, inc)
    endif

    let lib = a:arch ==# 'x86' ? s:FP.join(dir, 'lib') :
    \         a:arch ==# 'x64' ? s:FP.join(dir, 'lib', 'amd64') :
    \                            ''
    if isdirectory(lib)
      call add(vars.lib, lib)
      call add(vars.libpath, lib)
    endif
  endfor
  return vars
endfunction

function! s:winsdk(vsver, arch) abort
  let winsdk = s:vs_winsdk[a:vsver]
  let winsdkdir = get(s:query(winsdk.key, winsdk.var), winsdk.var, '')
  if !isdirectory(winsdkdir)
    return {}
  endif
  let vars = deepcopy(s:vars)

  if a:vsver ==# '10.0'
    if a:arch ==# 'x86'
      call add(vars.path, s:FP.join(winsdkdir, 'Bin'))
      call add(vars.lib, s:FP.join(winsdkdir, 'Lib'))
    elseif a:arch ==# 'x64'
      call add(vars.path, s:FP.join(winsdkdir, 'Bin', a:arch))
      call add(vars.lib, s:FP.join(winsdkdir, 'Lib', a:arch))
    endif
    call add(vars.include, s:FP.join(winsdkdir, 'Include'))
  elseif a:vsver =~# '^1[12].0$'
    call add(vars.path, s:FP.join(winsdkdir, 'bin', a:arch))
    call extend(vars.include, map(['shared', 'um', 'winrt'], 's:FP.join(winsdkdir, "Include", v:val)'))
    call add(vars.lib, s:FP.join(winsdkdir, 'Lib', a:vsver ==# '11.0' ? 'win8' : 'winv6.3', 'um', a:arch))
  elseif a:vsver ==# '14.0'
    let dirs = filter(split(glob(s:FP.join(winsdkdir, 'Include', '10.*'), 1), '\n'), 'isdirectory(v:val)')
    if empty(dirs)
      return {}
    endif
    let winsdkver = sort(map(dirs, 'fnamemodify(v:val, ":t")'))[-1]
    call add(vars.path, s:FP.join(winsdkdir, 'bin', a:arch))
    call extend(vars.include, map(['ucrt', 'shared', 'um', 'winrt'], 's:FP.join(winsdkdir, "Include", winsdkver, v:val)'))
    call extend(vars.lib, map(['ucrt', 'um'], 's:FP.join(winsdkdir, "Lib", winsdkver, v:val, a:arch)'))
  endif
  return vars
endfunction

function! s:query(key, ...) abort
  let val = a:0 ? '/v "' . a:1 . '"' : ''
  try
    silent let out = split(s:P.system(printf('reg query "HKLM\SOFTWARE\Microsoft\%s" %s /reg:32', a:key, val)), '\n')
  catch
    return {}
  endtry

  let rv = {}
  for l in out
    let m = matchlist(l, '\v^\s{4,}(.+)\s{4,}REG_.+\s{4,}(.+)$')
    if !empty(m)
      let rv[m[1]] = m[2]
    endif
  endfor
  return rv
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
