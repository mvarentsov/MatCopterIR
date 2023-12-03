function f_plot_by_segments (x, y, segment, is_major_segment, varargin)
    
    if (isempty (is_major_segment))
        is_major_segment = ones (size (segment));
    end

    unique_segments = unique (segment);
    for i = 1:numel (unique_segments)
        segment_ind_mj = find (segment == unique_segments(i) &   is_major_segment);
        segment_ind_mn = find (segment == unique_segments(i) &  ~is_major_segment);
        p = plot (x (segment_ind_mj), y (segment_ind_mj), '-', varargin{:});
        c = get (p, 'Color');
        plot (x (segment_ind_mn), y (segment_ind_mn), '--', 'Color', c, varargin{:});
    end
end
