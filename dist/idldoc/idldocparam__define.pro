;+
; Gets the portion of the file's search string from this param.
;
; @returns string
;-
function IDLdocParam::get_search_string
    compile_opt idl2

    comments = self->get_comments(empty=empty)
    return, self.name + (empty ? '' : strjoin(comments, ' '))
end


;+
; Handles raw attribute info from IDLdocRoutine parsing.
;
; @param attr {in}{required}{type=string} attribute info
;-
pro IDLdocParam::handle_attr, attr
    compile_opt idl2

    attr_parts = strsplit(attr, '=', /extract)
    val = n_elements(attr_parts) lt 2 ? 'yes' : attr_parts[1]
    self->put_attr, attr_parts[0], val
end


;+
; Get the name of the parameter (case preserved from the header of the routine).
;
; @returns string
;-
function IDLdocParam::get_name
    compile_opt idl2

    return, self.name
end


;+
; Add comments to the current comment lines.
;
; @param comments {in}{required}{type=string, strarr} comments for the parameter
;-
pro IDLdocParam::add_comments, comments
    compile_opt idl2

    *self.comments = n_elements(*self.comments) eq 0 $
        ? comments $
        : [*self.comments, comments]
end


;+
; Find the current comments for the paramater.
;
; @returns string array containing the lines of the comment or the empty string
;          if no comments present
; @keyword empty {out}{optional}{type=boolean} named variable set to 1B if
;          no comments present, 0B if any comments are present
;-
function IDLdocParam::get_comments, empty=empty
    compile_opt idl2

    empty = n_elements(*self.comments) eq 0
    return, empty ? '' : *self.comments
end


;+
; Implements the getVariable method so that IDLdocParam can be used as an
; IDLdocObjTemplate output object. This routine returns a value of a variable
; given the variable's name as a string.
;
; @returns any type
; @param name {in}{required}{type=string}
; @keyword found {out}{optional}{type=boolean} set to named variable to verify
;          the given variable was found
;-
function IDLdocParam::getVariable, name, found=found
    compile_opt strictarr

    if (size(name, /type) ne 7) then begin
        found = 0B
        return, -1L
    endif

    found = 1B
    case name of
    'name' : return, self.name
    'in' : return, self.in
    'out' : return, self.out
    'optional' : return, self.optional
    'required' : return, self.required
    'private' : return, self.private
    'hidden' : return, self.hidden
    'type' : return, self.type
    'boolean' : return, self.type eq 'boolean'
    'default' : return, self.default
    'comments' : begin
            empty = n_elements(*self.comments) eq 0
            return, empty ? '' : *self.comments
        end
    'delim' : begin
            self.routine->getProperty, type=rtype
            return, (rtype eq 'function' && self.first) ? '' : ', '
        end
    else : begin
            found = 0B
            return, -1L
        end
    endcase
end


;+
; Get arrtibutes of the paramater.
;
; @keyword in {out}{optional}{type=boolean} true if the parameter is an input
;          to the routine
; @keyword out {out}{optional}{type=boolean} true if the parameter is an output
;          to the routine
; @keyword type {out}{optional}{type=string} string indicating the type of
;          acceptable values for the parameter
; @keyword optional {out}{optional}{type=boolean} true if the parameter is
;          optional
; @keyword required {out}{optional}{type=boolean} true if the parameter is
;          required
; @keyword default {out}{optional}{type=string} string indicating the default
;          value of the parameter (if the parameter is not passed in)
; @keyword private {out}{optional}{type=boolean} true if the parameter should
;          only be visible to runs of IDLdoc with USER not set
; @keyword hidden {out}{optional}{type=boolean} true if the parameter should not
;          be visible
;-
pro IDLdocParam::get_attr, in=in, out=out, type=type, optional=optional, $
    required=required, default=default, private=private, hidden=hidden
    compile_opt idl2

    in = self.in
    out = self.out
    optional = self.optional
    required = self.required
    private = self.private
    hidden = self.hidden
    type = self.type
    default = self.default
end


;+
; Store the attribute value under the name (as lowercase).
;
; @param name {in}{required}{type=string} attribute name
; @param value {in}{required}{type=string} attribute value
;-
pro IDLdocParam::put_attr, name, value
    compile_opt idl2

    case strlowcase(name) of
    'in' : self.in = 1B
    'out' : self.out = 1B
    'optional' : self.optional = 1B
    'required' : self.required = 1B
    'private' : self.private = 1B
    'hidden' : self.hidden = 1B
    'type' : self.type = value
    'default' : self.default = value
    else :
    endcase
end


;+
; Sets the parameter as the first parameter of a routine.
;-
pro IDLdocParam::setFirst
    compile_opt strictarr

    self.first = 1B
end


;+
; Cleanup resources.
;-
pro IDLdocParam::cleanup
    compile_opt idl2

    ptr_free, self.comments
end


;+
; Initialize the param's attributes to the given names and values.
;
; @returns 1 for success, 0 for failure
; @param routine {in}{required}{type=string} IDLdocRoutine object accepting the
;        parameter
; @keyword name {in}{required}{type=string} name of the parameter
;-
function IDLdocParam::init, routine, name=name
    compile_opt idl2

    self.routine = routine
    self.name = name
    self.comments = ptr_new(/allocate_heap)
    self.first = 0B

    return, 1
end


;+
; Instance variable definition.
;
; @file_comments Object to hold the name, comments, and attributes of a
;                positional parameter or keyword.
; @field routine IDLdocRoutine object that the parameter is found in
; @field name name of the parameter
; @field in true if an input to the routine
; @field out true if an output to the routine
; @field optional true if an optional parameter to a routine
; @field required true if a required parameter to a routine
; @field hidden true if a hidden parameter (no one should see it)
; @field private true if a private parameter (only "developer" should see it)
; @field type description of the IDL type of the allowable variable type(s)
; @field default default value if not passed
; @field comments comment lines
;-
pro IDLdocParam__define
    compile_opt idl2

    define = { IDLdocParam, $
        routine : obj_new(), $
        name : '', $
        in : 0B, $
        out : 0B, $
        optional : 0B, $
        required : 0B, $
        hidden : 0B, $
        private : 0B, $
        type : '', $
        default : '', $
        first : 0B, $
        comments : ptr_new() $
        }
end
