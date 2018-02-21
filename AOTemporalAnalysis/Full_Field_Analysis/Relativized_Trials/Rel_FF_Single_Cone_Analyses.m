% function [fitCharacteristics]=Rel_FF_Single_Cone_Analyses(stimRootDir, controlRootDir)
% [fitCharacteristics]=Rel_FF_Single_Cone_Analyses(stimRootDir, controlRootDir)
%
%   Calculates pooled variance across a set of pre-analyzed 
%   signals from a single cone's stimulus and control trials, performs 
%   the subtraction between its standard deviations, and performs a
%   piecewise fit of the subtraction.
%
%   This script is designed to work with FULL FIELD datasets- that is, each
%   dataset (mat file) contains *only* control or stimulus data.
%
%   Normally, the user doesn't need to select a stimulus or control root
%   directory (that will be found automatically by
%   "FF_Aggregate_Multi_Trial_Run.m"), but if the software is run by
%   itself it will prompt the user for the folders containing the
%   pre-analyzed mat files generated by Rel_FF_Temporal_Reflectivity_Analysis.m.
%
% Inputs:
%       stimRootDir: The folder path of the pre-analyzed (.mat) stimulus
%       trials. Each mat file must contain valid stimulus signals.
%
%       controlRootDir: The folder path of the pre-analyzed (.mat) control
%       trials. Each mat file must contain valid control signals.
%
%
% Outputs:
%       fitCharacteristics: Information extracted from the mat files and
%       the fitted subtracted signal.
%
% Created by Robert F Cooper 2017-10-31
%

clear;
close all;

CUTOFF = 26;

if ~exist('stimRootDir','var')
    close all force;
    stimRootDir = uigetdir(pwd, 'Select the directory containing the stimulus profiles');
    controlRootDir = uigetdir(pwd, 'Select the directory containing the control profiles');
end

profileSDataNames = read_folder_contents(stimRootDir,'mat');
profileCDataNames = read_folder_contents(controlRootDir,'mat');


% For structure:
% /stuff/id/date/wavelength/time/intensity/location/data/Profile_Data

[remain kid] = getparent(stimRootDir); % data
[remain stim_loc] = getparent(remain); % location 
[remain stim_intensity] = getparent(remain); % intensity 
[remain stim_time] = getparent(remain); % time
[remain stimwave] = getparent(remain); % wavelength
% [remain sessiondate] = getparent(remain); % date
[~, id] = getparent(remain); % id


%% Code for determining variance across all signals at given timepoint

THEwaitbar = waitbar(0,'Loading stimulus profiles...');

max_index=0;

load(fullfile(stimRootDir, profileSDataNames{1}));
stim_coords = ref_coords;

stim_cell_reflectance = cell(length(profileSDataNames),1);
stim_time_indexes = cell(length(profileSDataNames),1);
stim_cell_prestim_mean = cell(length(profileSDataNames),1);

for j=1:length(profileSDataNames)

    waitbar(j/length(profileSDataNames),THEwaitbar,'Loading stimulus profiles...');
    
    ref_coords=[];
    profileSDataNames{j}
    load(fullfile(stimRootDir,profileSDataNames{j}));
    
    stim_cell_reflectance{j} = norm_cell_reflectance;
    stim_time_indexes{j} = cell_times;
    stim_cell_prestim_mean{j} = cell_prestim_mean;
    
    thesecoords = union(stim_coords, ref_coords,'rows');
    
    % These all must be the same length! (Same coordinate set)
    if size(ref_coords,1) ~= size(thesecoords,1)
        error('Coordinate lists different between mat files in this directory. Unable to perform analysis.')
    end
    
    for k=1:length(cell_times)
        max_index = max([max_index max(cell_times{k})]);
    end
    
end

%%
control_cell_reflectance = cell(length(profileCDataNames),1);
control_time_indexes = cell(length(profileCDataNames),1);
control_cell_prestim_mean = cell(length(profileCDataNames),1);

load(fullfile(controlRootDir, profileCDataNames{1}));
control_coords = ref_coords;

