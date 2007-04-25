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
function IDLdocFile::getVariable, name, found=found
    compile_opt strictarr

    if (size(name, /type) ne 7) then begin
        found = 0B
        return, -1L
    endif

    val = self->idldoctemplatemain::getVariable(name, found=found)
    if (found) then return, val

    found = 1B
    case strlowcase(name) of
    'has_fields' : return, ~self.fields->is_empty()
    'is_class' : return, obj_valid(self.class)
    'class' : begin
            return, self.class
        end
    'fields' : begin
            if (self.fields->is_empty()) then return, ''
            names = self.fields->keys()
            ind = sort(names)
            return, (self.fields->values())[ind]
        end
    'pro_file' : return, file_basename(self.filename)
    'pro_dir' : begin
            dir = file_dirname(self.filename, /mark_directory)
            return, strlen(dir) eq 2 ? dir : strmid(dir, 2)
        end
    'root' : return, self.relative_root
    'file_comments' : return, self.routines->is_empty() ? '' : self->get_file_comments()
    'nroutines' : return, self.n_routines
    'routines' : return, self.n_routines gt 0 ? *self.visible_routines : -1L
    'last_modified' : begin
            info = file_info(self.root + self.filename)
            return, systime(0, info.mtime)
        end
    'overview_href' : begin
            self.system->getProperty, assistant=assistant
            return, self.relative_root + (assistant ? 'home.html' : 'overview.html')
        end
    'overview_selected' : return, 0B
    'dir_overview_href' : return, ''
    'dir_overview_selected' : return, 0B
    'categories_href' : return, self.relative_root + 'idldoc-categories.html'
    'categories_selected' : return, 0B
    'index_href' : return, self.relative_root + 'idldoc-index.html'
    'index_selected' : return, 0B
    'search_href' : return, self.relative_root + 'search-page.html'
    'search_selected' : return, 0B
    'file_selected' : return, 1B
    'source_href' : return, self.root eq self.output $
        ? file_basename(self.filename) $
        : ''
    'source_selected' : return, 0B
    'help_href' : return, self.relative_root + 'idldoc-help.html'
    'help_selected' : return, 0B
    'etc_selected' : return, 0B
    'next_file_href' : return, (self.next eq '' $
        ? '' $
        : idldoc_elim_slash(idldoc_pro_to_html(self.next)))
    'prev_file_href' : return, (self.prev eq '' $
        ? '' $
        : idldoc_elim_slash(idldoc_pro_to_html(self.prev)))
    'view_single_page_href' : $
        return, idldoc_elim_slash(idldoc_pro_to_html(file_basename(self.filename)))
    'view_frames_href' : return, self.relative_root + 'index.html'
    'summary_fields_href' : return, (self.fields->is_empty() ? '' : '#field_summary')
    'summary_routine_href' : begin
            return, (self->num_visible_routines() gt 1 ? '#routine_summary' : '')
        end
    'details_routine_href' : return, '#routine_details'
    else : begin
            found = 0B
            return, -1L
        end
    endcase
end


;+
; Retrieves properties of the file.
;
; @keyword url {out}{optional}{type=string} relative url from root
; @keyword nlines {out}{optional}{type=long} number of lines in the file
; @keyword visible_routines {out}{optional}{type=objarr} array of visible
;          IDLdocRoutine objects or -1L if there are none
; @keyword n_visible_routines {out}{optional}{type=long} number of visible
;          routines in the file
;-
pro IDLdocFile::getProperty, $
    url=url, nlines=nlines, $
    visible_routines=visible_routines, $
    n_visible_routines=n_visible_routines

    compile_opt idl2

    if (arg_present(url)) then begin
        bname = byte(idldoc_pro_to_html(self.filename))

        ; Convert ASCII 92 (backslash) -> ASCII 47 (forward slash)
        ind = where(bname eq 92B, count)
        if (count gt 0) then  bname[ind] = 47B

        url = string(bname)
    endif

    visible_routines = self.n_routines eq 0 ? -1L : *self.visible_routines
    n_visible_routines = self.n_routines
    nlines = self.nlines
end


