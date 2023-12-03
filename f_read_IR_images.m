function [img_data] = f_read_IR_images (IMAGE_DIR_PATH, IMAGE_FORMAT, T_MATRIX_SIZE, EXIFTOOL_PATH, reload)

    
    try 
        reload;
    catch exc
        reload = false;
    end

    mat_path = [IMAGE_DIR_PATH, 'img_data.mat'];

    if (~reload)
        if (isfile (mat_path))
            load (mat_path);
        else
            reload = true;
        end
    end

    if (reload)
        files = dir([IMAGE_DIR_PATH, '*', IMAGE_FORMAT]);
        N = length (files);
        
        img_t_matrix = nan(T_MATRIX_SIZE(1), T_MATRIX_SIZE(2), N);
        img_filenames = cell (N, 1);
        img_time      = NaT(N, 1);
        
        %for i = 1:N
        parfor i = 1:N
            filename = files(i).name;
            img_time (i) = datetime(datenum (filename (1:end-6), 'yyyymmdd_HHMMSS'), 'ConvertFrom', 'datenum');
        
            img_t_matrix(:, :, i) = f_get_t_from_ir(EXIFTOOL_PATH, IMAGE_DIR_PATH, filename, i);
            img_filenames{i} = filename;

            out_id = fopen ([IMAGE_DIR_PATH, filename, '.processed'], 'w');
            fclose (out_id);
        
            n = numel (dir([IMAGE_DIR_PATH, '*.processed']));
        
            fprintf ('%d of %d processed\n', n, N);  
        end

        delete ([IMAGE_DIR_PATH, '*.processed'])
        
        [img_data.time, sort_ind] = sort (img_time);
        img_data.t_matrix = img_t_matrix (:, :, sort_ind);
        img_data.filenames = img_filenames (sort_ind);

        save (mat_path, 'img_data');
    end

end