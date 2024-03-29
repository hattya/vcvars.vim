vcvars.vim
==========

vcvars.vim is a Vim plugin to retrieve the PATH, INCLUDE, LIB, and LIBPATH
environment variables for the specified version of Visual C++.

.. image:: https://github.com/hattya/vcvars.vim/actions/workflows/ci.yml/badge.svg
   :target: https://github.com/hattya/vcvars.vim/actions/workflows/ci.yml

.. image:: https://ci.appveyor.com/api/projects/status/pjvw0fiidsy229jq/branch/master?svg=true
   :target: https://ci.appveyor.com/project/hattya/vcvars-vim

.. image:: https://codecov.io/gh/hattya/vcvars.vim/branch/master/graph/badge.svg
   :target: https://codecov.io/gh/hattya/vcvars.vim

.. image:: https://img.shields.io/badge/powered_by-vital.vim-80273f.svg
   :target: https://github.com/vim-jp/vital.vim

.. image:: https://img.shields.io/badge/doc-:h%20vcvars.txt-blue.svg
   :target: doc/vcvars.txt


Installation
------------

Vundle_

.. code:: vim

   Plugin 'hattya/vcvars.vim'

vim-plug_

.. code:: vim

   Plug 'hattya/vcvars.vim'

dein.vim_

.. code:: vim

   call dein#add('hattya/vcvars.vim')

.. _Vundle: https://github.com/VundleVim/Vundle.vim
.. _vim-plug: https://github.com/junegunn/vim-plug
.. _dein.vim: https://github.com/Shougo/dein.vim


Requirements
------------

- Vim 8.0+
- Visual Studio 2010+


Testing
-------

vcvars.vim uses themis.vim_ for testing.

.. code:: console

   $ cd /path/to/vcvars.vim
   $ git clone https://github.com/thinca/vim-themis
   $ ./vim-themis/bin/themis

.. _themis.vim: https://github.com/thinca/vim-themis


License
-------

vcvars.vim is distributed under the terms of the MIT License.
