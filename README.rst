pyflakes-vim-nopython
=====================

This is a slightly modified version of the pyflakes-vim project that enables
using pyflakes even with Vim that has no Python support (in case you are, for
any reason, stuck with such an installation of Vim). However, your system still
has to have Python installed.

For more information about pyflakes and the original pyflakes-vim, see the
appropriate page on vim.org_.

.. _vim.org: http://www.vim.org/scripts/script.php?script_id=2441


Differences from pyflakes-vim
-----------------------------

To work around the unability to call Python code (and thus pyflakes) directly
from vim, pyflakes-vim-nopython spawns an external Python process, writes the
current buffer content to its standard input and reads and parses its standard
output to get the results.


Quick installation
------------------
1. Make sure your ``.vimrc`` has::
 
    filetype on            " enables filetype detection
    filetype plugin on     " enables filetype specific plugins

2. Download the latest version of pyflakes-vim-nopython.

3. Extract ``pyflakes-nopython.tar.gz`` into ``~/.vim/ftplugin/python``.
   
   If you're using pathogen_, unzip the contents of ``pyflakes-nopython.tar.gz`` into
   its own bundle directory under ``ftplugin/python``, e.g. into
   ``~/.vim/bundle/pyflakes-nopython/ftplugin/python``. 

4. Make sure that pyflakes can be found by Python. This is by default done by
   enhancing the PYTHONPATH environment variable in the pyflakes-nopython.vim
   script, and on most systems that should be sufficient. 

Lastly, it is presumed that python can be called as "python" in the system shell.

If you need to change the way the pyflakes-wrapper.py gets invoked, you can
change the ``b:python_call`` variable at the top of ``pyflakes-nopython.vim``.

.. _pathogen: http://www.vim.org/scripts/script.php?script_id=2332


Known issues
------------

* Running a separate Python process each time the source gets changed is not
  very efficient and the time cost may be prohibitive on some machines.

Finally
-------

If you find any bugs, please let me know at WWuzzy@gmail.com. Thanks!
