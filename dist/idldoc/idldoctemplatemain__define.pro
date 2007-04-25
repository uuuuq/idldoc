;+
; Needed to implement getVariable interface for IDLdocObjTemplate.
;
; @returns variable value or -1L if variable not found
; @param name {in}{optional}{type=string} name of the variable to get;
;          required if NAMES keyword not set
; @keyword found {out}{optional}{type=boolean} returns if the variable
;          was found
; @keyword names {in}{optional}{type=boolean} set to make function return
;          a string array of the available variable names
;-
function idldoctemplatemain::getVariable, name, found=found, names=names
    compile_opt strictarr

    if (keyword_set(names)) then begin
        return, ['version', 'date', 'embed', 'css_location', $
            'print_css_location', 'title', $
            'subtitle', 'user', 'nonavbar', 'navbar_filename', 'footer', $
            'tagline_filename']
    endif

    self._system->getProperty, idldoc_root=idldoc_root, template_prefix=tp

    found = 1B
    case strlowcase(name) of
    'version' : begin
            return, self._system->getVersion()
        end
    'date' : begin
           return, systime()
        end
    'embed' : begin
            self._system->getProperty, embed=embed
            return, embed
        end
    'css_location' : $
        return, filepath('main_files.css', subdir=['resource'], root=idldoc_root)
    'print_css_location' : $
        return, filepath('main_files_print.css', subdir=['resource'], root=idldoc_root)
    'title' : begin
            self._system->getProperty, title=title
            return, title
        end
    'subtitle' : begin
            self._system->getProperty, subtitle=subtitle
            return, subtitle
        end
    'user' : begin
            self._system->getProperty, user=user
            return, user
        end
    'nonavbar' : begin
            self._system->getProperty, nonavbar=nonavbar
            return, nonavbar
        end
    'navbar_filename' : begin
            return, filepath(tp + 'navbar.tt', $
                subdir=['templates'], root=idldoc_root)
        end
    'footer' : begin
            self._system->getProperty, footer=footer
            return, footer
        end
    'tagline_filename' : begin
            return, filepath(tp + 'tagline.tt', $
                subdir=['templates'], root=idldoc_root)
        end
    else : begin
            found = 0B
            return, -1L
        end
    endcase
end


;+
; Destroy object template.
;-
pro idldoctemplatemain::cleanup
    compile_opt strictarr

end


;+
; Initialize the object template.
;
; @returns 1 if success, 0 otherwise
; @param osystem {in}{required}{type=object} IDLdocSystem object
;
;-
function idldoctemplatemain::init, osystem
    compile_opt strictarr

    self._system = osystem

    return, 1
end


;+
; Define member variables.
;
; @file_comments IDLdocTemplateMain implements the getVariable interface for
;                an object template and provides all the common variables
;                which are needed by other classes.
; @field IDLdocSystem object
;-
pro idldoctemplatemain__define
    compile_opt strictarr

    define = { idldoctemplatemain, $
        _system : obj_new() $
        }
end
