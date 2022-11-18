function master_script_selpar_recon(prefixOutputName, filePathInput, estimateMissingLinesMethod, halfKspaceSpiritFlag, coilCompressionFlag, NchaCoilCompression, ...
    spiritKernelSize, spiritNiter, spNiter, sliceArray, repArray, exp_wts_a, exp_wts_b, selparReconFlag, refDataType, refDataFullFilePath, cpmgPhaseMapFullFilePath, R)
% function master_script_selpar_recon(prefixOutputName, filePathInput, estimateMissingLinesMethod, coilCompressionFlag, NchaCoilCompression, ...
%     spiritKernelSize, spiritNiter, spNiter, sliceArray, repArray, exp_wts_a, exp_wts_b, selparReconFlag, refDataType, refDataFullFilePath, cpmgPhaseMapFullFilePath, R)
%
% prefixOutputName = prefix for output file ('')
%
% filePathInput = full path for input file
%
% estimateMissingLinesMethod = the method for the estimation of non-aquired kspace data: 
% 'zeros' (none)
% 'spirit_pocs' (SPIRIT POCS)
% 'spirit_cg' (SPIRIT conjugate gradient)
%
% halfKspaceSpiritFlag = half kspace SPIRIT flag, should be used only when data is concentrated in the right half of kspace
% 'no' (full kspace SPIRIT recon), supports both estimateMissingLinesMethod = 'spirit_pocs' and estimateMissingLinesMethod = 'spirit_cg'
% 'yes' (half kspace SPIRIT recon), forces estimateMissingLinesMethod = 'spirit_pocs'
% half kspace SPIRIT recon is possible only with 'spirit_pocs', 'spirit_cg' does not repect matrix boundaries
%
% coilCompressionFlag = coil compression flag: 
% 'no' (none)
% 'yes' (coil compression)
% when using coil compression, it is important that b0 dataset (the origin of external CPMG phase map) 
% was reconstructed using the same number of compressed channels
%
% NchaCoilCompression = the number of channels for coil compression
% 12 is sufficient to retain > 99% of total data variance
% 
% spiritKernelSize = SPIRIT kernel size 
% odd number e.g. 3, 5, 7, ..
% 
% spiritNiter = the number of iterations for SPIRIT reconstruction
% Typical number in the range 10 - 50
%
% spNiter = the number of iterations for selective parity reconstruction.
% Hardcoded and set to 1
% 
% sliceArray = array of slices to recon. 
% e.g. [1, 2, 10, ..]
% 
% repArray = array of repetitions to recon. 
% e.g. [1, 2, 10, ..]
% 
% exp_wts_a = 1st parameter of the exponential weighting function to control kspace signal decay and image PSF
% wts_func_handle = @(a, b, t) 1 - a.*exp(-b.*t);
% Typical value in the range 0.2 - 0.4
%
% exp_wts_b = 2st parameter of the exponential weighting function to control kspace signal decay and image PSF
% wts_func_handle = @(a, b, t) 1 - a.*exp(-b.*t);
% Typical value in the range 0.1 - 0.2
%
% selparReconFlag = selpar recon flag: 'no' (none), 'yes' (selpar recon)
% 'no' = effectively just does SPIRIT recon and saves a CPMG phase map for later use, 
% 'yes' = does selpar recon and uses the CPMG phase map from the previously reconstructed b0 data
%
% refDataType = type of reference data: 'int' (internal), 'ext' (external)    
% 'int' = comes from the internally acquired GRE, 
% 'ext' = comes from an external separate acquisition    
% If selparReconFlag = 'no' and  R = 1, either 'int' or 'ext' is fine
%
% refDataFullFilePath = full file path for the reference data
% if refDataType = 'int', refDataFullFilePath = ''
% 
% cpmgPhaseMapFullFilePath = full file path for the CPMG phase map
% if selparReconFlag = 'no', cpmgPhaseMapFullFilePath = ''
%
% R = acceleration factor
%

% File path/name for saving recon data
fileNameOutput = 'dataRecon.mat';
fileNameOutput = strcat(prefixOutputName, fileNameOutput);
filePathNameOutput = fullfile(filePathInput, fileNameOutput);

% File path/name for reading data
fileNameInput = 'data.mat';
filePathNameInput = fullfile(filePathInput, fileNameInput);
load(filePathNameInput)
[Nfe, Npe, Nsli, Ncha, Nrep] = size(data.kspace);

% Memory preallocation for results
if strcmp(coilCompressionFlag, 'yes')
    % with coil compression
    kspaceOP_spiritReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    kspaceEP_spiritReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    imgOP_spiritReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    imgEP_spiritReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    kspaceOP_spReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    kspaceEP_spReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    imgOP_spReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    imgEP_spReconAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
    cpmgPhaseMapAll = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep, 'single');
elseif strcmp(coilCompressionFlag, 'no')
    % without coil compression
    kspaceOP_spiritReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    kspaceEP_spiritReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    imgOP_spiritReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    imgEP_spiritReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    kspaceOP_spReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    kspaceEP_spReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    imgOP_spReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
    imgEP_spReconAll = zeros(Nfe, Npe, Nsli, Ncha, Nrep, 'single');
