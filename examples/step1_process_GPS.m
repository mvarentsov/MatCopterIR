addpath ("..\src\")

clear all;

LIST_PATH = 'example_data\example_missions.csv';

mission_list = readtable (LIST_PATH, 'Delimiter', ';');


%%
MISSION2PROCESS = 1;      % Number of mission in file to process
AERROR = 0.05;            % Allowable error (%)
SHOW_PREVIEW = false;     % to run preview mode or not 

root_dir  = fileparts (LIST_PATH);

f_link_IR2GPS (root_dir, mission_list(MISSION2PROCESS, :), AERROR, SHOW_PREVIEW);

%%