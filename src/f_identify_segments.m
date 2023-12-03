function mission_data = f_identify_segments(mission_data)

    mission_data.dir = nan (size (mission_data.height));
    mission_data.segment = nan (size (mission_data.height));
    mission_data.segment_pos1 = nan (size (mission_data.height));
    mission_data.segment_dist = nan (size (mission_data.height));
    mission_data.is_major_segment = zeros (size (mission_data.segment));
    
    mission_data.dt = nan (size (mission_data.t));
    
    mission_data.segment (1) = 1;
    mission_data.is_major_segment (1) = true;
    mission_data.segment_pos1(1) = 0;
    mission_data.segment_dist(1) = 0;
    segment_dir = 1;
    
    for i = 2:numel (mission_data.dir)
        mission_data.dt(i) = mission_data.t (i) - mission_data.t (i-1);
        mission_data.dir (i) = azimuth (mission_data.lat(i-1), mission_data.lon(i-1), mission_data.lat(i), mission_data.lon(i));
        if (mission_data.dir (i) > 300)
            mission_data.dir (i) = 360 - mission_data.dir (i);
        end
    
        cur_segment_dirs = mission_data.dir(mission_data.segment ==  mission_data.segment(i-1));
        median_dir = nanmedian (cur_segment_dirs); %mission_data.dir (i)
    
        delta_dir = abs (mission_data.dir - median_dir);
        delta_dir (delta_dir > 185) = abs (360 - delta_dir (delta_dir > 185));
        
        if (numel (cur_segment_dirs) > 20 && delta_dir (i) > 175 &&  delta_dir (i-1) > 175 && delta_dir (i-2) > 175)
            mission_data.segment (i-2:i) = mission_data.segment (i-1) + 1;
            mission_data.is_major_segment (i-2:i) = true;
            segment_dir = segment_dir * -1;
    
            mission_data.segment_pos1 (i-2:i) = mission_data.segment_pos1 (i-2:i) + (1:3)' * segment_dir;
            mission_data.segment_pos1 (i) = mission_data.segment_pos1 (i-1) + segment_dir;
            
            mission_data.segment_dist (i-2) = mission_data.segment_dist (i-3) + segment_dir * 111 * 1000 * distance (mission_data.lat(i-2), mission_data.lon (i-2), mission_data.lat(i-3), mission_data.lon(i-3));
            mission_data.segment_dist (i-1) = mission_data.segment_dist (i-2) + segment_dir * 111 * 1000 * distance (mission_data.lat(i-1), mission_data.lon (i-1), mission_data.lat(i-2), mission_data.lon(i-2));
            mission_data.segment_dist (i) = mission_data.segment_dist (i-1) + segment_dir * 111 * 1000 * distance (mission_data.lat(i), mission_data.lon (i), mission_data.lat(i-1), mission_data.lon(i-1));
        else
            if (numel (cur_segment_dirs) > 20 && delta_dir (i) > 65 &&  delta_dir (i-1) > 65 && delta_dir (i-2) > 65)
                mission_data.is_major_segment (i-2:i) = false;
            end
            mission_data.segment (i) = mission_data.segment (i - 1);
            mission_data.is_major_segment (i) = mission_data.is_major_segment (i - 1);
            
            if (~mission_data.is_major_segment (i))
                mission_data.segment_pos1 (i) = mission_data.segment_pos1 (i-1);
                mission_data.segment_dist (i) = mission_data.segment_dist (i-1);
            else
                mission_data.segment_pos1 (i) = mission_data.segment_pos1 (i-1) + segment_dir;
                mission_data.segment_dist (i) = mission_data.segment_dist (i-1) + segment_dir * 111 * 1000 * distance (mission_data.lat(i), mission_data.lon (i), mission_data.lat(i-1), mission_data.lon(i-1));
            end
    
        end
    end
end