end
residualsAll = zeros(Nsli, Nrep, spNiter, 'single');
                
% Reference scan
NcalibPointsFEdir = 32; % the number of data points along FE dir
NcalibPointsPEdir = NcalibPointsFEdir; % the number of data points along PE dir
if R == 3
   NcalibPointsPEdir = 24; 
end

if strcmp(selparReconFlag, 'no') && R == 1
    % Does nothing but helps to keep the interface consistent
    estimateMissingLinesMethod = 'zeros';
    refDataType = 'int';
    refScan = double(data.kspace);
    cpmgPhaseMapFullFilePath = '';
else
    if strcmp(refDataType, 'int')
        % Internal ref scan
        refScan = double(data.refScan.kspace);
        if isempty(refScan)
            errorMsg = sprintf('Internal reference scan is empty, aborting...\n');
            error(errorMsg);
        end
        refDataFullFilePath = '';
    elseif strcmp(refDataType, 'ext')
        % External ref scan
        if ~isfile(refDataFullFilePath)
            errorMsg = sprintf('File %s does not exist, aborting...\n', refDataFullFilePath);
            error(errorMsg);
        end
        temp = load(refDataFullFilePath);
        % Take raw data if no ref scan is available
        if temp.data.refScan.refMatrixSize.refNfe == 0
            refScan = double(temp.data.kspace);
        else
            refScan = double(temp.data.refScan.kspace);
        end
    end
end
[refNfe, refNpe, ~, ~, ~] = size(refScan);
      
% Force parameter change to avoid conflicts
if strcmp(halfKspaceSpiritFlag, 'yes')
   estimateMissingLinesMethod = 'spirit_pocs';
end
if strcmp(selparReconFlag, 'no') && strcmp(halfKspaceSpiritFlag, 'yes')
    % half kspace SPIRIT recon can be used only with selpar recon
    errorMsg = sprintf('Parameter conflict. selparReconFlag = %s and halfKspaceSpiritFlag = %s, aborting...\n', selparReconFlag, halfKspaceSpiritFlag);
    error(errorMsg)
end

% CPMG phase map
if ~isempty(cpmgPhaseMapFullFilePath)
    if ~isfile(cpmgPhaseMapFullFilePath)
        errorMsg = sprintf('File %s does not exist, aborting...\n', cpmgPhaseMapFullFilePath);
        error(errorMsg);
    end
    temp = load(cpmgPhaseMapFullFilePath);
    cpmgPhaseMap = double(temp.dataRecon.cpmgPhaseMapAll);
else
    if strcmp(coilCompressionFlag, 'yes')
        cpmgPhaseMap = zeros(Nfe, Npe, Nsli, NchaCoilCompression, Nrep);
    elseif strcmp(coilCompressionFlag, 'no')
        cpmgPhaseMap = zeros(Nfe, Npe, Nsli, Ncha, Nrep);
    end
end

