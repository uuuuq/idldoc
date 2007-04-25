;+
; Implements the getVariable method so that IDLdocParam can be used as an
; IDLdocObjTemplate output object. This routine returns a value of a variable
; given the variable's name as a string.
;
; @private
; @returns any typfe
; @param name {in}{required}{type=string} name of the variable
; @keyword found {out}{optional}{type=boolean} true if the variable was found
;-
function IDLdocField::getVariable, name, found=found
    compile_opt strictarr

    if (size(name, /type) ne 7) then begin
        found = 0B
        return, -1L
    endif

    found = 1B
    case strlowcase(name) of
    'name' : return, self.name
    'type' : return, self.type
    'comments' : return, self.comments->is_empty() ? '' : self.comments->to_array()
    else : begin
            found = 0B
            return, -1L
        end
    endcase
end


;+
; Get properties of the field.
;
; @keyword name {out}{optional}{type=string} name of the field
;-
pro IDLdocField::getProperty, name=name
    compile_opt strictarr

    name = self.name
end


;+
; Set properties of a field object.
;
; @keyword name {in}{optional}{type=string} name of field, mixed-case
; @keyword type {in}{optional}{type=string} nice name of field type
; @keyword comments {in}{optional}{type=strarr} comment block, added to existing
;          comments
;-
pro IDLdocField::setProperty, name=name, type=type, comments=comments
    compile_opt strictarr

    if (n_elements(name) gt 0) then self.name = name
    if (n_elements(type) gt 0) then self.type = type
    if (n_elements(comments) gt 0) then self.comments->add, comments
end


;+
; Destroy a field object.
;-
pro IDLdocField::cleanup
    compile_opt strictarr

    obj_destroy, self.comments
end


;+
; Create a field object.
;
; @returns 1
; @param name {in}{required}{type=string} name of the field, mixed-case
;-
function IDLdocField::init, name
    compile_opt strictarr

    self.name = name
    self.comments = obj_new('array_list', type=7, block_size=4)

    return, 1
end


;+
; Define instance variables of a field.
;
; @file_comments Represents a field of a class.
;
; @field name name of the field, mixed-case
; @field type nice type name of a field
; @field comments comment block for a field
;-
pro IDLdocField__define
    compile_opt strictarr

    define = { IDLdocField, $
        name : '', $
        type : '', $
        comments : obj_new() $
        }
end