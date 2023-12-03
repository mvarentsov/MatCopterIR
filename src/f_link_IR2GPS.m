function [mission] = f_link_IR2GPS (root_dir, mission, AERROR, SHOW_PREVIEW)

    libpath = fileparts (mfilename('fullpath'));
    addpath ([libpath, '\libs\replaceinfile\']);

    dji_path  = [root_dir, '\FLIGHT_LOGS\', mission.FLIGHT_LOG_PATH{1}];
    flir_path = [root_dir, '\', mission.IR_FOLDER_PATH{1}, '\'];

    dji_data_raw = readtable (dji_path);
    dji_data.date_num = datenum (table2array (dji_data_raw (1, 2))) + table2array (dji_data_raw (1:end-1, 1)) / (24*3600*1000);
    
    dji_data.vars.rel_height =  dji_data_raw.height_above_takeoff_feet_ (1:end-1) * 0.3048;
    dji_data.vars.lon = dji_data_raw.longitude (1:end-1);
    dji_data.vars.lat = dji_data_raw.latitude (1:end-1);
    dji_data.vars.yaw = dji_data_raw.compass_heading_degrees_ (1:end-1);
    dji_data.vars.roll = zeros (size ( dji_data.vars.yaw));
    dji_data.vars.pitch = zeros (size ( dji_data.vars.yaw));
    
    med_height = nanmedian (dji_data.vars.rel_height);
    med_yaw    = nanmedian (dji_data.vars.yaw);

    if (iscell(mission.START_MISSION_FILE) && ~isempty (mission.START_MISSION_FILE{1}))
    
        yaw_shift1 = circshift (dji_data.vars.yaw, -1); % -1);
        yaw_shift2 = circshift (dji_data.vars.yaw, -2); %-2);
        yaw_shift3 = circshift (dji_data.vars.yaw, -3); %-2);
    
        mission_ind = find (abs(dji_data.vars.rel_height - med_height)   <= med_height * AERROR & ...
                            mod (abs (dji_data.vars.yaw - med_yaw), 360) <= 10 & ...
                            mod (abs (yaw_shift1 - med_yaw), 360) <= 10 & ...
                            mod (abs (yaw_shift2 - med_yaw), 360) <= 10 & ...
                            mod (abs (yaw_shift3 - med_yaw), 360) <= 10);
    
        dji_data.vars.is_mission = zeros (size (dji_data.vars.rel_height));
        dji_data.vars.is_mission (mission_ind) = 1;
    
        stable_segments = [];
        for i = 2:numel (dji_data.vars.is_mission)
            if (~dji_data.vars.is_mission (i-1) && dji_data.vars.is_mission (i))
                mission_start = i;
            elseif (dji_data.vars.is_mission (i-1) && ~dji_data.vars.is_mission (i))
                mission_end = i-1;
                cur_segment = [mission_start, mission_end];
                stable_segments = [stable_segments; cur_segment];
            end
        end
    
        segment_len = stable_segments(:, 2) - stable_segments(:, 1);
        [~, longest_segment_ind] = max (segment_len);
    
        %start_mission_ind = mission_ind(1);
        start_mission_ind = stable_segments (longest_segment_ind, 1);
        
        [~, fname] = fileparts (mission.START_MISSION_FILE);
    
        first_dji_time = dji_data.date_num(start_mission_ind);
        first_image_time = datenum (fname, 'yyyymmdd_HHMMSS') - mission.TIME_BELT/24;
        flir_time_corr = first_dji_time - first_image_time; 
        flir_time_corr_dv = datevec (flir_time_corr);
        flir_time_corr_dv (6) = round (flir_time_corr_dv (6));
        flir_time_corr = datenum(flir_time_corr_dv);
    else
        flir_time_corr = datenum (0, 0, 0, 0, 0, mission.FLIR_TIME_CORR_SEC);
        flir_time_corr_dv = datevec (flir_time_corr);
        flir_time_corr = datenum(flir_time_corr_dv);
    end
    
    fprintf ('FLIR_TIME_CORR_SEC = %d\n', flir_time_corr_dv (6));

    if (SHOW_PREVIEW)
        f = figure('Position', [100, 100, 1200, 500]); 
    end
    
    file_list = dir([flir_path, '*.jpg']);
    
    k = 1;
    
    FLIR_PATH_SEL = [flir_path, '\selected\'];
    mkdir (FLIR_PATH_SEL);
    
    for i_file = 1:numel (file_list)
        cur_path = [flir_path, file_list(i_file).name];
        
        warning off
        a = imfinfo(cur_path);
        
        warning on
        cur_image_datestr = file_list(i_file).name (1:end-6);
        cur_image_time = datenum (cur_image_datestr, 'yyyymmdd_HHMMSS') - mission.TIME_BELT/24 + flir_time_corr;
        %cur_image_time = datenum(datetime(a.FileModDate)) - TIME_BELT/24 + FLIR_TIME_CORR;
        
        cur_image = imread(cur_path);
        
        cur_height = interp1(dji_data.date_num, dji_data.vars.rel_height, cur_image_time);
        
        if (isnan (cur_height))
            continue;
        end
        cur_lon = interp1(dji_data.date_num,    dji_data.vars.lon, cur_image_time);
        cur_lat = interp1(dji_data.date_num,    dji_data.vars.lat, cur_image_time);
        cur_yaw = interp1(dji_data.date_num, dji_data.vars.yaw, datenum(cur_image_time));
        cur_roll = 0;
        cur_pitch = 0;
        
        is_selected = abs(cur_height - med_height) <= med_height * AERROR & ...
                      mod (abs (cur_yaw - med_yaw), 360)    <= 10;
    
        if (SHOW_PREVIEW && cur_height >= med_height * 0.75)
            fprintf ('preview: %s, %s, %.2f, %.8f, %.8f\n', file_list(i_file).name, datestr (cur_image_time, 'HH:MM:SS'), cur_height, cur_lon, cur_lat);
            subplot(1, 3, 1);
            imagesc(cur_image);
            axis equal;
            title({datestr(cur_image_time),strrep(file_list(i_file).name,'_','\_')});
    
            subplot(1, 3, 2); hold on;
    
            plot(datetime (dji_data.date_num, 'ConvertFrom', 'datenum'), dji_data.vars.rel_height);
            plot(datetime (datenum(cur_image_time), 'ConvertFrom', 'datenum'), cur_height, 'or');
            
            title(sprintf('h = %.2f, yaw = %.2f, sel = %d', cur_height, cur_yaw, is_selected));
    
            subplot(1, 3, 3); hold on;
            plot(dji_data.vars.lon, dji_data.vars.lat, '-k');
            
            try
                plot(dji_data.vars.lon (start_mission_ind:end), dji_data.vars.lat(start_mission_ind:end), '-b');
            end
    
            plot(cur_lon, cur_lat, 'or', 'LineWidth', 2); 
            text(cur_lon, cur_lat, '{\uparrow}', 'horizontal', 'center', 'vertical', 'bottom', 'Color', 'red', 'FontWeight', 'bold', 'FontSize', 15, 'rotation', -cur_yaw); 
            
            pause;
            clf (f);
            continue;
        end
        
        
        if (~SHOW_PREVIEW && is_selected)
            fprintf ('copy: %s, %s, %.2f, %.8f, %.8f\n', file_list(i_file).name, datestr (cur_image_time, 'HH:MM:SS'), cur_height, cur_lon, cur_lat);
            copyfile (cur_path, [FLIR_PATH_SEL, file_list(i_file).name]);
            
            
            [~, fname] = fileparts (file_list(i_file).name);
            ir_name(k, 1)    = {[fname, '_t', '.png']};
            ir_lat(k, 1)     = cur_lat;
            ir_lon(k, 1)     = cur_lon;
            ir_height(k, 1)  = cur_height;
            ir_yaw(k, 1)     = cur_yaw;
            ir_roll(k, 1)    = cur_roll;
            ir_pitch(k, 1)   = cur_pitch;
            k = k + 1;
        end
    end

    if (~SHOW_PREVIEW)
        ir_accuracy = 10 * ones (size (ir_height));
        ir_out = table(ir_name, ir_lat, ir_lon, ir_height, ir_accuracy, ir_yaw, ir_roll, ir_pitch);
    
        figure; 
        plot (ir_lon, ir_lat, 'ok');
    
        writetable(ir_out, [FLIR_PATH_SEL 'gps_data.csv'], 'Delimiter', ';', 'WriteVariableName', 0);
        replaceinfile ('.png', '.tif', [FLIR_PATH_SEL 'gps_data.csv'], [FLIR_PATH_SEL 'gps_data_tif.csv']);
    end
    
end