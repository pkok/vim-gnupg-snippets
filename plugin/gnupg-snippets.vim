if exists("g:gnupg_snippets_loaded") || &cp
  finish
endif
let g:gnupg_snippets_loaded = 1

python << EOF
import vim
import re
import gnupg

gpg = gnupg.GPG()

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

def encrypt_plaintext(text):
    recipients = []
    header = []
    for line in text.split('\n'):
        if not line.strip():
            break
        header.append(line)
        match = re.match('^for:?', line, re.IGNORECASE)
        if match:
            line = line[match.span()[1]:]
            for r in line.split(','):
                recipients.append(find_gpg_key(r.strip()))
    if not header:
        raise vim.error, "No header for GPG snippet."
    cipher = gpg.encrypt(text, recipients)
    if not cipher.ok:
        raise vim.error, "Could not encrypt."
    return cipher.data

def find_gpg_key(expression):
    candidates = []
    keyring = gpg.list_keys()
    # Expression is the end of a fingerprint
    if re.match("^[0-9A-Fa-f]{8,}$", expression): 
        for key in keyring:
            if key['fingerprint'].endswith(expression.upper()):
                candidates.append(key)
                break
    for key in keyring:
        for uid in key['uids']:
            if expression.lower() in uid.lower():
                candidates.append(key)
    if not candidates:
        # If it is not a user, try to see if it is a group.
        if not candidates:
            raise vim.error, "No matching key found for '%s'" % expression
    if len(candidates) > 1:
        matches = ("- %s (%s)" % (', '.join(key['uids']),
            key['fingerprint'][-8:]) for key in candidates)
        matches = '\n'.join(matches)
        msg = "Key '%s' is ambiguous. Matches found: \n%s"
        raise vim.error, msg % (expression, matches)
    return candidates[0]['fingerprint']

def encrypt_secret_infos():
    store_lines = False
    end = None
    for line_number, line in reversed(list(enumerate(vim.current.buffer))):
        if store_lines:
            if re.match("BEGIN\s+SECRET\s+INFO\s*$", line):
                store_lines = False
                cipher = encrypt_plaintext(get_selected_text(line_number, end+1))
                vim.current.buffer[line_number:end+1] = cipher.split('\n')[:-1]
        if re.match("END\s+SECRET\s+INFO\s*$", line):
            store_lines = True
            end = line_number

def decrypt_pgp(text):
    cipher = gpg.decrypt(text)
    if not cipher.ok:
        raise vim.error, "Could not decrypt."
    return cipher.data

def decrypt_secret_infos():
    store_lines = False
    end = None
    for line_number, line in reversed(list(enumerate(vim.current.buffer))):
        if store_lines:
            if re.match("-{5,}\s*BEGIN\s+PGP\s+MESSAGE\s*-{5,}", line):
                store_lines = False
                try:
                    cipher = decrypt_pgp(get_selected_text(line_number, end))
                    vim.current.buffer[line_number:end+1] = cipher.split('\n')[:-1]
                except vim.error:
                    pass
        if re.match("-{5,}\s*END\s+PGP\s+MESSAGE\s*-{5,}", line):
            store_lines = True
            end = line_number
EOF

function! s:encrypt_secret_infos()
  python encrypt_secret_infos()
endfunction

function! s:decrypt_secret_infos()
  python decrypt_secret_infos()
endfunction

" Key mappings will be of the form '<Leader>s' followed by something more
" specific.  Current mappings:
" - <Leader>se encrypt a range selected by V;
" - <Leader>sd decrypts the current GPG block.
map <Leader>se :python encrypt_secret_infos()<CR>
map <Leader>sd :python decrypt_secret_infos()<CR>

autocmd BufRead,BufWritePost * :python decrypt_secret_infos()
autocmd BufWritePre * :python encrypt_secret_infos()
