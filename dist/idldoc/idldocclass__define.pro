;+
; Implements the getVariable method so that IDLdocParam can be used as an
; IDLdocObjTemplate output object. This routine returns a value of a variable
; given the variable's name as a string.
;
; @private
; @returns any type
; @param name {in}{required}{type=string} name of the variable
; @keyword found {out}{optional}{type=boolean} true if the variable was found
;-
function IDLdocClass::getVariable, name, found=found
    compile_opt strictarr

    if (size(name, /type) ne 7) then begin
        found = 0B
        return, -1L
    endif

    found = 1B
    case name of
    'classname' : begin
            return, self.classname
        end
    'nfields' : begin
            return, self.fields->count()
        end
    'fields' : begin
            return, self.fields->get(/all)
        end
    'has_superclasses' : return, self.superclasses->count() gt 0
    'all_superclasses' : begin
            if (self.superclasses->count() eq 0) then return, self
            return, (self->getAllSuperclasses())[1:*]
        end
    'has_subclasses' : return, self.subclasses->count() gt 0
    'direct_subclasses' : begin
            if (self.subclasses->count() eq 0) then return, self
            return, self.subclasses->get(/all)
        end
    'url' : begin
            return, (self.url eq '') ? '' : (self.current_root + self.url)
        end
    'known' : return, ~self.unknown
    'first_subclass' : return, self.first_subclass
    'hierarchy' : begin
            max_level = 0L
            total_classes = 0L
            self->setLevel, 0L, max_level=max_level, total_classes=total_classes

            output = strarr(2L * total_classes - 1L)
            self->print, output, 0L, max_level=max_level

            return, output
        end
    else : begin
            found = 0B
            return, -1L
        end
    endcase
end


;+
; Returns all the superclasses (direct and several levels above) of the class.
;
; @returns object array
;-
function IDLdocClass::getAllSuperclasses
    compile_opt strictarr

    super = self
    for s = 0L, self.superclasses->count() - 1L do begin
        osuper = self.superclasses->get(position=s)
        super = [super, osuper->getAllSuperclasses()]
    endfor
    return, super
end


;+
; Find the level above the current class of all the superclasses.
;
; @param level {in}{required}{type=long} level to set the current class;
;        superclasses of this class will be set to level + 1, etc.
; @keyword max_level {in}{out}{required}{type=numeric} maximum level of any
;          of the superclasses above the original class
; @keyword total_classes {in}{out}{required}{type=numeric} total superclasses
;          of the original class
;-
pro IDLdocClass::setLevel, level, max_level=max_level, total_classes=total_classes
    compile_opt strictarr

    total_classes++
    self.hierarchy_level = level
    for s = 0L, self.superclasses->count() - 1L do begin
        osuper = self.superclasses->get(position=s)
        max_level = max_level > (level + 1)
        osuper->setLevel, level + 1, max_level=max_level, total_class=total_classes
    endfor
end


;+
; Print the class hierarchy for the given class. The setLevel method must be
; called first to get the correct max_level to pass in and create an output
; string array of the correct size.
;
; @private
; @param output {out}{required}{type=strarr} current result of the class diagram
;        output
; @param line_number {in}{required}{type=long} array element of output to
;        start placing output
; @keyword max_level {in}{required}{type=long} maximum level of all superclasses
;          above the original class
;-
pro IDLdocClass::print, output, line_number, max_level=max_level
    compile_opt strictarr

    tab = (self.hierarchy_level eq max_level) $
        ? '' $
        : string(bytarr(2 * (max_level - self.hierarchy_level)) + 32B)

    for s = 0L, self.superclasses->count() - 1L do begin
        osuper = self.superclasses->get(position=s)
        osuper->print, output, line_number, max_level=max_level
        if (s ne self.superclasses->count() - 1L) then begin
            output[line_number] = tab + '['
        endif else begin
            output[line_number] = tab + '|'
        endelse
        line_number++
    endfor
    output[line_number] = $
        + tab + (self.superclasses->count() eq 0 ? '  ' : '+-') $
        + (self.url eq '' $
            ? self.classname $
            : ('<a href="' + self.current_root + self.url + '">' $
                + self.classname + '</a>'))
    line_number++
end


;+
; Add a field to the class. Fields added this way should be fields of the
; class, not its superclasses.
;
; @param ofield {in}{required}{type=object} IDLdocField object
;-
pro IDLdocClass::addField, ofield
    compile_opt strictarr

    self.fields->add, ofield
