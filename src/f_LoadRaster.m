function [ data ] = f_LoadRaster( path, ch)
    try
        ch;
    catch
        ch = 1;
    end
        
    [data.val, refmat, bbox] = geotiffread (path, ch);
    info = geotiffinfo(path);

    [pix_lon, pix_lat] = pixcenters(info);
    
    data.lat = pix_lat; 
    data.lon = pix_lon; 

    data.val  = single (data.val);

    data.max_lon = max (data.lon);
    data.min_lon = min (data.lon);
    data.max_lat = max (data.lat);
    data.min_lat = min (data.lat);
end

