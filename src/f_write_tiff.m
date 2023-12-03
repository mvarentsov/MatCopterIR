function f_write_tiff(data, impath, filename)
    t = Tiff([impath, filename, '_t.tif'], 'w');

    tagstruct.ImageLength = 256; 
    tagstruct.ImageWidth = 336;
    tagstruct.Photometric = 0;
    tagstruct.BitsPerSample = 32;
    tagstruct.SamplesPerPixel = 1;
    tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky; 
    tagstruct.Software = 'MATLAB'; 

    setTag(t,tagstruct);

    write(t, single(data));
    close(t);
end