end


;+
; Add a direct superclass to the class.
;
; @param osuper {in}{required}{type=object} IDLdocClass object
;-
pro IDLdocClass::addSuperclass, osuper
    compile_opt strictarr

    self.superclasses->add, osuper
end


;+
; Add a direct subclass to the class.
;
; @param osub {in}{required}{type=object} IDLdocClass object
;-
pro IDLdocClass::addSubclass, osub
    compile_opt strictarr

    self.subclasses->add, osub
end


;+
; Recursively, set the root of the superclasses of the class to a path to the
; library root.
;
; @param root {in}{required}{type=string} path to the library root
;-
pro IDLdocClass::setRoot, root
    compile_opt strictarr

    self.current_root = root
    for i = 0L, self.superclasses->count() - 1L do begin
        osuper = self.superclasses->get(position=i)
        osuper->setRoot, root
    endfor
end


;+
; Marks a class as the first direct subclass of one of its superclass for
; presentation purposes.
;
; @param first {in}{required}{type=boolean} set if marking as first subclass
;-
pro IDLdocClass::markFirstSubclass, first
    compile_opt strictarr

    self.first_subclass = first
end


;+
; Set a property of the class.
;
; @keyword url {in}{optional}{type=string} URL of the class' definition file,
;          relative to the root of the library
; @keyword classname {in}{optional}{type=string} classname of the class,
;          case-sensitive
; @keyword current_root {in}{optional}{type=string} changed by IDLdocFiles
;          to get to get from the file location to the root (so that the URL
;          can be correct)
; @keyword unknown {in}{optional}{type=boolean} set to indicate the class
;          definition is not in the library
;-
pro IDLdocClass::setProperty, url=url, classname=classname, $
    current_root=current_root, unknown=unknown
    compile_opt strictarr

    if (n_elements(url) gt 0) then self.url = url
    if (n_elements(classname) gt 0) then self.classname = classname
    if (n_elements(current_root) gt 0) then begin
        self.current_root = current_root
        for i = 0L, self.superclasses->count() - 1L do begin
            osuper = self.superclasses->get(position=i)
            osuper->setRoot, current_root
        endfor
        for i = 0L, self.subclasses->count() - 1L do begin
            osub = self.subclasses->get(position=i)
            osub->markFirstSubclass, i eq 0L
            osub.current_root = current_root
        endfor
    endif
    if (n_elements(unknown) gt 0) then self.unknown = keyword_set(unknown)
end


;+
; Get properties of the class.
;
; @keyword nfields {out}{optional}{type=long} number of fields of the class,
;          counting only fields of the class itself and not its superclasses
; @keyword fields {out}{optional}{type=objarr} object array of the fields of the
;          class or -1L if class doesn't have any fields
; @keyword url {out}{optional}{type=string} URL of class definition relative to
;          the library root
;-
pro IDLdocClass::getProperty, nfields=nfields, fields=fields, url=url
    compile_opt strictarr

    nfields = self.fields->count()
    fields = self.fields->get(/all)
    url = self.url
end


;+
; Destroy a class.
;-
pro IDLdocClass::cleanup
    compile_opt strictarr

    obj_destroy, [self.fields, self.superclasses, self.subclasses]
end


;+
; Create a class object.
;
; @returns 1
; @param classname {in}{required}{type=string} classname of the class,
;        case-sensitive
;-
function IDLdocClass::init, classname
    compile_opt strictarr

    self.classname = classname
    self.superclasses = obj_new('IDL_Container')
    self.subclasses = obj_new('IDL_Container')
    self.fields = obj_new('IDL_Container')

    return, 1
end


;+
; Define member variables.
;
; @field classname classname of the class
; @field url URL relative from the library root
; @field current_root current path to the library root from a given location
; @field hierarchy_level
; @field superclasses IDL_Container containing direct superclass IDLdocClass
;        objects
; @field subclasses IDL_Container containing direct subclass IDLdocClass objects
; @field fields IDL_Container containing IDLdocField objects for fields of the
;        class (but not its superclasses)
; @field first_subclass set if first subclass of one of its superclasses
;-
pro IDLdocClass__define
    compile_opt strictarr

    define = { IDLdocClass, $
        classname : '', $
        unknown : 0B, $
        url : '', $
        current_root : '', $
        hierarchy_level : 0L, $
        superclasses : obj_new(), $
        subclasses : obj_new(), $
        fields : obj_new(), $
        first_subclass : 0B $
        }
end
