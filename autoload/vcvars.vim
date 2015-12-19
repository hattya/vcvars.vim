" File:        autoload/vcvars.vim
" Author:      Akinori Hattori <hattya@gmail.com>
" Last Change: 2015-12-19
" License:     MIT License

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vcvars')
let s:P = s:V.import('Process')
let s:FP = s:V.import('System.Filepath')

" Visual Studio
let s:vs = {
\  'key':  'VisualStudio\SxS\VS7',
\  '2010': '10.0',
\}

" Windows SDK
let s:vs_winsdk = {
\  '10.0': {
\    'key': 'Microsoft SDKs\Windows\v7.1',
\    'var': 'InstallationFolder',
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

function! vcvars#call(expr, ver, arch) abort
  let vars = vcvars#get(a:ver, a:arch)
  if empty(vars)
    return
  endif
  let sep = s:FP.path_separator()
  let path = $PATH
  let include = $INCLUDE
  let lib = $LIB
  let libpath = $LIBPATH
  try
    let $PATH = join(vars.path, sep) . sep . path
    let $INCLUDE = join(vars.include, sep) . sep . include
    let $LIB = join(vars.lib, sep) . sep . lib
    let $LIBPATH = join(vars.libpath, sep) . sep . libpath
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

function! vcvars#get(ver, arch) abort
  let ver = get(s:vs, a:ver, a:ver)
  let vsdir = get(s:query(s:vs.key), ver, '')
  if !isdirectory(vsdir)
    return {}
  endif
  if a:arch ==? 'x86'
    let arch = 'x86'
  elseif a:arch =~? '\v^%(x64|x86[_-]64|amd64)'
    let arch = 'x64'
  else
    return {}
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

  let atlmfcdir = s:FP.join(vcdir, 'atlmfc')
  for dir in [vcdir, atlmfcdir]
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
