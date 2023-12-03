function [data, exifval] = f_get_t_from_ir(exiftoolpath, impath, filename, i)
    [waste, exif_text] = system(['"', exiftoolpath '" -flir:all ' '"' impath filename '"']);
    raw_exif = split(exif_text, {': ', char(10)});
    
    for j = 1:floor(length(raw_exif) / 2)
        name = raw_exif{j * 2 - 1};
        val = raw_exif{j * 2};
        
        exifval.(name(find(~isspace(name) & name ~= '/'))) = str2double(val(~isletter(val)));
    end
    
    clear j val name a b c
    
    rawpath = [impath 'raw' num2str(i) '.tif'];
    cmd = ['"', exiftoolpath '"', ' ' '"' impath filename '"' ' -b -RawThermalImage > "' rawpath '"'];
    %cmd = [exiftoolpath ' ' '''' impath filename '''' ' -b -RawThermalImage > ''' rawpath ''''];
    system(cmd);
    raw = imread(rawpath);
    
    R1 = exifval.PlanckR1;
    R2 = exifval.PlanckR2;
    B = exifval.PlanckB;
    F = exifval.PlanckF;
    O = exifval.PlanckO;
    
    emissivity = exifval.Emissivity;
    refl_temp = exifval.ReflectedApparentTemperature;
    
    raw_refl = R1 / (R2 * (exp(B / (refl_temp + 273.15)) - F)) - O;
    raw_obj = (raw - (1.0 - emissivity) * raw_refl) ./ emissivity;
    t_full = B ./ log(double(R1 ./ (R2 .* (raw_obj + O)) + F)) - 273.15;
    
    data = t_full;
    
    delete(rawpath);
end