;+
; Gets the string used by the Search page to search in this file.
;
; @returns string
;-
function IDLdocFile::get_search_string
    compile_opt idl2

    return, self.search_string
end


;+
; File is hidden if an routine in it is hidden.
;
; @returns 1 if file is hidden using "hidden_file" attribute to any routine
;          in the file, 0 otherwise
;-
function IDLdocFile::is_hidden
    compile_opt idl2

    hidden = 0B
    iter = self.routines->iterator()
    while (not iter->done()) do begin
        r = iter->next()
        r->getProperty, hidden_file=hidden_file
        if (hidden_file) then begin
            hidden = 1B
            break
        endif
    endwhile
    obj_destroy, iter

    return, hidden
end


;+
; File is private if any routine in it is private.
;
; @returns 1 if file is private using "private_file" attribute to any routine
;          in the file
;-
function IDLdocFile::is_private
    compile_opt idl2

    private = 0B
    iter = self.routines->iterator()
    while (not iter->done()) do begin
        r = iter->next()
        r->getProperty, private_file=private_file
        if (private_file) then begin
            private = 1B
            break
        endif
    endwhile
    obj_destroy, iter

    return, private
end


;+
; Finds the number of visible (not hidden) routines in the file.  This number
; depends on whether the USER keyword is set.  Private + /USER -> Hidden.
;
; @returns integer
;-
function IDLdocFile::num_visible_routines
    compile_opt idl2

    if (self.n_routines ne 0) then return, self.n_routines

    num = 0L
    iter = self.routines->iterator()
    visroutines = obj_new('array_list', type=11)
    while (not iter->done()) do begin
        r = iter->next()
        r->getProperty, hidden_routine=hidden_routine
        if (~hidden_routine) then begin
            num++
            visroutines->add, r
        endif
    endwhile
    obj_destroy, iter

    self.n_routines = num
    *self.visible_routines = visroutines->to_array()
    obj_destroy, visroutines
    return, num
end


;+
; Adds a comment to the field summary.
;
; @param comment {in}{required}{type=strarr} comment
;-
pro IDLdocFile::add_field, comment
    compile_opt idl2

    full_line = strjoin(comment, ' ')
    pos = stregex(full_line, '[_$[:alnum:]]+', len=len)
    if (pos eq -1) then return

    field_name = strmid(full_line, pos, len)

    lines_length = strlen(comment) + 1  ; +1 for the spaces added in STRJOIN
    clines_length = total(lines_length, /cumulative)
    ind = where(clines_length ge pos + len, count)
    comment_line = ind[0]
    comment_pos = pos + len - (clines_length[ind[0]] - lines_length[ind[0]])

    comments = comment[comment_line:*]
    comments[0] = strmid(comments[0], comment_pos)

    ofield = self.fields->get(strupcase(field_name), found=found)
    if (found) then begin
        ofield->setProperty, comments=comments, name=field_name
    endif else begin
        ; Probably should do a warning like below, but what if there are
        ; multiple class definitions in a file or if the file doesn't have the
        ; right name? It causes many "false positive" errors.
        ;
        ; self.system->addWarning, 'Field ' + field_name + ' not found in ' + self.filename
    endelse
end


;+
; Get the IDLdcRoutine object references in a array_list object of IDLdocRoutines.
;
; @returns array_list object
;-
function IDLdocFile::get_routines
    compile_opt idl2

    return, self.routines
end


;+
; Returns the file comments for a file.
;
; @private
; @returns string array or string (if first_sentence is set)
; @keyword first_sentence {in}{optional}{type=boolean} set to receive
;          just the first sentence of the file comments
; @keyword found {out}{optional}{type=boolean} send a named variable
;          to get whether the comments were found
;-
function IDLdocFile::get_file_comments, first_sentence=first_sentence, $
    found=found
    compile_opt idl2

    found = 0B
    fcomments = obj_new('array_list', type=7)

    iter = self.routines->iterator()
    while (not iter->done()) do begin
        r = iter->next()
        com = r->get_file_comments(empty=empty)
        if (not empty) then begin
            fcomments->add, com
            found = 1B
        endif
    endwhile
    obj_destroy, iter

    file_comments = fcomments->to_array()
    obj_destroy, fcomments

    if (found and keyword_set(first_sentence)) then begin
        file_comments = strjoin(file_comments, ' ')
        pos = strsplit(file_comments, '.', length=len)
        add_dot = strlen(file_comments) gt len[0]
        file_comments = strmid(file_comments, 0, len[0])
        if (add_dot) then file_comments = file_comments + '.'
    endif

    return, found ? file_comments : ''
