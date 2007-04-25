;+
; Creates a visualization of an variable, if possible.
;
; @returns 1 if visualization is created, 0 otherwise
; @param var {in}{required}{type=numeric variable} variable to visualize
; @keyword image {out}{optional}{type=bytarr(3, 64, height)} true color image of
;          visualization of var; the height of the image depends on the type of
;          visualization created and the size of the data
;-
function idldoc_make_variable_image, var, image=image
    compile_opt strictarr

    ss = size(var, /structure)

    ; can't visualize some variable types
    if (ss.type eq 0 or $ ; undefined
        ss.type eq 7 or $ ; string
        ss.type eq 8 or $ ; structure
        ss.type eq 10 or $ ; pointer
        ss.type eq 11 ) then begin ; object
        return, 0
    endif

    width = 64.0
    golden_ratio = 1.61803399

    ; start object graphics hierarchy
    oview = obj_new('IDLgrView')

    omodel = obj_new('IDLgrModel')
    oview->add, omodel

    threeD = 0B
    result = 0B

    case 1B of
    ss.n_dimensions eq 0 :

    ; Vector: create a line plot
    ss.n_dimensions eq 1 : begin
            dims = [width, long(width / golden_ratio)]

            oatom = obj_new('IDLgrPlot', var, thick=1)

            out_range = [-1.0, 1.0]

            result = 1B
        end

    ; 2D array: create an image
    ss.n_dimensions eq 2 : begin
            factor = (ss.dimensions[0] > ss.dimensions[1]) / width
            dims = (ss.dimensions / factor)[0:1]

            oatom = obj_new('IDLgrImage', bytscl(var), greyscale=1)

            out_range = [-1.0, 1.0]

            result = 1B
        end

    ; 3D array:
    ;   if one dim is 3 then create an TrueColor image
    ;   otherwise create an isosurface of a volume
    ss.n_dimensions eq 3 : begin
            ind = where(ss.dimensions eq 3, count)
            if (count gt 0) then begin
                ; TrueColor image
                oatom = obj_new('IDLgrImage', var, interleave=ind[0])

                oatom->getProperty, dimensions=dims
                dims = dims * width / max(dims)

                out_range = [-1.0, 1.0]

                result = 1B
            endif else begin
                ; Volume
                dims = [width, width]

                oatom = obj_new('IDLgrVolume', var)

                out_range = [-0.70, 0.70]

                omodel->rotate, [1, 0, 0], -90
                omodel->rotate, [0, 1, 0], 30
                omodel->rotate, [1, 0, 0], 45

                threeD = 1B
                result = 1B
            endelse
        end

    ss.n_dimensions gt 3 :
    endcase

    if result then begin
        omodel->add, oatom

        ; set coordinate conversion factors
        oatom->getProperty, xrange=xr, yrange=yr, zrange=zr

        if (xr[0] eq xr[1]) then begin
            xr[0] -= 0.5
            xr[1] += 0.5
        endif
        if (yr[0] eq yr[1]) then begin
            yr[0] -= 0.5
            yr[1] += 0.5
        endif
        if (zr[0] eq zr[1]) then begin
            zr[0] -= 0.5
            zr[1] += 0.5
        endif

        xc = [out_range[0] * xr[1] - out_range[1] * xr[0], $
            out_range[1] - out_range[0]] / (xr[1] - xr[0])
        yc = [out_range[0] * yr[1] - out_range[1] * yr[0], $
            out_range[1] - out_range[0]] / (yr[1] - yr[0])
        zc = [out_range[0] * zr[1] - out_range[1] * zr[0], $
            out_range[1] - out_range[0]] / (zr[1] - zr[0])

        oatom->setProperty, xcoord_conv=xc, ycoord_conv=yc
        if threeD then oatom->setProperty, zcoord_conv=zc

        ; draw to buffer and get resulting image
        obuffer = obj_new('IDLgrBuffer', dimensions=ceil(dims))
        obuffer->draw, oview
        obuffer->getProperty, image_data=image
        obj_destroy, obuffer
    endif

    ; cleanup
    obj_destroy, oview

    return, result
end
