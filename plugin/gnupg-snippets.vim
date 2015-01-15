python << EOF
import vim
import re

PGP_START_PATTERN = re.compile("-{3,}\s*BEGIN\s+PGP\s+MESSAGE\s*-{3,}")
PGP_END_PATTERN = re.compile("-{3,}\s*END\s+PGP\s+MESSAGE\s*-{3,}")

def fetch_range():
    start_line = None
    start_col = None
    end_line = None
    end_col = None

    cursor = vim.current.window.cursor
    cb = vim.current.buffer
    # Search from the current line upwards to the beginning of a PGP block.
    # This is the start of the nearest PGP block the cursor could be in.
    for line in xrange(cursor[0], -1, -1):
        for match in PGP_START_PATTERN.finditer(cb[line]):
            start_line = line
            start_col = match.start()
        if start_line is not None:
            break
    else:
        # TODO: throw an exception, not a string.
        raise "Cursor is not inside a PGP block." 

    # Find the matching end of the PGP block.
    for line in xrange(start_line, cursor[0]):
        for match in PGP_END_PATTERN.finditer(cb[line]):
            end_line = line
            end_col = match.end()
        if end_line is not None:
            break
    else:
        # TODO: throw an exception, not a string.
        raise "Cursor is not inside a PGP block." 

    return ((start_line, start_col), (end_line, end_col))
EOF

function! s:fetch_range()
    python fetch_range()
endfunction