end


;+
; Parse the input file into chunks of code for each routine.  Creates the
; IDLdcRoutine objects for each one of the routines.
;
; @keyword warnings {in}{out}{type=int}{optional} a named variable to return
;          the number of warning messages
;-
pro IDLdocFile::parse, warnings=warnings
    compile_opt idl2

    basename = file_basename(self.filename)
    define_pos = stregex(basename, '__define.pro$', /fold_case)
    if (define_pos ne -1) then begin
        classname = strmid(basename, 0, define_pos)
        self.system->getProperty, classhierarchy=och
        och->addClass, classname
        self.class = och->getClass(classname)
        self.class->setProperty, classname=classname
        ; tell class its URL
        self->getProperty, url=url
        self.class->setProperty, url=url
        self.class->getProperty, fields=fields, nfields=nfields
        for i = 0L, nfields - 1L do begin
            fields[i]->getProperty, name=name
            self.fields->put, name, fields[i]
        endfor
    endif

    self.system->getProperty, index=index
    index->add_item, $
        name=file_basename(self.filename), $
        url=idldoc_elim_slash(idldoc_pro_to_html(self.filename)), $
        description='a file from the directory ' + file_dirname(self.filename)

    line = ''
    nlines = 0
    continuation = 0
    inside = 0

    starts = [0]
    ends = [0]

    while (not eof(self.lun)) do begin
        readf, self.lun, line
        first_word = strlowcase(get_first_word(line))
        last_char = last_char(strtrim(remove_comment(line), 2))

        if (((first_word eq 'pro') or $
            (first_word eq 'function') or $
            (strmid(first_word, 0, 2) eq ';+')) and $
            (not inside)) then begin

            starts = [ starts, nlines ]
            inside = 1
        endif

        first_char = strmid(strtrim(line, 1), 0, 1)
        if (((first_word eq 'pro') or (first_word eq 'function') or $
            continuation)) then begin
            if ((last_char eq '$') or (first_char eq ';'))  then $
                continuation = 1 $
            else begin
                continuation = 0
                ends = [ ends, nlines ]
                inside = 0
            endelse
        endif

        if (continuation and (last_char ne '$') and (first_char ne ';')) then continuation = 0
        ;continuation = idldoc_continuation(line)

        nlines = nlines + 1
    endwhile

    self.nlines = nlines

    n_routines = n_elements(ends) - 1
    if (n_routines le 0) then return

    if (n_elements(starts) ne n_elements(ends)) then begin
        msg = 'invalid comment syntax in ' + self.filename
        self.system->addWarning, msg
    endif

    all_code = strarr(nlines)
    point_lun, self.lun, 0
    readf, self.lun, all_code

    self.search_string = str_replace(strjoin(all_code, ' '), '<[^>]*>', '', /global)
    self.search_string = str_replace(self.search_string, '[^[:alnum:]_: ]+', ' ', /global)

    starts = starts[1:*]
    ends = ends[1:*]
    starts = [starts, nlines]

    for i = 0, n_routines - 1 do begin
        self.routines->add, $
            obj_new('IDLdocRoutine', $
                all_code[starts[i]:ends[i]], $
                all_code[starts[i]:starts[i+1]-1], $
                warnings=warnings, $
                filename=self.filename, $
                file_ref=self, $
                start_line_number=starts[i] + 1L, $
                system=self.system)
    endfor

    n = self->num_visible_routines()
end


