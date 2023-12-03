addpath('..\libs\Colormaps\');
addpath ('..\libs\plot_google_map\');

clear;
PATHS = {'example_data\20220617_173518_het_160m_corr3_lowess.tif', ...
         'example_data\20220617_173518_het_160m_raw.tif', 
         };
margin_k = 0.01;


FIG_W = 500;
FIG_H = 500;

if (~iscell (PATHS))
    file_list = dir ([PATHS, '*.tif']);
    paths2load = cell (0);
    for i_f = 1:numel (file_list)
        cur_path = [file_list(i_f).folder,'\',file_list(i_f).name];
        paths2load = [paths2load; cur_path];
    end
    try
        gps_data = readtable ([PATHS, 'gps_data.csv']);
    catch exc
        gps_data = [];
    end
else
    paths2load = PATHS;
    gps_data = [];
end

data = zeros (0);
for i_p  = 1:numel (paths2load)
    cur_path = paths2load {i_p};
    cur_data  = f_LoadRaster (cur_path);
    cur_data.min_lon = min (cur_data.lon(:));
    cur_data.max_lon = max (cur_data.lon(:));
    cur_data.min_lat = min (cur_data.lat(:));
    cur_data.max_lat = max (cur_data.lat(:));
    cur_data.path = cur_path;
    [~, cur_data.name] = fileparts (cur_path);
    data = [data; cur_data];
end


%%


min_lon = min ([data(:).min_lon]);
min_lat = min ([data(:).min_lat]);
max_lon = max ([data(:).max_lon]);
max_lat = max ([data(:).max_lat]);

%%

for i_d = 0:numel (data)
    
    if (i_d > 0)
        data2draw = data(i_d).val (:, :, 1);
        if (ndims (data(i_d).val) == 3)
            data2draw (data(i_d).val (:, :, 2) == 0) = nan;
        else
            data2draw (data(i_d).val (:, :) == 1) = nan;
        end
        data_mean_val = nanmean (data2draw (:));
        data2draw_anom = data2draw - data_mean_val;
    
        t_mean  = nanmean (data2draw (:));
        t_std   = nanstd (data2draw (:));
        t_q1  = prctile (data2draw(:), 1);
        t_q99 = prctile (data2draw(:), 99);
        t_range = t_q99 - t_q1;
    end

    figure ('Position', [50, 50, FIG_W, FIG_H], 'Color', 'white');

    if (contains (paths2load(1), 'Nadym') && i_d > 0) % || contains (paths2load(1), 'Kalmykia'))
        subplot ('Position', [0.01, 0.01, 0.92, 0.98]);
    else
        subplot ('Position', [0.01, 0.07, 0.98, 0.92]);
    end
    

    if (i_d > 0)
        pcolor (data(i_d).lon, data(i_d).lat, data2draw); shading flat;
        colormap inferno;
        %caxis ([t_q1-1, t_q99+1]);
        caxis ([t_q1, t_q99]);
    end

    delta_lon = max_lon - min_lon;
    delta_lat = max_lat - min_lat;

    xlim ([min_lon - delta_lon * margin_k, max_lon + delta_lon * margin_k]);
    ylim ([min_lat - delta_lat * margin_k, max_lat + delta_lat * margin_k]);
    
    if (~isempty (gps_data) && i_d == 0)
        plot (gps_data.Var3, gps_data.Var2, '-g', 'LineWidth', 1.5);
    end

    if (contains (paths2load(1), 'Nadym') && i_d > 0) % || contains (paths2load(1), 'Kalmykia'))
        cb = colorbar ('Location', 'eastoutside');
    else 
        cb = colorbar ('Location', 'southoutside');
    end
    set (cb, 'FontSize', 10)

    
    if (i_d > 0)
        yl = ylabel(cb, {strrep(data(i_d).name, '_', '\_'), sprintf('mean = %.1f, std = %.1f, IQR(1-99) = %.1f', t_mean, t_std, t_range)});
        if (FIG_W < 500)
            set (yl, 'FontSize', 7);
        end
    end
    
    set (gca, 'XTick', []);
    set (gca, 'YTick', []);
    
    plot_google_map ('ShowLabels', false, 'MapType', 'satellite'); 
    makescale;
    
    if (i_d > 0)
        out_path = [data(i_d).path, '_preview.png'];
    else
        out_path = [fileparts(data(1).path),'\empty.png'];
    end
    print (out_path, '-dpng', '-r300');
end
    

