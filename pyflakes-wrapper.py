"""
Call pyflakes and return the output in a format easily parseable and usable
by the pyflakes-nopython.vim script.
"""

import ast
from operator import attrgetter
import sys

from pyflakes import checker


def check(contents, filename=None):
    """
    Get pyflakes warning for the contents.

    The result is returned in the form of a string, each warning being on a
    single line in a following format:
    <line_number> <column_number> <message>

    If no column is specified, e.g. in the case of a SyntaxError, the format is:

    <line_number> -1 <message>

    """
    try:
        tree = ast.parse(contents, filename or '<unknown>')
    except:
        try:
            value = sys.exc_info()[1]
            lineno, offset, line = value[1][1:]
        except IndexError:
            lineno, offset, line = 1, 0, ''
        if line and line.endswith("\n"):
            line = line[:-1]
        return "%i -1 could not compile: %s!" % (lineno, str(value))

    w = checker.Checker(tree, filename)
    w.messages.sort(key = attrgetter('lineno'))
    messages = [
        "%i %i %s" % (msg.lineno, getattr(msg, 'col', -1) or -1,
            msg.message % msg.message_args)
        for msg in w.messages
    ]
    return '\n'.join(messages)


if __name__ == '__main__':
    contents = sys.stdin.read()

    arglen = len(sys.argv)
    if arglen == 1:
        filename = '<unknown>'
    elif arglen == 2:
        filename = sys.argv[1]
    else:
        print "Usage: python pyflakes-wrapper.py [<filename>]"
        sys.exit(1)

    # TODO: add "vim quote"
    print check(contents, filename)
