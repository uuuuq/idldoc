;+
; Frees the resources stored in the memento structure.  All mementos must be
; freed using this method.
;
; @param memento {in}{required}{type=structure} memento produced by save_pos
;        method
;-
pro file_tokenizer::free_pos, memento
    compile_opt idl2

end


;+
; Restores the file_tokenizer to the state/location it was in when the given
; memento was produced.
;
; @param memento {in}{required}{type=structure} memento produced by save_pos
;        method
;-
pro file_tokenizer::restore_pos, memento
    compile_opt idl2

    self.line_number = memento.line_number
    *self.tokens = memento.tokens
    *self.token_length = memento.token_length
    self.token_counter = memento.token_counter
    self.line = memento.line
end


;+
; Saves the current state/location of the file_tokenizer in a memento structure.
;
; @returns structure
;-
function file_tokenizer::save_pos
    compile_opt idl2

    memento = { $
        line_number:self.line_number, $
        tokens:*self.tokens, $
        token_length:*self.token_length, $
        token_counter:self.token_counter, $
        line:self.line $
        }

    return, memento
end


;+
; Returns the current line of the tokenized file.
;
; @returns string
; @keyword number {out}{optional}{type=long} line number of returned line
;-
function file_tokenizer::getCurrentLine, number=number
    compile_opt strictarr

    number = self.line_number + 1L

    return, self.line
end


;+
; Returns the next token of the file.
;
; @returns string
; @keyword pre_delim {out}{optional}{type=string} delimiter before the returned token
; @keyword post_delim {out}{optional}{type=string} delimiter after the returned token
; @keyword newline {out}{optional}{type=boolean} true if token is first on a new line
;-
function file_tokenizer::next, pre_delim=pre_delim, post_delim=post_delim, newline=newline
    compile_opt idl2

    if (self->done()) then begin
        pre_delim = ''
        post_delim = ''
        return, ''
    endif

    newline = 0B

    token_start = (*self.tokens)[self.token_counter]
    token_length = (*self.token_length)[self.token_counter]
    token = strmid(self.line, token_start, token_length)

    newline = self.token_counter eq 0 and self.line_number gt 0

    if (arg_present(pre_delim)) then begin
        if (self.token_counter eq 0) then begin
            pre_delim = ''
            if ((*self.tokens)[0] ne 0) then begin
                pre_delim = strmid(self.line, 0, (*self.tokens)[0])
            endif
        endif else begin
            delim_start = (*self.tokens)[self.token_counter - 1L] $
                + (*self.token_length)[self.token_counter - 1L]
            delim_length = (*self.tokens)[self.token_counter] - delim_start
            pre_delim = strmid(self.line, delim_start, delim_length)
        endelse
    endif

    if (arg_present(post_delim)) then begin
        ; if last token on the line
        if (self.token_counter eq n_elements(*self.tokens) - 1) then begin
            post_delim = ''
            delim_start $
                = (*self.tokens)[self.token_counter] $
                    + (*self.token_length)[self.token_counter]
            if (delim_start lt strlen(self.line) - 1) then begin
                post_delim = strmid(self.line, delim_start)
            endif
        endif else begin
            delim_start = (*self.tokens)[self.token_counter] $
                + (*self.token_length)[self.token_counter]
            delim_length = (*self.tokens)[self.token_counter + 1L] - delim_start
            post_delim = strmid(self.line, delim_start, delim_length)
        endelse
    endif


    ++self.token_counter
    return, token
end


;+
; Returns whether there are any more tokens in the file.  Parses a new line of
; the file if necessary.
;
; @returns 1B if no more tokens or 0B otherwise
;-
function file_tokenizer::done
    compile_opt idl2

    ; Already have more tokens in hand, so not done
    if (self.token_counter lt n_elements(*self.tokens)) then return, 0B

    ; Handle: EOF, no tokens
    if (self.line_number ge self.nlines - 1L) then return, 1B

    ; Skip blank lines
    self.line = (*self.data)[++self.line_number]

    ; New tokens
    *self.tokens = strsplit(self.line, self.pattern, /regex, length=len)
    *self.token_length = len
    self.token_counter = 0L

    return, 0B
end


;+
; Resets the tokenizer to the beginning of the tokenized file.
;-
pro file_tokenizer::reset
    compile_opt strictarr

    self.line_number = 0L
end


;+
; Closes the file.
;-
pro file_tokenizer::cleanup
    compile_opt idl2

    ptr_free, self.tokens, self.token_length, self.data
end


;+
; Creates a file_tokenizer for a given file with a given pattern.  Creating the
; file_tokenizer opens the file.
;
; @returns 1 if successful, 0 otherwise
; @param filename {in}{required}{type=string} filename of the file to be
;        tokenized
; @keyword pattern {in}{optional}{type=string}{default=space} regular expression
;          (as in STRPSLIT) to split the text of the file into tokens
;-
function file_tokenizer::init, filename, pattern=pattern
    compile_opt idl2
    on_error, 2

    if (n_params() ne 1) then message, 'filename parameter required'
    self.pattern = n_elements(pattern) eq 0 ? '[[:space:]]' : pattern

    file_present = file_test(filename)
    if (~file_present) then message, 'file not found: ' + filename

    self.nlines = file_lines(filename)
    data = strarr(self.nlines)
    openr, lun, filename, /get_lun
    readf, lun, data
    free_lun, lun

    self.data = ptr_new(data)

    self.tokens = ptr_new(/allocate_heap)
    self.token_length = ptr_new(/allocate_heap)
    self.token_counter = 0L

    self.line_number = -1L

    return, 1
end


;+
; Define instance variables.
;
; @file_comments The file_tokenizer class is a class to split a file into
;                tokens.
;
; @field data contents of file to be tokenized
; @field pattern regular expression to split lines on
; @field line_number indicates the line number in the file of line (starts at 0)
; @field nlines number of lines in file to be tokenized
; @field line current line read by tokenizer
; @field tokens pointer to long array which indicates the beginnings of the
;        tokens in line
; @field token_length pointer to long array which indicates the length of the
;        tokens in line
; @field token_counter next token in tokens and token_length
;
; @requires IDL 6.0
;
; @categories input/output
;
; @author Michael Galloy
; @history Created October, 8, 2003
; @copyright RSI, 2003
;-
pro file_tokenizer__define
    compile_opt idl2

    define = { file_tokenizer, $
        data : ptr_new(), $
        pattern : '', $
        line_number : 0L, $
        nlines : 0L, $
        line : '', $
        tokens : ptr_new(), $
        token_length : ptr_new(), $
        token_counter : 0L $
        }
end
