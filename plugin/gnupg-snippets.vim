if exists("g:gnupg_snippets_loaded") || &cp
  finish
endif
let g:gnupg_snippets_loaded = 1

python << EOF
import vim
import re

PGP_START_PATTERN = re.compile("-{5,}\s*BEGIN\s+PGP\s+MESSAGE\s*-{5,}")
PGP_END_PATTERN = re.compile("-{5,}\s*END\s+PGP\s+MESSAGE\s*-{5,}")

def get_selected_text(start=None, end=None, buffer=None):
    """Return the text of a range."""

    if buffer is None:
      buffer = vim.current.buffer
    if start is None and end is None:
      start = vim.current.buffer.mark('<')
      end = vim.current.buffer.mark('>')
      start = start[0]-1, start[1]
      end = end[0]-1, end[1]+1
    elif type(start) is vim.Range:
      end = start.end
      start = start.start
    elif start is None or end is None:
      raise vim.error, "Wrong arguments."

    if type(start) is int:
      start = start, 0
    if type(end) is int:
      end = end, 0

    selection = buffer[start[0]:end[0]+1]
    selection[0] = selection[0][start[1]:]
    selection[-1] = selection[-1][:end[1]]
    #return selection
    return '\n'.join(selection)

def current_gpg_block_range():
    """
    Find the start and end position of the PGP block of the cursor.
  
    If the vim cursor is inside a PGP block, find the starting and ending
    line and column.  This will be returned as
        ((start_line, start_column), (end_line, end_column))
    If the cursor is not inside a PGP block, raise a vim.error. 
    """
    start_line = None
    start_column = None
    end_line = None
    end_column = None

    cursor = vim.current.window.cursor
    cb = vim.current.buffer
    # Search from the current line upwards to the beginning of a PGP block.
    # This is the start of the nearest PGP block the cursor could be in.
    for line in xrange(cursor[0], -1, -1):
        for match in PGP_START_PATTERN.finditer(cb[line]):
            start_line = line
            start_column = match.start()
        if start_line is not None:
            break
    else:
        raise vim.error, "Cursor is not inside a PGP block." 

    # Find the matching end of the PGP block.
    for line in xrange(start_line, len(cb)):
        for match in PGP_END_PATTERN.finditer(cb[line]):
            end_line = line
            end_column = match.end()
        if end_line is not None:
            break
    else:
        raise vim.error, "Cursor is not inside a PGP block." 

    if start_line > cursor[0] or end_line < cursor[0]:
      raise vim.error, "Cursor is not inside a PGP block."

    return ((start_line, start_column), (end_line, end_column))

def current_gpg_block_text():
    """
    Retrieve the text of the PGP block of the cursor.

    If the vim cursor is inside a PGP block, return its text, including 
    the beginning and end patterns.  If the cursor is not inside a PGP
    block, raise a vim.error.
    """
    pgp_range = current_gpg_block_range()
    return get_selected_text(*pgp_range)
EOF

function! s:fetch_gpg_current_range()
    python fetch_gpg_current_range()
  endfunction

" Key mappings will be of the form '<Leader>s' followed by something more
" specific.  Planned mappings:
" - <Leader>se encrypt a range selected by V;
" - <Leader>sd decrypts the current GPG block.
" The mappings below are just for debugging purposes.
map <Leader>e :python print get_selected_text()
map <Leader>r :python print current_gpg_block_range()
map <Leader>t :python print current_gpg_block_text()