for j=1:length(profileCDataNames)

    waitbar(j/length(profileCDataNames),THEwaitbar,'Loading control profiles...');
    
    ref_coords=[];
    profileCDataNames{j}
    load(fullfile(controlRootDir,profileCDataNames{j}));
        
    control_cell_reflectance{j} = norm_cell_reflectance;
    control_time_indexes{j} = cell_times;
    control_cell_prestim_mean{j} = cell_prestim_mean;

    thesecoords = union(control_coords, ref_coords,'rows');
    
    % The length of the cell reflectance lists *must* be the same, because the
    % coordinate lists *must* be the same in each mat file.
    if size(ref_coords,1) ~= size(thesecoords,1)
        error('Coordinate lists different between mat files in this directory. Unable to perform analysis.')
    end
    
    for k=1:length(cell_times)
        max_index = max([max_index max(cell_times{k})]);
    end
    
end

%% The coordinate lists must the same length,
% otherwise it's not likely they're from the same set.

if size(stim_coords,1) ~= size(control_coords,1)
    error('Coordinate lists different between control and stimulus directories. Unable to perform analysis.')
end

allcoords = stim_coords;


%% Aggregation of all trials

percentparula = parula(101);

stim_cell_var = nan(size(stim_coords,1), max_index);
stim_cell_median = nan(size(stim_coords,1), max_index);
stim_trial_count = zeros(size(stim_coords,1),1);
stim_posnegratio = nan(size(stim_coords,1),max_index);
% ratioplotnums=[];

for i=1:size(stim_coords,1)
    waitbar(i/size(stim_coords,1),THEwaitbar,'Processing stimulus signals...');
    
%     figure(1);
%     clf;
%     hold on;
    
    numtrials = 0;
    all_times_ref = nan(length(profileSDataNames), max_index);
    for j=1:length(profileSDataNames)
        
        if ~isempty(stim_cell_reflectance{j}{i}) && ...
           sum(stim_time_indexes{j}{i} >= 67 & stim_time_indexes{j}{i} <=99) >= CUTOFF
            
            % Find out what percentage of time the signal spends negative
            % or positive after stimulus delivery (66th frame)
            numposneg = sign(stim_cell_reflectance{j}{i}(stim_time_indexes{j}{i}>66));
            pos = sum(numposneg == 1);

%             subplot(3,1,1);hold on; plot(stim_time_indexes{j}{i}, (stim_cell_reflectance{j}{i}) );
%             xlabel('Frame #'); ylabel('Standardized reflectance'); title(num2str(i));

            stim_posnegratio(i,j) = round(100*pos/length(numposneg))+1;                        
%             if ~isnan(stim_posnegratio(i,j)) && ~isinf(stim_posnegratio(i,j))
% %                 ratioplotnums = [ratioplotnums;stim_cell_prestim_mean{j}(i) posnegatio];
%                 subplot(3,1,2);hold on; plot(j, stim_cell_prestim_mean{j}(i),'.','Color',percentparula(stim_posnegratio(i,j),:),'MarkerSize', 15 );
%                 axis([0 50 0 255]); xlabel('Trial #'); ylabel('Prestimulus reflectance (AU)');
%             end
        
            numtrials = numtrials+1;
            all_times_ref(j, stim_time_indexes{j}{i} ) = stim_cell_reflectance{j}{i};
        end
    end 
    stim_trial_count(i) = numtrials;
    

    for j=1:size(stim_cell_var,2)
        nonan_ref = all_times_ref(~isnan(all_times_ref(:,j)), j);
        refcount = sum(~isnan(all_times_ref(:,j)));
        refmedian = median(nonan_ref);
        if ~isnan(refmedian)
            stim_cell_median(i,j) = refmedian;            
            stim_cell_var(i,j) = ( sum((nonan_ref-refmedian).^2)./ (refcount-1) );
        end
    end
%     subplot(3,1,3);
%     plot(stim_cell_mean(i,:));hold on;
%     plot(sqrt(stim_cell_var(i,:)));
    
    
%     figure(2); 
%     hold on;
%     clf;
%     subplot(4,1,4);
%     plot(abs(stim_cell_mean(i,:)) +sqrt(stim_cell_var(i,:)) ); 
%      drawnow; hold off;

%     if i == 400
%         pause;
%     end
%     saveas(gcf,['NC_11043_stimulus_cone_' num2str(i) '_stddev_' num2str(numtrials) '_trials.png']);
end


