vcvars.vim
==========

vcvars.vim is a Vim plugin to retrieve the PATH, INCLUDE, LIB, and LIBPATH
environment variables for a specified version of Visual C++.

.. image:: https://ci.appveyor.com/api/projects/status/pjvw0fiidsy229jq/branch/master?svg=true
   :target: https://ci.appveyor.com/project/hattya/vcvars-vim

.. image:: https://img.shields.io/badge/powered_by-vital.vim-80273f.svg
   :target: https://github.com/vim-jp/vital.vim


Installation
------------

pathogen.vim_

.. code:: console

   $ cd ~/.vim/bundle
   $ git clone https://github.com/hattya/vcvars.vim

Vundle_

.. code:: vim

   Plugin 'hattya/vcvars.vim'

NeoBundle_

.. code:: vim

   NeoBundle 'hattya/vcvars.vim'

vim-plug_

.. code:: vim

   Plug 'hattya/vcvars.vim'

.. _pathogen.vim: https://github.com/tpope/vim-pathogen
.. _Vundle: https://github.com/VundleVim/Vundle.vim
.. _NeoBundle: https://github.com/Shougo/neobundle.vim
.. _vim-plug: https://github.com/junegunn/vim-plug


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
