% Goes through all folders recursively and saves SoS images "sosimg.mat"

fileName = 'dataRecon.mat';
filelist = dir(fullfile(pwd, '**/*.*'));
foldersCell = {};
count = 0;
for ii = 1:numel(filelist)
    if filelist(ii).isdir
        if ~any(ismember(foldersCell, filelist(ii).folder)) && isfile(strcat(filelist(ii).folder, '/', fileName))
            count = count + 1;
            foldersCell{count} = filelist(ii).folder;
        end
    end
end

for ii = 1:numel(foldersCell)
    temp = load(strcat(foldersCell{ii}, '/', fileName));
    img = temp.dataRecon.imgOP_spiritRecon; % OP and EP are identical after SP recon
    img = imrotate(img, 180); % if necessary
    img = squeeze(sos(img, 4)); % multichannel sos recon
    img = mean(img, 4); % average multiple repetitions
    save(strcat(foldersCell{ii}, '/sosimg.mat'), 'img', '-v7.3')
end