%%
control_cell_var = nan(size(control_coords,1), max_index);
control_cell_median = nan(size(control_coords,1), max_index);
control_trial_count = zeros(size(control_coords,1),1);
control_posnegratio = nan(size(control_coords,1),max_index);

for i=1:size(control_coords,1)
    waitbar(i/size(control_coords,1),THEwaitbar,'Processing control signals...');
%     figure(3);
%     clf;
%     hold on;
    
    numtrials = 0;
    all_times_ref = nan(length(profileCDataNames), max_index);
    for j=1:length(profileCDataNames)
                
        % Find out what percentage of time the signal spends negative
        % or positive after stimulus delivery (66th frame)
        numposneg = sign(control_cell_reflectance{j}{i}(control_time_indexes{j}{i}>66));
        pos = sum(numposneg == 1);

%         subplot(2,1,1);hold on; plot(control_time_indexes{j}{i}, (control_cell_reflectance{j}{i}) );
%         xlabel('Frame #'); ylabel('Standardized reflectance'); title(num2str(i));

        control_posnegratio(i,j) = round(100*pos/length(numposneg))+1;
%         if ~isnan(posnegatio) && ~isinf(posnegatio)
%             subplot(2,1,2);hold on; plot(j, control_cell_prestim_mean{j}(i),'.','Color',percentparula(posnegatio,:),'MarkerSize', 15 );
%             axis([0 100 0 255]); xlabel('Trial #'); ylabel('Prestimulus reflectance (AU)');
%         end
        
        if ~isempty(control_cell_reflectance{j}{i}) && ...
           sum(control_time_indexes{j}{i} >= 67 & control_time_indexes{j}{i} <=99) >=  CUTOFF
       
            numtrials = numtrials+1;
            all_times_ref(j, control_time_indexes{j}{i} ) = control_cell_reflectance{j}{i};
        end
    end
    control_trial_count(i) = numtrials;
%     drawnow;
%     saveas(gcf,['NC_11043_control_cone_' num2str(i) '_signals_' num2str(numtrials) '_trials.png']);

%     if i == 400
%             pause;
%     end
%     if numtrials > 75
%         drawnow;
%         frm = getframe(gcf);        
%         imwrite(frm.cdata, 'Signal_vs_prestim_ref_controls.tif','WriteMode','append');
%     end
    
    for j=1:size(control_cell_var,2)
        nonan_ref = all_times_ref(~isnan(all_times_ref(:,j)), j);
        refcount = sum(~isnan(all_times_ref(:,j)));
        refmedian = median(nonan_ref);
        if ~isnan(refmedian)
            control_cell_median(i,j) = refmedian;
            control_cell_var(i,j) = ( sum((nonan_ref-refmedian).^2)./ (refcount-1) );
        end
    end
%     figure(4);
%     hold on;
%     clf;
%     plot(control_cell_stddev(i,:)); drawnow;
%     saveas(gcf,['NC_11043_control_cone_' num2str(i) '_stddev_' num2str(numtrials) '_trials.png']);
end





%% Calculate the pooled std deviation
std_dev_sub = sqrt(stim_cell_var)-sqrt(control_cell_var);
median_sub = stim_cell_median-control_cell_median;

% Possible bug- first index is always nan?
std_dev_sub = std_dev_sub(:,2:end);
median_sub = median_sub(:,2:end);

timeBase = ((1:max_index-1)/16.6)';

fitAmp = nan(size(std_dev_sub,1),1);
fitMedian = nan(size(std_dev_sub,1),1);
fitAngle = nan(size(std_dev_sub,1),1);
% waitbar(1/size(std_dev_sub,1),THEwaitbar,'Fitting subtracted signals...');

parfor i=1:size(std_dev_sub,1)

% Filtering
    std_dev_sig = std_dev_sub(i,:);
%     padding_amt = ceil((2^(nextpow2(length(std_dev_sig)))-length(std_dev_sig)) /2);
%     padded_stddev_sig = padarray(std_dev_sig, [0  padding_amt],'symmetric', 'both');
%     padded_stddev_sig=wavelet_denoise( padded_stddev_sig );
%     filt_stddev_sig = padded_stddev_sig(padding_amt+1:end-padding_amt);
% 
    median_sig = median_sub(i,:);
