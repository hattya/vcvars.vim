" File:        autoload/vcvars.vim
" Author:      Akinori Hattori <hattya@gmail.com>
" Last Change: 2020-02-06
" License:     MIT License

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#vcvars#import('Prelude')
let s:P = vital#vcvars#import('Process')
let s:FP = vital#vcvars#import('System.Filepath')

" Visual Studio
let s:vs = {
\  'key':  'VisualStudio\SxS\VS7',
\  '2010': '10.0',
\  '2012': '11.0',
\  '2013': '12.0',
\  '2015': '14.0',
\  '2017': '15.0',
\}

" Visual C++
let s:vc = {
\  'id':   'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
\  '15.0': 'Microsoft.VCToolsVersion.default.txt',
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
\  '15.0': {
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
    if s:V.is_funcref(a:expr)
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

function! vcvars#clear() abort
  let s:vcvars = {}
endfunction

function! vcvars#get(ver, ...) abort
  let ver = get(s:vs, a:ver, a:ver)
  let vsdir = get(ver =~# '^1[0-4]\.0$' ? s:query(s:vs.key) : s:vswhere(), ver, '')
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

function! vcvars#list() abort
  return keys(s:query(s:vs.key)) + keys(s:vswhere())
endfunction

function! s:msvc(ver, arch, vsdir) abort
  if a:ver =~# '^1[0-4]\.0$'
    let vcdir = s:FP.join(a:vsdir, 'VC')
    if !isdirectory(vcdir)
      return {}
    endif
    let vars = deepcopy(s:vars)

    if a:arch ==# 'x86'
      if filereadable(s:FP.join(vcdir, 'bin', 'cl.exe'))
        call add(vars.path, s:FP.join(vcdir, 'bin'))
      endif
      let arch = ''
    elseif a:arch ==# 'x64'
      if has('win64') && filereadable(s:FP.join(vcdir, 'bin', 'amd64', 'cl.exe'))
        call add(vars.path, s:FP.join(vcdir, 'bin', 'amd64'))
      elseif filereadable(s:FP.join(vcdir, 'bin', 'x86_amd64', 'cl.exe'))
        call extend(vars.path, [s:FP.join(vcdir, 'bin', 'x86_amd64'),
        \                       s:FP.join(vcdir, 'bin')])
      endif
      let arch = 'amd64'
    endif
    let vcpackages = s:FP.join(vcdir, 'VCPackages')
  else
    let conf = s:FP.join(a:vsdir, 'VC', 'Auxiliary', 'Build', s:vc[a:ver])
    if !filereadable(conf)
      return {}
    endif
    let vcdir = s:FP.join(a:vsdir, 'VC', 'Tools', 'MSVC', readfile(conf)[0])
    if !isdirectory(vcdir)
      return {}
    endif
    let vars = deepcopy(s:vars)

    if a:arch ==# 'x86'
      if filereadable(s:FP.join(vcdir, 'bin', 'Host' . a:arch, a:arch, 'cl.exe'))
        call add(vars.path, s:FP.join(vcdir, 'bin', 'Host' . a:arch, a:arch))
      endif
    elseif a:arch ==# 'x64'
      if has('win64') && filereadable(s:FP.join(vcdir, 'bin', 'Host' . a:arch, a:arch, 'cl.exe'))
        call add(vars.path, s:FP.join(vcdir, 'bin', 'Host' . a:arch, a:arch))
      elseif filereadable(s:FP.join(vcdir, 'bin', 'Hostx86', a:arch, 'cl.exe'))
        call extend(vars.path, [s:FP.join(vcdir, 'bin', 'Hostx86', a:arch),
        \                       s:FP.join(vcdir, 'bin', 'Hostx86', 'x86')])
      endif
    endif
    let arch = a:arch
    let vcpackages = s:FP.join(a:vsdir, 'Common7', 'IDE', 'VC', 'VCPackages')
  endif
  if empty(vars.path)
    return {}
  endif
  call extend(vars.path, [vcpackages,
  \                       s:FP.join(a:vsdir, 'Common7', 'IDE'),
  \                       s:FP.join(a:vsdir, 'Common7', 'Tools')])

  for dir in [vcdir, s:FP.join(vcdir, 'atlmfc')]
    let inc = s:FP.join(dir, 'include')
    if isdirectory(inc)
      call add(vars.include, inc)
    endif

    let lib = s:FP.join(dir, 'lib', arch)
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
  elseif a:vsver =~# '^1[12]\.0$'
    call add(vars.path, s:FP.join(winsdkdir, 'bin', a:arch))
    call extend(vars.include, map(['shared', 'um'], 's:FP.join(winsdkdir, "Include", v:val)'))
    call add(vars.lib, s:FP.join(winsdkdir, 'Lib', a:vsver ==# '11.0' ? 'win8' : 'winv6.3', 'um', a:arch))
  else
    let dirs = filter(s:V.glob(s:FP.join(winsdkdir, 'Include', '10.*')), 'isdirectory(v:val)')
    if empty(dirs)
      return {}
    endif
    let winsdkver = sort(map(dirs, 'fnamemodify(v:val, ":t")'))[-1]
    call extend(vars.path, map([winsdkver, ''], 's:FP.join(winsdkdir, "bin", v:val, a:arch)'))
    call extend(vars.include, map(['ucrt', 'shared', 'um'], 's:FP.join(winsdkdir, "Include", winsdkver, v:val)'))
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

function! s:vswhere() abort
  let isi = &isident
  try
    set isident+=(,)
    let vswhere = ( has('win64') ? $ProgramFiles(x86) : $ProgramFiles ) . '\Microsoft Visual Studio\Installer\vswhere.exe'
  finally
    let &isident = isi
  endtry
  if !filereadable(vswhere)
    return {}
  endif

  silent let out = s:P.system(printf('"%s" -products * -requires %s -nologo', vswhere, s:vc.id))
  let rv = {}
  let props = {}
  for l in split(out . '\n', '\n')
    let i = stridx(l, ':')
    if i != -1
      let props[l[: i-1]] = l[i+2 :]
    elseif !empty(props)
      let ver = matchstr(props['installationVersion'], '^\d\+') . '.0'
      if !has_key(rv, ver)
        let rv[ver] = props['installationPath']
      endif
      let props = {}
    endif
  endfor
  return rv
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