% Loop over slices and repetitions
for sliceInd = 1:numel(sliceArray)
    sliceNo = sliceArray(sliceInd);
    for repInd = 1:numel(repArray)
        repNo = repArray(repInd);
        % Raw data to recon
        kspaceOP = double(reshape(data.kspaceOP(:, :, sliceNo, :, repNo), [Nfe, Npe, Ncha]));
        kspaceEP = double(reshape(data.kspaceEP(:, :, sliceNo, :, repNo), [Nfe, Npe, Ncha]));
        
        % Coil compression
        if strcmp(coilCompressionFlag, 'yes')
            refData = refScan(refNfe / 2 - NcalibPointsFEdir / 2 + 1:refNfe / 2 + NcalibPointsFEdir / 2, refNpe / 2 - NcalibPointsPEdir / 2 + 1:refNpe / 2 + NcalibPointsPEdir / 2, sliceNo, :, 1);
            refData = reshape(refData, [NcalibPointsFEdir, NcalibPointsPEdir, Ncha]);
            
            % Reshape 3D matrices (raw data and ref data) into 2D
            kspaceOP_2D = reshape(kspaceOP, Nfe * Npe, Ncha);
            kspaceEP_2D = reshape(kspaceEP, Nfe * Npe, Ncha);
            refData_2D = reshape(refData, NcalibPointsFEdir * NcalibPointsPEdir, Ncha);
            
            % SVD of ref data
            [U, D, V]=svd(refData_2D);
            eigenVectors = V; % eigen vectors of At x A
            eigenValues = diag(D).^2; % eigen values
            clear U D V
            
            % Project raw data and ref data onto a set of NchaCoilCompression eigen
            % vectors from ref data, and reshape 2D matrices into 3D
            kspaceOP = reshape(kspaceOP_2D * eigenVectors(:,1:NchaCoilCompression), Nfe, Npe, NchaCoilCompression);
            kspaceEP = reshape(kspaceEP_2D * eigenVectors(:,1:NchaCoilCompression), Nfe, Npe, NchaCoilCompression);           
            refData = reshape(refData_2D * eigenVectors(:,1:NchaCoilCompression), NcalibPointsFEdir, NcalibPointsPEdir, NchaCoilCompression);
            phaseMap = double(reshape(cpmgPhaseMap(:, :, sliceNo, :, 1), [Nfe, Npe, NchaCoilCompression]));
        elseif strcmp(coilCompressionFlag, 'no')
            refData = refScan(refNfe / 2 - NcalibPointsFEdir / 2 + 1:refNfe / 2 + NcalibPointsFEdir / 2, refNpe / 2 - NcalibPointsPEdir / 2 + 1:refNpe / 2 + NcalibPointsPEdir / 2, sliceNo, :, 1);
            refData = reshape(refData, [NcalibPointsFEdir, NcalibPointsPEdir, Ncha]);
            phaseMap = double(reshape(cpmgPhaseMap(:, :, sliceNo, :, 1), [Nfe, Npe, Ncha]));
        end
                          
        % Pack recon pars, raw data and ref data into struct for later use
        ParsAndDataForRecon = struct('estimateMissingLinesMethod', estimateMissingLinesMethod, 'halfKspaceSpiritFlag', halfKspaceSpiritFlag, ...
            'spiritKernelSize', spiritKernelSize, 'spiritNiter', spiritNiter, 'spNiter', spNiter, ...
            'sliceNo', sliceNo, 'repNo', repNo, 'refData', refData, 'kspaceOP', kspaceOP, 'kspaceEP', kspaceEP, ...
            'indxLinesOP', data.indLines.indxLinesOP, 'indxLinesEP', data.indLines.indxLinesEP, ...
            'echoParityArray', data.echoParityArray, 'a_coef', exp_wts_a, 'b_coef', exp_wts_b, ...
            'selparReconFlag', selparReconFlag, 'phaseMap', phaseMap);
        clear refData kspaceOP kspaceEP
        
        tic;
        % Do recon
        [kspaceOP_spiritRecon, imgOP_spiritRecon, kspaceEP_spiritRecon, imgEP_spiritRecon, ...
            kspaceOP_spRecon, imgOP_spRecon, kspaceEP_spRecon, imgEP_spRecon, phaseMap, residuals] = selpar_recon(ParsAndDataForRecon);
        fprintf('SP recon done for slice: %d rep: %d [%0.1f s]\n', sliceNo, repNo, toc);

        % Bookkeeping
        kspaceOP_spiritReconAll(:,:,sliceNo,:,repNo) = kspaceOP_spiritRecon;
        kspaceEP_spiritReconAll(:,:,sliceNo,:,repNo) = kspaceEP_spiritRecon;
        imgOP_spiritReconAll(:,:,sliceNo,:,repNo) = imgOP_spiritRecon;
        imgEP_spiritReconAll(:,:,sliceNo,:,repNo) = imgEP_spiritRecon;
        kspaceOP_spReconAll(:,:,sliceNo,:,repNo) = kspaceOP_spRecon;
        kspaceEP_spReconAll(:,:,sliceNo,:,repNo) = kspaceEP_spRecon;
        imgOP_spReconAll(:,:,sliceNo,:,repNo) = imgOP_spRecon;
        imgEP_spReconAll(:,:,sliceNo,:,repNo) = imgEP_spRecon;
        cpmgPhaseMapAll(:,:,sliceNo,:,repNo) = phaseMap;
        residualsAll(sliceNo, repNo, :) = residuals;
    end
end

% Pack recon data for saving
dataRecon = struct('estimateMissingLinesMethod', estimateMissingLinesMethod, 'coilCompressionFlag', coilCompressionFlag, ...
    'NchaCoilCompression', NchaCoilCompression, 'spiritKernelSize', spiritKernelSize, 'spiritNiter', spiritNiter, ...
    'spNiter', spNiter, 'sliceArray', sliceArray, 'repArray', repArray, 'exp_wts_a', exp_wts_a, 'exp_wts_b', exp_wts_b, 'selparReconFlag', selparReconFlag, ...
    'refDataType', refDataType, 'refDataFullFilePath', refDataFullFilePath, 'cpmgPhaseMapFullFilePath', cpmgPhaseMapFullFilePath, 'R', R, ...
    'kspaceOP_spiritRecon', kspaceOP_spiritReconAll, 'kspaceEP_spiritRecon', kspaceEP_spiritReconAll, ...
    'imgOP_spiritRecon', imgOP_spiritReconAll, 'imgEP_spiritRecon', imgEP_spiritReconAll, ...
    'kspaceOP_spRecon', kspaceOP_spReconAll, 'kspaceEP_spRecon', kspaceEP_spReconAll, ...
    'imgOP_spRecon', imgOP_spReconAll, 'imgEP_spRecon', imgEP_spReconAll, ...
    'cpmgPhaseMapAll', cpmgPhaseMapAll, 'residualsAll', residualsAll);

% Save recon data
save(filePathNameOutput, 'dataRecon', '-v7.3')
end
