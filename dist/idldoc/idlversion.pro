function IDLVersion, idl61=idl61, idl62=idl62
    compile_opt strictarr

    ; determine if IDL has at least IDL 6.1 capabilities
    if (strmid(!version.release, 0, 1) eq '<') then begin
        ; if a development build, then it must have been built in 2005 or later
        idl_build_date = strsplit(!version.build_date, ' ', /extract)
        if (keyword_set(idl61)) then return, long(idl_build_date[2]) ge 2005
        if (keyword_set(idl62)) then return, long(idl_build_date[2]) ge 2006
    endif else begin
        idl_version = long(strsplit(!version.release, '.', /extract))
        if (keyword_set(idl61)) then return, (idl_version[0] gt 6) $
            || (idl_version[0] eq 6 && idl_version[1] ge 1)
        if (keyword_set(idl62)) then return, (idl_version[0] gt 6) $
            || (idl_version[0] eq 6 && idl_version[1] ge 2)
    endelse

    return, 0B
end