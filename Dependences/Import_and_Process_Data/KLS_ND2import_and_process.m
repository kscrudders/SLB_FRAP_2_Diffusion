function results = KLS_ND2import_and_process(data_dir, save_dir, name_of_data, img_info, save_tif_flag)
% runCARImageProcessing Imports and processes imaging data.
%
%   results = runCARImageProcessing(data_dir, save_data_dir, name_of_data)
%
%   INPUTS:
%       data_dir      - Directory where raw data is stored.
%       save_data_dir - Directory where processed data will be saved.
%       name_of_data  - Name of the dataset.
%
%   OUTPUT:
%       results       - Structure containing the raw data, metadata,
%                       processed data, and other results.
%
%   NOTE: This function relies on several custom functions (e.g.,
%         KLS_ParseND2Metadata, KLS_RICM_bkgd_correction,
%         etc.) that must be available in the MATLAB path.
%{
% This are the fields of img_info the function needs
% Define channel parameters.
img_info.num_ch = 1;
img_info.NDFin_or_NDFout = 0;  % 1 for in, 0 for out   

img_info.channel_freq = [1];
img_info.median_filter_ch_flag = [0];
img_info.self_med_filter_ch_flag = [0];
img_info.shade_correct_ch_flag = [1];
img_info.AU_to_Photon_flag = [1];
img_info.bleach_correct_flag = [0];
img_info.med_filter_lower_thresholds = {[];};   
img_info.channel_labels = {'';};
img_info.external_ch_num = [0];  % Must be of length num_ch
img_info.external_bkgd_dir = [];
img_info.external_dir_loc_of_bkgd_data = [];  % Change as needed

data_dir = 'D:\02_PurdueDocuments\08_Papers\20250228_CARTcell_MinimumActivationThreshold\01_Figures\02a';
save_dir = 'D:\02_PurdueDocuments\08_Papers\20250228_CARTcell_MinimumActivationThreshold\01_Figures\02a';
name_of_data = 'HighDensity_FOLR1';
%}
    if isempty(save_dir)
        save_dir = data_dir;
    end
    
    % Bring in channel parameters.
    num_ch = img_info.num_ch;
    
    NDFin_or_NDFout = img_info.NDFin_or_NDFout;  % 1 for in, 0 for out   
    
    channel_freq = img_info.channel_freq;
    median_filter_ch_flag = img_info.median_filter_ch_flag;
    self_med_filter_ch_flag = img_info.self_med_filter_ch_flag;
    shade_correct_ch_flag = img_info.shade_correct_ch_flag;
    AU_to_Photon_flag = img_info.AU_to_Photon_flag;
    bleach_correct_flag = img_info.bleach_correct_flag;
    med_filter_lower_thresholds = img_info.med_filter_lower_thresholds;   
    channel_labels = img_info.channel_labels;
    
    external_ch_num = img_info.external_ch_num;  % Must be of length num_ch
    external_bkgd_dir = img_info.external_bkgd_dir;
    external_dir_loc_of_bkgd_data = img_info.external_dir_loc_of_bkgd_data;  % Change as needed
    
