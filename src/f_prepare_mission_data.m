function [mission_data] = f_prepare_mission_data (img_data, gps_data)
    

    gps_data.file = strrep (gps_data.file, '_t', '');
    gps_data.file = strrep (gps_data.file, 'png', 'jpg');
    
    mission_data = table;
    mission_data.time = img_data.time;
    mission_data.file = img_data.filenames;
    mission_data.t = squeeze (mean (mean (img_data.t_matrix)));
    
    gps_data_cr = table;
    for it = 1:numel (mission_data.time)
        ind = find (strcmp (mission_data.file (it), gps_data.file));
        if (isempty (ind))
            error ('images and GPS data do not overlap by time');
        end
        gps_data_cr = [gps_data_cr; gps_data(ind,:)];
    end
    gps_data_cr.file = [];
    mission_data = [mission_data, gps_data_cr];
    
end