;+
; Output file's info to a file.
;-
pro IDLdocFile::output
    compile_opt strictarr

    reloutpath = file_dirname(self.filename)
    outpath = self.output + (reloutpath eq '.' ? '' : reloutpath + path_sep())
    outfilename = outpath + file_basename(self.filename, '.pro') + '.html'

    if (not file_test(outpath, /directory)) then begin
        file_mkdir, outpath
    endif

    if (obj_valid(self.class)) then begin
        self.class->setProperty, current_root=self.relative_root
    endif

    openw, lun, outfilename, /get_lun, error=error
    if (error ne 0) then begin
        self.system->addWarning, 'Error opening ' + outfilename + ' for writing.'
        return
    endif

    self.system->getProperty, idldoc_root=idldoc_root, file_template=oTemplate

    oTemplate->reset
    oTemplate->process, self, lun=lun

    free_lun, lun
end


;;+
;; Generates output for the entire file in a file with the same path as the
;; input .pro file, but with an .html extension.
;;-
;pro IDLdocFile::output
;    compile_opt idl2
;
;    reloutpath = file_dirname(self.filename)
;    outpath = self.output + (reloutpath eq '.' ? '' : reloutpath + path_sep())
;    outfilename = outpath + file_basename(self.filename, '.pro') + '.html'
;
;    slashes = stroccur(self.filename, '\/:', count=levels)
;    root = ''
;    for i = 0, levels - 2 do $
;        root = root + '../'
;    if (not file_test(outpath, /directory)) then begin
;        file_mkdir, outpath
;    endif
;
;    openw, lun, outfilename, /get_lun, error=error
;    if (error ne 0) then begin
;        osystem->addWarning, 'Error opening ' + filename + ' for writing.'
;        return
;    endif
;
;    self.system->getProperty, title=title, subtitle=subtitle, user=user, $
;        embed=embed, nonavbar=nonavbar, idldoc_root=idldoc_root, $
;        footer=footer, template_prefix=tp, assistant=assistant
;
;    multi_routines = self->num_visible_routines() gt 1
;
;    info = file_info(self.root + self.filename)
;;    if (stregex(self.filename, '__define.pro$', /fold_case) ne -1) then begin
;;            class_name = file_basename(self.filename)
;;            class_name = stregex(class_name, '(.*)__define.pro$', /fold_case, $
;;                /extract, /subexpr)
;;            diagram = class_diagram(class_name[1], space_str='&nbsp;', $
;;                root=self.root, path=path, all_superclasses=all_superclasses, $
;;                field_names=field_names, field_types=field_types, $
;;                field_sizes=field_sizes, $
;;                field_classes=field_classes, class_files=class_files, $
;;                fields_found=fields_found)
;;            for i = 0, n_elements(diagram) - 1 do begin
;;                diagram[i] = char_replace(diagram[i], '\', '/')
;;            endfor
;;            for i = 0, n_elements(all_superclasses) - 1 do begin
;;                all_superclasses[i] = char_replace(all_superclasses[i], '\', '/')
;;            endfor
;;            if (n_elements(diagram) gt 1) then begin
;;                printf, lun, '<PRE>'
;;                for i = 0, n_elements(diagram) - 1 do begin
;;                    printf, lun, diagram[i]
;;                endfor
;;                printf, lun, '</PRE>'
;;                printf, lun, '<P>'
;;
;;                printf, lun, '<DL>'
;;                printf, lun, '<DT CLASS="attribute">All known superclasses:'
;;                printf, lun, '<DD>' + strjoin(all_superclasses, ', ') + '</DD></DT>'
;;            endif else begin
;;                printf, lun, '<DL>'
;;            endelse
;;    endif
;    comments = self.routines->is_empty() ? '' : self->get_file_comments()
;
;    sdata = { $
;        root : root, $
;        multi_routines : multi_routines, $
;        pro_file : file_basename(self.filename), $
;        pro_dir : reloutpath, $
;        nsuperclasses : 0, $
;        superclasses : { name:'', url:'', delim:'' }, $
;        last_modified : systime(0, info.mtime), $
;        comments : comments, $
;        version : self.system->getVersion(), $
;        date : systime(), $
;        embed : embed, $
;        css_location : $
;            filepath('main_files.css', subdir=['resource'], root=idldoc_root), $
;        title : title, $
;        subtitle : subtitle, $
;        user : user, $
;        nonavbar : nonavbar, $
;        navbar_filename : $
;            filepath(tp + 'navbar.tt', subdir=['templates'], root=idldoc_root), $
;        overview_href : root + (assistant ? 'home.html' : 'overview.html'), $
;        overview_selected : 0B, $
;        dir_overview_href : '', $
;        dir_overview_selected : 0B, $
;        categories_href : root + 'idldoc-categories.html', $
;        categories_selected : 0B, $
;        index_href : root + 'idldoc-index.html', $
;        index_selected : 0B, $
;        search_href : root + 'search-page.html', $
;        search_selected : 0B, $
;        file_selected : 1B, $
;        source_href : self.root eq self.output $
;            ? file_basename(self.filename) $
;            : '', $
;        source_selected : 0B, $
;        help_href : root + 'idldoc-help.html', $
;        help_selected : 0B, $
;        etc_selected : 0B, $
;        next_file_href : (self.next eq '' $
;            ? '' $
;            : idldoc_elim_slash(idldoc_pro_to_html(self.next))), $
;        prev_file_href : (self.prev eq '' $
;            ? '' $
;            : idldoc_elim_slash(idldoc_pro_to_html(self.prev))), $
;        view_single_page_href : $
;            idldoc_elim_slash(idldoc_pro_to_html(self.filename)), $
;        view_frames_href : root + 'index.html', $
;        summary_fields_href : '', $
;        summary_routine_href : (multi_routines ? '#routine_summary' : ''), $
;        details_routine_href : '#routine_details', $
;        footer : footer, $
;        tagline_filename : $
;            filepath(tp + 'tagline.tt', subdir=['templates'], root=idldoc_root) $
;        }
;
;    ; write pro-file-begin.tt: navbar, class diagram, file attributes, comments
;    oTemplate = obj_new('template', $
;        filepath(tp + 'pro-file-begin.tt', subdir=['templates'], root=idldoc_root))
;    oTemplate->process, sdata, lun=lun
;    obj_destroy, oTemplate
;
;    ; write field summary
;    ; write each inherited list of fields
;    ; write summary for each routine
;    if (multi_routines) then begin
;        blank = { date : systime() }
;        oTemplate = obj_new('template', $
;            filepath(tp + 'pro-file-summary-begin.tt', $
;                subdir=['templates'], root=idldoc_root))
;        oTemplate->process, blank, lun=lun
;        obj_destroy, oTemplate
;
;        for r = 0L, self.routines->size() - 1L do begin
;            oroutine = self.routines->get(r)
;            rhdata = oroutine->get_header_info()
;            oTemplate = obj_new('template', $
;                filepath(tp + 'pro-file-summary-routine.tt', $
;                    subdir=['templates'], root=idldoc_root))
;            oTemplate->process, rhdata, lun=lun
;            obj_destroy, oTemplate
;        endfor
;
;        oTemplate = obj_new('template', $
;            filepath(tp + 'pro-file-summary-end.tt', $
;                subdir=['templates'], root=idldoc_root))
;        oTemplate->process, blank, lun=lun
;        obj_destroy, oTemplate
;    endif
;
;    oTemplate = obj_new('template', $
;        filepath(tp + 'pro-file-details-begin.tt', $
;            subdir=['templates'], root=idldoc_root))
;    oTemplate->process, blank, lun=lun
;    obj_destroy, oTemplate
;
;    ; write each routine
;    for r = 0L, self.routines->size() - 1L do begin
;        oroutine = self.routines->get(r)
;        oroutine->output, lun=lun
;    endfor
;
;    oTemplate = obj_new('template', $
;        filepath(tp + 'pro-file-details-end.tt', $
;            subdir=['templates'], root=idldoc_root))
;    oTemplate->process, blank, lun=lun
;    obj_destroy, oTemplate
;
;    ; write footer/tagline
;    oTemplate = obj_new('template', $
;        filepath(tp + 'pro-file-end.tt', subdir=['templates'], root=idldoc_root))
;    oTemplate->process, sdata, lun=lun
;    obj_destroy, oTemplate
;
;    free_lun, lun
;end
;

;    if (not keyword_set(self.user)) then begin
;        define_pos = stregex(basename, '__define.pro$', /fold_case)
;        if (define_pos ne -1) then begin
;            class = strmid(basename, 0, define_pos)
;            found = idldoc_class_fields(class, names=names, types=types)
;            if (found) then href_fields = '#_fields_summary'
;        endif
;    endif
;
;    multi_routines = self->num_visible_routines() gt 1
;
;    ; Check to see if the file is a class definition
;    if (stregex(self.filename, '__define.pro$', /fold_case) ne -1) then begin
;            class_name = file_basename(self.filename)
;            class_name = stregex(class_name, '(.*)__define.pro$', /fold_case, $
;                /extract, /subexpr)
;            diagram = class_diagram(class_name[1], space_str='&nbsp;', $
;                root=self.root, path=path, all_superclasses=all_superclasses, $
;                field_names=field_names, field_types=field_types, $
;                field_sizes=field_sizes, $
;                field_classes=field_classes, class_files=class_files, $
;                fields_found=fields_found)
;            for i = 0, n_elements(diagram) - 1 do begin
;                diagram[i] = char_replace(diagram[i], '\', '/')
;            endfor
;            for i = 0, n_elements(all_superclasses) - 1 do begin
;                all_superclasses[i] = char_replace(all_superclasses[i], '\', '/')
;            endfor
;            if (n_elements(diagram) gt 1) then begin
;                printf, lun, '<PRE>'
;                for i = 0, n_elements(diagram) - 1 do begin
;                    printf, lun, diagram[i]
;                endfor
;                printf, lun, '</PRE>'
;                printf, lun, '<P>'
;
;                printf, lun, '<DL>'
;                printf, lun, '<DT CLASS="attribute">All known superclasses:'
;                printf, lun, '<DD>' + strjoin(all_superclasses, ', ') + '</DD></DT>'
;            endif else begin
;                printf, lun, '<DL>'
;            endelse
;    endif else begin
;        printf, lun, '<DL>'
;    endelse
;
;    ; Instance variables if name ends in __define
;    if (not keyword_set(self.user)) then begin
;        basename = file_basename(self.filename)
;        define_pos = stregex(basename, '__define.pro$', /fold_case)
;        if ((define_pos ne -1) and keyword_set(fields_found)) then begin
;            class = strmid(basename, 0, define_pos)
;            top_level_fields = where(field_classes eq strupcase(class), n_tlf)
;            if (n_tlf gt 0) then begin
;                printf, lun, '<TABLE CELLPADDING="3" CELLSPACING="0" ' $
;                    + 'CLASS="listing">'
;                printf, lun, '<TR><TD COLSPAN=2 CLASS="title">'
;                printf, lun, '<A NAME="_fields_summary">Fields Summary</A>'
;                printf, lun, '</TD></TR>'
;
;                for i = 0, n_tlf - 1 do begin
;                    printf, lun, '<TR>'
;                    printf, lun, '<TD ALIGN="right" VALIGN="top" WIDTH="1%">'
;                    printf, lun, '<FONT CLASS="param_name">' $
;                        + field_names[top_level_fields[i]] + '</FONT><BR>'
;                    printf, lun, '<FONT CLASS="param_attrib"><NOBR>'
;                    printf, lun, type_name(field_types[top_level_fields[i]])
;                    printf, lun, field_sizes[top_level_fields[i]]
;                    printf, lun, '</NOBR></FONT>'
;                    ;printf, lun, '<FONT CLASS="param_attrib">' $
;                    ;    + field_classes[top_level_fields[i]] + '</FONT><BR>'
;                    printf, lun, '</TD>'
;                    printf, lun, '<TD VALIGN="top">'
;                    ocomments = self.fields->get(field_names[top_level_fields[i]], $
;                        found=found)
;                    if (found) then begin
;                        comments = ocomments->to_array(empty=empty)
;                        if (empty) then comments = ['.']
;                    endif else comments = ['.']
;                    printf, lun, transpose(comments)
;                    printf, lun, '</TD>'
;                    printf, lun, '</TR>'
;                endfor
;
;                printf, lun, '</TABLE>'
;            endif
;
;            for i = 0, n_elements(all_superclasses) - 1 do begin
;                class_name = stregex(all_superclasses[i], '>(.*)<', /subexpr, /extract)
;                class_name = class_name[1]
;
;                if (class_name eq '') then class_name = all_superclasses[i]
;
;                fields = where(field_classes eq class_name, n_fields)
;
;                if (n_fields gt 0) then begin
;                    printf, lun, '<P>'
;                    printf, lun, '<TABLE CELLPADDING="3" CELLSPACING="0" CLASS="minor_listing">'
;                    printf, lun, '<TR BGCOLOR="#EEEEFF"><TD><B>Fields inherited from ' $
;                        + all_superclasses[i] + ':</B></TD></TR>'
;                    printf, lun, '<TR><TD>'
;
;                    printf, lun, '<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">'
;                    printf, lun, '<TR><TD ALIGN="RIGHT">' $
;                        + type_name(field_types[fields]) + '&nbsp;' $
;                        + field_sizes[fields] + '&nbsp;</TD>' $
;                        + '<TD><B>' + field_names[fields] + '</B></TD></TR>'
;
;                    printf, lun, '</TABLE>'
;
;                    printf, lun, '</TD></TR>'
;                    printf, lun, '</TABLE>'
;                endif
;            endfor
;
;            printf, lun, '<P>'
;        endif
;    endif
;


;+
; Standard cleanup procedure.
;-
pro IDLdocFile::cleanup
    compile_opt idl2

    self->idldoctemplatemain::cleanup

    routines = self.routines->to_array(empty=no_routines)
    if (~no_routines) then obj_destroy, routines
    obj_destroy, self.routines

    fields = self.fields->values(nfields)
    if (nfields gt 0) then obj_destroy, fields
    obj_destroy, self.fields

    ptr_free, self.visible_routines
end


;+
; Constructor for the IDLdocFile class.
;
; @returns 1 on success; 0 on failure
; @param filename {in} {type=string} The filename of the file to read, parse,
;        and create a doc HTML page for.
; @keyword system {in}{required}{type=objref} IDLdocSystem object
; @keyword output {in}{optional}{type=string} directory to place output
; @keyword root {in} {type=string} root of directory tree
; @keyword next {in} {type=string} {optional} filename of the next file in the
;          directory in alphabetical order
; @keyword prev {in} {type=string} {optional} filename of the previous file
;          in the directory in alphabetical order
;-
function IDLdocFile::init, filename, system=system, $
    output=output, root=root, next=next, prev=prev
    compile_opt idl2

    if (~self->idldoctemplatemain::init(system)) then return, 0

    self.system = system
    self.routines = obj_new('array_list', type=11, block_size=5)
    self.visible_routines = ptr_new(/allocate_heap)

    self.filename = filename
    self.output = output
    self.root = root

    slashes = stroccur(self.filename, '\/:', count=levels)
    self.relative_root = './'
    for i = 0, levels - 2 do self.relative_root += '../'

    self.fields = obj_new('hash_table', array_size=11, key_type=7, value_type=11)

    self.next = file_dirname(next) eq file_dirname(filename) ? $
        file_basename(next) : ''
    self.prev = file_dirname(prev) eq file_dirname(filename) ? $
        file_basename(prev) : ''
    warnings = 0

    ; read_filename = root + filename
    read_filename = root + strmid(filename, 2)

    openr, lun, read_filename, /get_lun, error=err
    if (err eq 0) then begin
        self.lun = lun
        self->parse, warnings=warnings
        free_lun, self.lun
        return, 1
    endif else return, 0
end


;+
; Instance variable declaration.
;
; @field filename filename relative to the ROOT
; @field output directory to place output files (with trailing slash)
; @author Michael D. Galloy
; @copyright RSI, 2001
;-
pro IDLdocFile__define
    compile_opt idl2

    define = { IDLdocFile, $
        inherits idldoctemplatemain, $
        system : obj_new(), $
        filename  : '', $
        nlines : 0L, $
        search_string : '', $
        next : '', $
        prev : '', $
        lun : 0L, $
        output : '', $
        relative_root : '', $
        root : '', $
        n_routines : 0L, $
        routines : obj_new(), $    ; array_list of IDLdocRoutines
        visible_routines : ptr_new(), $
        fields : obj_new(), $
        class : obj_new() $
        }
end