%% Section 00: import shade data and get default figure position
    %---------------------------------------------------------%
    % BaSiC data generated in ImageJ
    %---------------------------------------------------------%
    % estimate both flat-field and dark-field, no input data
    Dependency_folder = 'H:\01_Matlab\99_Github\SLB_FRAP_2_Diffusion\Dependences\Import_and_Process_Data';
    try
        load(fullfile(Dependency_folder, 'Shade_20240701.mat'), '-mat'); %#ok<LOAD>
    catch
        disp('Failed to load dependencies from the specified folder.');
        Dependency_folder = uigetdir('', 'Select the folder containing dependencies');
        if Dependency_folder == 0
            error('No folder selected. Define dependency folder on line 66.');
        end
        load(fullfile(Dependency_folder, 'Shade_20240701.mat'), '-mat'); %#ok<LOAD>
    end

    
    %---------------------------------------------------------%
    % Set a default figure position
    %---------------------------------------------------------%
    Pos = get(0,'defaultfigureposition');
    
    % Get the screen size
    screenSize = get(0, 'ScreenSize'); % screenSize = [left, bottom, width, height]
    
    % Define your figure size
    figureWidth = Pos(3); % Width of the figure
    figureHeight = Pos(4); % Height of the figure
    
    % Calculate the position to place the figure at the far left edge of the screen
    Pos = [5, screenSize(4) - figureHeight - 85, figureWidth, figureHeight]; % [left, bottom, width, height]
    
    clear screenSize figureWidth figureHeight
    
    KLS_Check_tif_Imwrite()

    %% Section 01: Import Data
    base_save_dir = fullfile(save_dir, name_of_data);
    
    % Time stamps: try to automatically find the _Time_Field txt file.
    try
        file_name = dir(fullfile(base_save_dir, '*_Time_Field*.txt'));
        Time_stamps_address = fullfile(base_save_dir, file_name.name);
    catch
        disp(['Timestamp import is automatic if you save ' ...
              'the ND2 time information in a txt file with ' ...
              '''_Time_Field'' in its name']);
        Time_stamps_address = '';  % Change as needed
    end
    
    % Setup file import and retrieve raw data.
    [Raw_data, base_save_dir, Raw_dir, Processed_dir] = ...
        LF_ImportFileSetup(data_dir, save_dir, name_of_data);

    % Pull out metadata from the ND2 file.
    try
        meta_data = KLS_ParseND2Metadata(fullfile(data_dir, [name_of_data '.nd2']));
    catch
        meta_data = KLS_GetMetadata(base_save_dir);
    end
    
    KLS_Check_tif_Imwrite();
    
    disp(' ');
    disp('Channels:');
    for i = 1:length(meta_data)
        disp(['Ch' num2str(i) ' --- ' meta_data(i).Name]);
    end
    
    %% Section 02: Image Processing
    close all
    % If an external background is needed.
    if any(median_filter_ch_flag .* ~self_med_filter_ch_flag)
        data_dir_list = dir(external_bkgd_dir);
        
        temp_cell = cell(length(external_dir_loc_of_bkgd_data), 1);
        for i = 1:length(external_dir_loc_of_bkgd_data)
            temp_cell{i} = KLS_ND2ImportAll(data_dir_list(external_dir_loc_of_bkgd_data(i)).name);
        end
    end
    
    processed_data = cell(num_ch, 1);
    median_threshold = zeros(num_ch, 1);
    
    % Extract unique image data from Raw_data.
    if exist('Raw_data','var') && ~exist('base_data','var')
        base_data = cell(num_ch, 1);
        for i = 1:num_ch
            base_data{i} = Raw_data(:,:, i:num_ch*channel_freq(i):end);
            if channel_freq(i) ~= 1
                [x, y, t] = size(base_data{i});
                reshapedData = reshape(base_data{i}, x*y, t);
                [uniqueColumns, ~, ~] = unique(reshapedData', 'rows', 'stable');
                uniqueData = reshape(uniqueColumns', x, y, size(uniqueColumns, 1));
                nonZeroFrames = any(any(uniqueData, 1), 2);
                base_data{i} = uniqueData(:, :, nonZeroFrames);
                channel_freq(i) = ceil(size(Raw_data, 3) / (t * num_ch));
            end
        end
    end
    
    clear Raw_data
    % Process each channel.
    for i = 1:num_ch
        processed_data{i} = base_data{i};
        
        % Median image correction.
        if median_filter_ch_flag(i) == 1
            switch self_med_filter_ch_flag(i)
                case 1
                    [processed_data{i}, ~, median_threshold(i), ~] = ...
                        KLS_RICM_bkgd_correction(processed_data{i}, med_filter_lower_thresholds{i});
                case 0
                    temp_bkgd = zeros(size(temp_cell{1},1), size(temp_cell{1},2), length(external_dir_loc_of_bkgd_data));
                    for ii = 1:length(external_dir_loc_of_bkgd_data)
                        temp_bkgd(:,:,ii) = temp_cell{ii}(:,:,external_ch_num(i));
                    end
                    [~, median_img, median_threshold(i), ~] = ...
                        KLS_RICM_bkgd_correction(temp_bkgd, med_filter_lower_thresholds{i});
                    rows = round(size(processed_data{i},1) / 512);
                    cols = round(size(processed_data{i},2) / 512);
                    if floor(rows) ~= rows || floor(cols) ~= cols
                        disp('Current script only handles image data that is divisible by 512.');
                        return;
                    end
                    if rows + cols > 2
                        median_img = repmat(median_img, [rows cols 1]);
                    end
                    processed_data{i} = (processed_data{i} - median_img) + round(mean(median_img, 'all'));
            end
        end
        
        % Convert arbitrary units to photons.
        if AU_to_Photon_flag(i) == 1
            gain = meta_data(i).Multiplier;
            [conversion, offset] = KLS_gain_basic(gain);
            processed_data{i} = (processed_data{i} - offset) .* conversion;
        end
        
        % Shade correction.
        if shade_correct_ch_flag(i) == 1
            rows = round(size(base_data{i}(:,:,1),1) / 512);
            cols = round(size(base_data{i}(:,:,1),2) / 512);
            if floor(rows) ~= rows || floor(cols) ~= cols
                disp('Current script only handles image data that is divisible by 512.');
                return;
            end
            if isscalar(meta_data(i).ExWavelength)
                switch meta_data(i).ExWavelength
                    case 405
                        WL_num = 1;
                    case 488
                        WL_num = 2;
                    case 561
                        WL_num = 3;
                    case 640
                        WL_num = 4;
                    otherwise
                        if contains(meta_data(i).Name, '405')
                            WL_num = 1;
                        elseif contains(meta_data(i).Name, '488')
                            WL_num = 2;
                        elseif contains(meta_data(i).Name, '561')
                            WL_num = 3;
                        elseif contains(meta_data(i).Name, '640') || contains(meta_data(i).Name, '647')
                            WL_num = 4;
                        else
                            WL_num = 2;
                            warning('ExWavelength not recognized. Setting WL_num to 2 (488).');
                        end
                end
            else
                if contains(meta_data(i).Name, '405')
                    WL_num = 1;
                elseif contains(meta_data(i).Name, '488')
                    WL_num = 2;
                elseif contains(meta_data(i).Name, '561')
                    WL_num = 3;
                elseif contains(meta_data(i).Name, '640') || contains(meta_data(i).Name, '647')
                    WL_num = 4;
                else
                    WL_num = 2;
                    warning('ExWavelength not recognized. Setting WL_num to 2 (488).');
                end
            end
            
            if isempty(meta_data(i).TIRF_Direction)
                Direction_num = 1;
            else
                switch meta_data(i).TIRF_Direction
                    case 0
                        Direction_num = 1;
                    case 45
                        Direction_num = 2;
                    case 135
                        Direction_num = 3;
                    otherwise
                        Direction_num = 1;
                end
            end
            
            if NDFin_or_NDFout == 1
                shade_img = Shade_NDFin{WL_num, Direction_num};
            else
                shade_img = Shade_NDFout{WL_num, Direction_num};
            end
            
            Resized_shade_img = repmat(shade_img, [rows cols]);
            ii = 1;
            while ii <= size(processed_data{i}, 3)
                processed_data{i}(:, :, ii) = processed_data{i}(:, :, ii) ./ Resized_shade_img;
                ii = ii + 1;
            end
        end
        
        % Bleach correction.
        if bleach_correct_flag(i) == 1 && size(processed_data{i}, 3) > 3
            figure();
            y = median(processed_data{i}, [1 2]);
            y = squeeze(unique(y, 'stable'));
            x = 0:length(y)-1;
            scatter(x, y);
            [fitFunction, ~, fit_str, lifetime_tau] = KLS_Exponentialfit_and_plot(processed_data{i}, 1);
            xlabel('Frame');

            if AU_to_Photon_flag(i) == 1
                ylabel('Mean Intensity (Photons)');
            else
                ylabel('Mean Intensity (AU)');
            end

            legend('Data', fit_str, 'location', 'best');
            title({['Ch_' num2str(i) ' Bleach Correction'], ['Tau = ' num2str(lifetime_tau,3)]});

            x = 0:size(processed_data{i},3)-1;
            y = fitFunction(x);
            y = KLS_NormStack(y);
            for ii = 1:size(processed_data{i}, 3)
                processed_data{i}(:, :, ii) = processed_data{i}(:, :, ii) ./ y(ii);
            end
        end
    end
    
    % Display histograms for each channel.
    for i = 1:num_ch
        figure('Position', Pos + (i-1)*[Pos(3) 0 0 0]);
        histogram(processed_data{i}, 'Normalization', 'PDF');
        title_name = ['Histogram -- ' channel_labels{i,1}];
        title(title_name);
        box off;

        saveas(gcf,[base_save_dir '\' title_name '.png'])
        saveas(gcf,[base_save_dir '\' title_name '.fig'])
    end
    

    if save_tif_flag == 1
        %---------------------------------------------------------%
        % Save the seperate raw data from the channels
        %---------------------------------------------------------%
        for i = 1:num_ch
            file_name = ['raw_' channel_labels{i,1}]; % <--- Change Me as needed =
            KLS_save_double2tif(base_data{i,1}, file_name, Raw_dir);
        end
        
        %---------------------------------------------------------%
        % Save the seperate processed data from the channels
        %---------------------------------------------------------%
        for i = 1:num_ch
            file_name = ['processed_' channel_labels{i,1}]; % <--- Change Me as needed = 
            KLS_save_double2tif(processed_data{i,1}, file_name, Processed_dir);
        end
    end


    % Return outputs in a structure.
    results = struct();
    results.base_data = base_data;
    results.meta_data = meta_data;
    results.processed_data = processed_data;
end


function [Raw_data, base_save_dir, Raw_dir, Processed_dir] = LF_ImportFileSetup(data_dir, save_data_in_this_folder, name_of_data)
% Last update: 20241203 KLS
%    - Check for import file existance and allow ND2 or tif format,
%       preference ND2
% 20240821 KLS
%     - Allow either idx in current folder or file name
%

    base_save_dir = [save_data_in_this_folder '\' name_of_data];
    %---------------------------------------------------------%
    % Do not change this stuff
    %---------------------------------------------------------%

    %---------------------------------------------------------%
    % import data
    %---------------------------------------------------------%
    % Construct the full file path for the .nd2 file
    nd2_file = fullfile(data_dir, [name_of_data '.nd2']);
    
    % Construct the full file path for the .tif file
    tif_file = fullfile(data_dir, [name_of_data '.tif']);
    
    % Check if the .nd2 file exists
    if isfile(nd2_file)
        % If .nd2 file exists, import using KLS_ND2ImportAll
        Raw_data = KLS_ND2ImportAll(nd2_file);
    elseif isfile(tif_file)
        % If .nd2 file does not exist but .tif file does, import using KLS_TIFImportAll
        Raw_data = KLS_TifImportAll(tif_file);
    else
        % If neither file exists, throw an error
        error('That file does not exists as a .tif nor .nd2 in the specified directory.');
    end
    
    %---------------------------------------------------------%
    % This is where all the workflow's data will be saved
    %---------------------------------------------------------%
    % Check if the folder exists, and if not, create it
    if ~exist(base_save_dir, 'dir')
        % If the folder doesn't exist, create it
        mkdir(base_save_dir);
    end

    %---------------------------------------------------------%
    % Save the seperate raw data from the channels
    %---------------------------------------------------------%
    folderName = 'Raw';
    folder_path = fullfile(base_save_dir, folderName);
    if ~exist(folder_path, 'dir')
        % If folder doesn't exist, create it
        mkdir(folder_path);
    end
    Raw_dir = folder_path;

    %---------------------------------------------------------%
    % Save the seperate processed data from the channels
    %---------------------------------------------------------%
    folderName = 'Processed';
    folder_path = fullfile(base_save_dir, folderName);
    if ~exist(folder_path, 'dir')
        % If folder doesn't exist, create it
        mkdir(folder_path);
    end
    Processed_dir = folder_path;
end