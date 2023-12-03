function f_write_processed_IR_images (img_t_matrix, IMAGE_DIR_PATH, file_names)
    
    t_max = prctile (img_t_matrix (:), 99.99);
    t_min = prctile (img_t_matrix (:), 0.01);
    
    t_borders = [t_min t_max];
    
    f = figure('Menu', 'none', 'ToolBar', 'none', 'Units', 'Pixels', 'Position', [0 0 size(img_t_matrix(:, :, 1)')]);
    
    for i = 1:length(file_names)
        ah(i) = axes('Units','Normalize','Position',[0 0 1 1]);
        imagesc(img_t_matrix(:, :, i));
        colormap inferno;
        set(gca, 'Visible', 'off');
        caxis(t_borders);
        fr = getframe(gcf);

        [~, file_name, file_ext] = fileparts (file_names(i));
        
        imwrite(fr.cdata, [IMAGE_DIR_PATH, file_name, '_t.png']); 
        
        clf(f)

        f_write_tiff(img_t_matrix(:, :, i), IMAGE_DIR_PATH, file_name);
    end
    
    fcb = figure();
    imagesc(img_t_matrix(:, :, end));
    colormap inferno;
    hcb = colorbar; 
    box on;
    caxis(t_borders);
    xlabel('X (m)');
    ylabel('Y (m)');
    ylabel(hcb, 'Surface temperature (\circC)', 'FontSize', 16);
    print([IMAGE_DIR_PATH, file_name, '_t_colorbar.png'], '-dpng', '-r300');
    
    close all
end