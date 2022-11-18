function read_raw_data_selpar(filePathInput, fileNameInput)
% read_raw_data_selpar(filePathInput, fileNameInput)
%
% Script to convert Siemens raw data file (*.dat) into MATLAB file (data.mat)
%

% File name/path for saving *.mat data
fileNameOutput = 'data.mat';
filePathNameOutput = fullfile(filePathInput, fileNameOutput);

% File name/path for reading *.dat data
filePathNameInput = fullfile(filePathInput, fileNameInput);
twix = mapVBVD(filePathNameInput);
twix = twix{2};
twix.image.dataSize(1:11);
twix.image.flagDoAverage = true;
twix.image.flagRemoveOS = true;
twix.image.flagAverageReps = false;

% Raw data matrix pars
readOversamplingFactor = 2; % readout oversampling factor
Npe = twix.image.NLin; % number of PE lines
Nfe = twix.image.NCol / readOversamplingFactor; % number of FE points per line
Nsli = twix.image.NSli; % Number of slices
Ncha = twix.image.NCha; % number of channels
Nrep = twix.image.NRep; % number of repetition
indxSli = twix.hdr.Config.chronSliceIndices(1:Nsli) + 1; % indices of slices as acquired
[~, indxSliSorted] = sort(indxSli);
indxLinesKspaceSampling = single(twix.image.Lin(1:twix.image.NLin)); % indices of kspace lines as acquired
echoParityArray=twix.image.iceParam(13,1:Npe);

% Indices of kspace lines for OP
indxLinesOP = single(indxLinesKspaceSampling(echoParityArray == 1));
indxLinesOP = unique(indxLinesOP, 'stable'); % exclude duplicates when R>=2
% Indices of kspace lines for EP
indxLinesEP = single(indxLinesKspaceSampling(echoParityArray == 0));
indxLinesEP = unique(indxLinesEP, 'stable'); % exclude duplicates when R>=2
echoParityArray = echoParityArray(1:numel(indxLinesOP) + numel(indxLinesEP)); % exclude duplicates when R>=2
indxLinesKspaceSampling = indxLinesKspaceSampling(1:numel(indxLinesOP) + numel(indxLinesEP)); % exclude duplicates when R>=2

% Save .txt (index of each kspace line as acquired)
M = indxLinesKspaceSampling;
fid = fopen(strcat(filePathInput, '/indx_lines.txt'), 'w');
for ii = 1:length(M)
    fprintf(fid,'%d,',M(ii));
end
fclose(fid);

% Save .txt (echo parity of each kspace line as acquired)
M = echoParityArray;
fid = fopen(strcat(filePathInput, '/echo_parity.txt'), 'w');
for ii=1:length(M)
    fprintf(fid,'%d,',M(ii));
end
fclose(fid);

% Raw data
twix.image.flagIgnoreSeg = true;
tempKspace = reshape(twix.image(:,:,:,1,:,1,1,1,:,1,1), [Nfe, Ncha, Npe, Nsli, Nrep]);
tempKspace = permute(tempKspace,[1 3 4 2 5]);
% little trick to take care of odd Npe
if rem(Npe, 2) == 1
    Npe = Npe + 1;
    kspace = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    kspace(:,1:Npe - 1,:,:,:) = tempKspace(:,:,:,:,:);
    
else
    kspace = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    kspace(:,:,:,:,:) = tempKspace(:,:,:,:,:);
end
kspace = kspace(:,:,indxSliSorted,:,:);
[dim1, dim2, dim3, dim4, dim5] = size(kspace);

% Raw data for OP
kspaceOP = zeros([dim1, dim2, dim3, dim4, dim5], 'single');
kspaceOP(:,indxLinesOP,:,:,:) = kspace(:,indxLinesOP,:,:,:);
% Raw data for EP
kspaceEP = zeros([dim1, dim2, dim3, dim4, dim5], 'single');
kspaceEP(:,indxLinesEP,:,:,:) = kspace(:,indxLinesEP,:,:,:);
scaling = 10e6; % artificial scaling to reduce roundoff errors due to low numbers
kspace = kspace.*scaling;
img = ifftshift(ifft2(fftshift(kspace)));
kspaceOP = kspaceOP.*scaling;
kspaceEP = kspaceEP.*scaling;

% Ref data
if isfield(twix, 'refscan')
    refNpe = twix.refscan.NLin;
    refNfe = twix.refscan.NCol / readOversamplingFactor;
    refNsli = twix.refscan.NSli;
    refNcha = twix.refscan.NCha;
    refNrep = twix.refscan.NRep;
    twix.refscan.flagDoAverage = true;
    twix.refscan.flagRemoveOS = true;
    twix.refscan.flagAverageReps = false;
    refData = reshape(twix.refscan(:,:,:,1,:,1,1,1,:,1,1), [refNfe, refNcha, refNpe, refNsli, refNrep]);
    refData = permute(refData,[1 3 4 2 5]);
    refData = refData(:,:,indxSliSorted,:,:);
    refData = refData.*scaling;
    % Ref data
    refMatrixSize = struct('refNfe', refNfe, 'refNpe', refNpe, 'refNsli', refNsli, 'refNcha', refNcha, 'refNrep', refNrep);
    refScan = struct('kspace', refData, 'refMatrixSize', refMatrixSize);
else
    % Ref data
    refMatrixSize = struct('refNfe', 0, 'refNpe', 0, 'refNsli', 0, 'refNcha', 0, 'refNrep', 0);
    refScan = struct('kspace', 0, 'refMatrixSize', refMatrixSize);
end


% Raw data
indLines = struct('indxLinesOP', indxLinesOP, 'indxLinesEP', indxLinesEP, 'indxLinesKspaceSampling', indxLinesKspaceSampling);
matrixSize = struct('Nfe', Nfe, 'Npe', Npe, 'Nsli', Nsli, 'Ncha', Ncha, 'Nrep', Nrep, 'indxSli', indxSli);
data = struct('refScan', refScan, 'kspace', kspace, 'img', img, 'kspaceOP', kspaceOP, 'kspaceEP', kspaceEP, 'echoParityArray', echoParityArray, ...
    'indLines', indLines, 'matrixSize', matrixSize);

% Save raw data
save(filePathNameOutput, 'data', '-v7.3')
end