%     padding_amt = ceil((2^(nextpow2(length(median_sig)))-length(median_sig)) /2);
%     padded_mean_sig = padarray(median_sig, [0  padding_amt],'symmetric', 'both');
%     padded_mean_sig=wavelet_denoise( padded_mean_sig );
%     filt_mean_sig = padded_mean_sig(padding_amt+1:end-padding_amt);
             
    

    
    if ~all( isnan(std_dev_sig) ) && (stim_trial_count(i) >= 25) && (control_trial_count(i) >= 25)
%         figure(2);clf; plot(timeBase,std_dev_sig);

% Fitting
%         fitData = modelFit_beta(timeBase, std_dev_sig', []);
%         fitAmp(i) = fitData.amplitude;
%         
%         fitData = modelFit_beta(timeBase, median_sig', [] );
%         fitMedian(i) = fitData.amplitude;
        
%         fitMean(i) = fitDataStim.amplitude - fitDataCont.amplitude;

% Filtering AUC
%         [~, themaxind]=max( abs(filt_stddev_sig(67:116)) );

%         fitAmp(i) = filt_stddev_sig(66+themaxind) - mean(filt_stddev_sig(1:66));
%         fitAmp(i) = sum(filt_stddev_sig(67:116)) - sum(filt_stddev_sig(17:66));
%         if fitAmp(i)==0
%            figure(200); plot(timeBase,std_dev_sig,timeBase,filt_stddev_sig);
%            figure(201); plot(timeBase,mean_sub(i,:), timeBase, filt_mean_sig); 
%            fitAmp(i) 
%         end
        
%         [~, themaxind]=max(abs(filt_mean_sig(67:116)));
%         
%         fitMean(i) = filt_mean_sig(66+themaxind) - mean(filt_mean_sig(1:66));
%         fitMean(i) = sum(filt_mean_sig(67:116)) - sum(filt_mean_sig(17:66));
        
% AUC        
        fitAmp(i) = sum(std_dev_sig(66:100)) - sum(std_dev_sig(31:65));
        fitMedian(i) = sum(median_sig(66:100)) - sum(median_sig(31:65));

%         figure(2);clf; 
%         plot(timeBase,stim_cell_mean(i, 2:end)); hold on;
%         plot(timeBase,control_cell_mean(i, 2:end)); hold off;
%         title( num2str(fitMean(i)));
        


    end
end
close(THEwaitbar);

%% Plot the pos/neg ratio of the mean vs the amplitude
posnegratio=nan(size(control_coords,1),1);


figure(101); clf; hold on;
for i=1:size(control_coords,1)
    if ~isnan(fitAmp(i))
        % Find out what percentage of time the signal spends negative
        % or positive after stimulus delivery (66th frame)
%         numposneg = sign(mean_sub(i,:));
%         pos = sum(numposneg == 1);
% 
%         posnegratio(i) = 100*pos/length(numposneg);

        plot( fitAmp(i),fitMedian(i),'k.');        
    end
end
ylabel('Median response amplitude');
xlabel('Reflectance response amplitude');
title('Median reflectance vs reflectance response amplitude')
hold off;
saveas(gcf,['posneg_vs_amp_' num2str(stim_intensity) '.png']);
%% Plot histograms of the amplitudes
% figure(5); 
% histogram( ( control_amps(~isnan(control_amps)) ),'Binwidth',0.1); hold on;
% histogram( ( stim_amps(~isnan(stim_amps)) ),'Binwidth',0.1);  hold off;
% title('Stimulus and control inter-trial stddev amplitudes');
% xlabel('Amplitude');
% ylabel('Number of cones');

figure(7);
histogram( fitAmp(~isnan(fitAmp)) ,'Binwidth',0.1);
title('Stim-Control per cone subtraction amplitudes');
xlabel('Amplitude difference from control');
ylabel('Number of cones');

%% Output


save([ stim_intensity '.mat'],'fitAmp','fitMedian','fitAngle',...
     'allcoords','ref_image','control_cell_median',...
     'control_cell_var','stim_cell_median','stim_cell_var');
