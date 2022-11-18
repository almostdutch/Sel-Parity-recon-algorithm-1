% Goes through all folders recursively and executes read_raw_data_selpar(filePathInput, fileNameInput)

close all, clear all, clc
pattern = '.dat';
filelist = dir(fullfile(pwd, '**/*.*'));
count = 0;
for ii = 1:numel(filelist)
    if filelist(ii).isdir
        continue
    end
    if contains(filelist(ii).name, pattern)
        sprintf('Folder: %s, reading: %s\n', filelist(ii).folder, filelist(ii).name)
        read_raw_data_selpar(filelist(ii).folder, filelist(ii).name)
        count = count + 1;
    end
end

fprintf('Done. A total of %i files read..\n', count)