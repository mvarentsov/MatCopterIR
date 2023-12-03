function f_process_IR (IMAGE_DIR_PATH)
    

    libpath = fileparts (mfilename('fullpath'));
    addpath ([libpath, '\libs\plot_google_map\']);
    addpath ([libpath, '\libs\tight_subplot\']);
    addpath ([libpath, '\libs\Colormaps\']);

    IMAGE_FORMAT  = '.jpg';
    EXIFTOOL_PATH = [libpath, '\exiftool.exe'];
    T_MATRIX_SIZE = [256 336];
    
    RELOAD_IR_IMAGES = false;

    USE_SHARP_DT_CORR = true;
    USE_TREND_CORR    = true;
    USE_SEGMENTS_CORR = true;
    USE_DETREND_SEGMENT_CORR = true;
    
    SEGMENTS_CORR_N_NEIGHB    = 3;
    SEGMENTS_CORR_SM_STEP     = 5;
    SHARP_DT_CORR_SIGMA_LIMIT = 3;
    DETREND_CORR_MODE = 'lowess';
    
    
    pics_dir = [IMAGE_DIR_PATH, 'processing_figs\'];
    mkdir (pics_dir);
    
    img_data = f_read_IR_images (IMAGE_DIR_PATH, IMAGE_FORMAT, T_MATRIX_SIZE, EXIFTOOL_PATH, RELOAD_IR_IMAGES); 

    %% Link images with GPS data
    gps_data = readtable ([IMAGE_DIR_PATH, 'gps_data.csv']);
    try
        gps_data.Properties.VariableNames = {'file', 'lat', 'lon', 'height', 'yaw', 'pitch', 'roll'};
    catch 
        gps_data.Properties.VariableNames = {'file', 'lat', 'lon', 'height', 'acc', 'yaw', 'pitch', 'roll'};
    end

    mission_data = f_prepare_mission_data (img_data, gps_data);
    mission_data = f_identify_segments (mission_data);
    
    
    for i = 2:numel (mission_data.dir)
        if (mission_data.segment (i) ~= mission_data.segment (i-1))
            fprintf ('%s\n', mission_data.file{i})
        end
    end
    
    figure ('Color', 'white'); hold on; box on; 
    f_plot_by_segments (mission_data.lon, mission_data.lat, mission_data.segment, mission_data.is_major_segment, 'LineWidth', 1.5);
    plot_google_map ('MapType', 'satellite');
    set (gcf, 'PaperPositionMode', 'auto');
    print ([pics_dir, 'segments.png'], '-dpng', '-r200');
    
    %% Correction based on sharp dt values
    
    if (USE_SHARP_DT_CORR)
    
        dt_std = nanstd (mission_data.dt);
        crit_ind = find (abs (mission_data.dt) > SHARP_DT_CORR_SIGMA_LIMIT * dt_std); 
    
        mission_data.t_corr1a = mission_data.t;
        
        for i = 1:numel (mission_data.time)
            if (abs (mission_data.dt (i)) >  SHARP_DT_CORR_SIGMA_LIMIT * dt_std)
                mission_data.t_corr1a (i:end) = mission_data.t_corr1a (i:end) - mission_data.dt (i);
                fprintf ('Sharp dt %.2f between %s and %s\n', mission_data.dt (i), mission_data.file{i}, mission_data.file{i-1})
            end
        end
       delta_means = mean (mission_data.t_corr1a) - mean (mission_data.t);
       mission_data.t_corr1b = mission_data.t_corr1a - delta_means;
    
        if (USE_TREND_CORR)
            mission_data.t_corr1 = mean (mission_data.t_corr1b) + detrend (mission_data.t_corr1b);
        else
            mission_data.t_corr1 = mission_data.t_corr1;
        end
    
        figure ('Color', 'white', 'Position', [100 100 560, 760]); %, 'Position', [0.1300    0.1100    0.7750    0.3412], 'units', 'normalized');
        ax = tight_subplot (2,1,0.06, [0.07, 0.03], [0.1, 0.05]);
        subplot (ax(1)); hold on; grid on;
        p1 = plot (mission_data.time, mission_data.t_corr1a, '--k', 'LineWidth', 1.5, 'Color',  [0.5, 0.5, 0.5]);
        p2 = plot (mission_data.time, mission_data.t_corr1b, ':k', 'LineWidth', 1.5, 'Color', [0.5, 0.5, 0.5]);
        p3 = plot (mission_data.time, mission_data.t_corr1, '-k', 'LineWidth', 1.5, 'Color', [0.5, 0.5, 0.5]); %[0.5, 0.5, 0.5]);
        f_plot_by_segments (mission_data.time, mission_data.t, mission_data.segment, [], 'LineWidth', 2);
        xlim ([min(mission_data.time),max(mission_data.time)]);
        p4 = plot (mission_data.time (crit_ind), mission_data.t (crit_ind), 'ok', 'LineWidth', 2);
        set (gca, 'YTickLabel', get (gca, 'YTick'));
        ylabel ('Температура [{\circ}C]', 'FontWeight','bold')
        l = legend ([p4, p1, p2, p3], {'Артефакты', 'T^С^0', 'T^С^1', 'T^С^1 (удален тренд)'}, 'Orientation','horizontal', 'Location','best');
        set (l, 'FontSize', 11);
    
        subplot (ax(2)); hold on; grid on;
        f_plot_by_segments (mission_data.time, mission_data.dt, mission_data.segment, [], 'LineWidth', 1.5);
        xlim ([min(mission_data.time),max(mission_data.time)]);
        plot (mission_data.time (crit_ind), mission_data.dt (crit_ind), 'ok', 'LineWidth', 2);
        ylabel ('{\Delta}T [{\circ}C/с]', 'FontWeight','bold')
        set (gca, 'YTickLabel', get (gca, 'YTick'));
        
        print ([pics_dir, 'L1 sharp dt.png'], '-dpng', '-r200');
    
    else 
       mission_data.t_corr1 = mission_data.t;
    end
    
    %% Correction based on segments of opposite direction
    unique_segments = unique (mission_data.segment);
    
    if (USE_SEGMENTS_CORR)
    
        %close all;
        delta_t = zeros (size (mission_data.time));
        
        for i = 1:numel (mission_data.dir)
        
            if (mission_data.segment (i) > 1)
                prev_seg = mission_data.segment (i) - 1;
                prev_ind = find (mission_data.segment == prev_seg & mission_data.is_major_segment);
                prev_dist = distance (mission_data.lat(i), mission_data.lon(i), mission_data.lat(prev_ind), mission_data.lon(prev_ind));
                [~, sort_ind] = sort (prev_dist, 'ascend');
                prev_ind = prev_ind (sort_ind(1:SEGMENTS_CORR_N_NEIGHB));
            else
                prev_ind = [];
            end
        
            if (mission_data.segment (i) < max (unique_segments))
                next_seg = mission_data.segment (i) + 1;
                next_ind = find (mission_data.segment == next_seg & mission_data.is_major_segment);
                next_dist = distance (mission_data.lat(i), mission_data.lon(i), mission_data.lat(next_ind), mission_data.lon(next_ind));
                [~, sort_ind] = sort (next_dist, 'ascend');
                next_ind = next_ind (sort_ind(1:SEGMENTS_CORR_N_NEIGHB));
            else
                next_ind = [];
            end
        
            t_prev = mean (mission_data.t_corr1(prev_ind));
            t_next = mean (mission_data.t_corr1(next_ind));
    
            %if (isnan (t_prev) || isnan (t_next)) 
            %    continue
            %end
    
            delta_t (i) = mission_data.t_corr1 (i) - nanmean ([t_prev, t_next]);
                
        
                 %plot (mission_data.lon(i), mission_data.lat (i), 'o');
                 %plot (mission_data.lon(prev_ind), mission_data.lat (prev_ind), '+k');
                 %plot (mission_data.lon(next_ind), mission_data.lat (next_ind), '+k');
                 %pause;
                 %print ('aaa');
        end
        
        mission_data.t_corr2  = mission_data.t_corr1 - 0.5 * movmean (delta_t, SEGMENTS_CORR_SM_STEP);
    else
        mission_data.t_corr2 = mission_data.t_corr1;
    end
    
    %%
    
    if (USE_DETREND_SEGMENT_CORR)
        x_var = 'segment_dist';
        x_label = 'Расстояние вдоль полосы [м]';
    
        %x_var = 'segment_pos1';
        %x_label = 'Положение вдоль сегмента [сек]'; % 'Position along segment';
    
        if (strcmp (DETREND_CORR_MODE, 'linear'))
        
            [k] = polyfit (mission_data.(x_var), mission_data.t_corr2, 1);
        
            x_trend = min (mission_data.(x_var)):(max (mission_data.(x_var))-min (mission_data.(x_var)))/100:max(mission_data.(x_var));
            y_trend = k(2) + x_trend*k(1);
    
            temp_corr = mission_data.(x_var) * k (1);
            temp_corr = temp_corr - mean (temp_corr);
        elseif (strcmp (DETREND_CORR_MODE, 'lowess'))
            [x_sort, sort_ind] = sort (mission_data.(x_var));
            y_sort = mission_data.t_corr2 (sort_ind);
            x_trend = x_sort;
            y_trend = smooth(x_sort, y_sort, 0.5, 'lowess');
    
    
            [x_sort_unique, unique_ind] = unique (x_sort);
            f_sort_unique = y_trend (unique_ind);
    
            temp_corr = nan (size (mission_data.t_corr2));
            for i = 1:numel (temp_corr)
                cur_x = mission_data.(x_var) (i);
                temp_corr (i) = interp1 (x_sort_unique, f_sort_unique, cur_x);
            end        
        end
    
        temp_corr = temp_corr - mean (temp_corr);
        mission_data.t_corr3 = mission_data.t_corr2 - temp_corr;
    
        figure ('Color', 'white'); hold on; grid on; box on;
        f_plot_by_segments (mission_data.(x_var), mission_data.t_corr2, mission_data.segment, [], 'Marker', 'o', 'LineStyle', 'none');
        plot (x_sort, y_trend, '--k', 'LineWidth', 1.5);
        ylabel ('Температура [{\circ}C]', 'FontWeight', 'bold');
        xlabel (x_label, 'FontWeight', 'bold');
        l = legend('Полоса 1', 'Полоса 2', 'Полоса 3', 'Полоса 4', 'Полоса 5', 'Полоса 6', 'Полоса 7', 'Полоса 8',  'Аппроксимация (LOWESS)');
        set (l, 'FontSize', 10)
        print ([pics_dir, 'L3 detrend segment pos.png'], '-dpng', '-r200');
        
    
    else
        mission_data.t_corr3 = mission_data.t_corr2;
    end
    
    
    
    %%
    
    %vars2draw = {'t', 't_corr1', 't_corr2', 't_corr3'}
    
    figure;  hold on;
    scatter (mission_data.lon, mission_data.lat, 50, mission_data.t, 'fill');
    colorbar;
    plot_google_map ('MapType', 'satellite');
    set (gcf, 'PaperPositionMode', 'auto');
    %print ([pics_dir, 'map_t0_raw.png'], '-dpng', '-r200');
    
    
    figure;  hold on;
    scatter (mission_data.lon, mission_data.lat, 50, mission_data.t_corr1, 'fill');
    c_lim = get (gca, 'CLim');
    colorbar;
    plot_google_map ('MapType', 'satellite');
    set (gcf, 'PaperPositionMode', 'auto');
    %print ([pics_dir, 'map_t1.png'], '-dpng', '-r200');
    
    
    figure;  hold on;
    scatter (mission_data.lon, mission_data.lat, 50, mission_data.t_corr2, 'fill');
    caxis (c_lim);
    colorbar;
    plot_google_map ('MapType', 'satellite');
    set (gcf, 'PaperPositionMode', 'auto');
    %print ([pics_dir, 'map_t2.png'], '-dpng', '-r200');
    
    
    figure;  hold on;
    scatter (mission_data.lon, mission_data.lat, 50, mission_data.t_corr3, 'fill');
    caxis (c_lim);
    colorbar;
    plot_google_map ('MapType', 'satellite');
    set (gcf, 'PaperPositionMode', 'auto');
    %print ([pics_dir, 'map_t3', DETREND_CORR_MODE, '.png'], '-dpng', '-r200');
    
    
    %%
    figure; hold on; grid on;
    f_plot_by_segments (mission_data.time, mission_data.t, mission_data.segment, [], 'LineWidth', 1.5)
    y_lim = get (gca, 'YLim');
    xlim ([min(mission_data.time),max(mission_data.time)]);
    print ([pics_dir, 'plot_t0.png'], '-dpng', '-r200');
       
    
    figure; hold on; grid on;
    f_plot_by_segments (mission_data.time, mission_data.t_corr1, mission_data.segment, [], 'LineWidth', 1.5)
    ylim (y_lim);
    xlim ([min(mission_data.time),max(mission_data.time)]);
    print ([pics_dir, 'plot_t1.png'], '-dpng', '-r200');
    
    
    figure; hold on; grid on;
    f_plot_by_segments (mission_data.time, mission_data.t_corr2, mission_data.segment, [], 'LineWidth', 1.5)
    ylim (y_lim);
    xlim ([min(mission_data.time),max(mission_data.time)]);
    print ([pics_dir, 'plot_t2.png'], '-dpng', '-r200');
    
    
    figure; hold on; grid on;
    f_plot_by_segments (mission_data.time, mission_data.t_corr3, mission_data.segment, [], 'LineWidth', 1.5)
    ylim (y_lim);
    xlim ([min(mission_data.time),max(mission_data.time)]);
    print ([pics_dir, 'plot_t3', DETREND_CORR_MODE, '.png'], '-dpng', '-r200');
        
    
    %%
    t1_corr = mission_data.t_corr1 - mission_data.t;
    t2_corr = mission_data.t_corr2 - mission_data.t;
    t3_corr = mission_data.t_corr3 - mission_data.t;
    
    
    img_data.t_raw   = img_data.t_matrix;
    img_data.t_corr1 = img_data.t_matrix;
    img_data.t_corr2 = img_data.t_matrix;
    img_data.t_corr3 = img_data.t_matrix;
    
    
    for it = 1:numel (mission_data.t)
        img_data.t_corr1 (:, :, it) = img_data.t_raw (:, :, it) + t1_corr (it);
        img_data.t_corr2 (:, :, it) = img_data.t_raw (:, :, it) + t2_corr (it);
        img_data.t_corr3 (:, :, it) = img_data.t_raw (:, :, it) + t3_corr (it);
    end
    
    vars2export = {'t_raw', 't_corr2', 't_corr3'}; %
    
    for i_v = 1:numel (vars2export)
        cur_var = vars2export {i_v};
        if (strcmp (cur_var, 't_corr3'))
            str = DETREND_CORR_MODE;
        else
            str = '';
        end
        export_dir = [IMAGE_DIR_PATH, cur_var, str, '\'];
        mkdir (export_dir)
        f_write_processed_IR_images (img_data.(cur_var), export_dir, img_data.filenames);
    
    end


end