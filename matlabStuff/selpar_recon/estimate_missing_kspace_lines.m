function [kspaceOPestimated, kspaceEPestimated] = estimate_missing_kspace_lines(ParsAndDataForRecon)
% [kspaceOPestimated, kspaceEPestimated] = estimate_missing_kspace_lines(ParsAndDataForRecon)
%
% Script to estimate the non-aquired kspace data 
%

% kspace dims
[Nfe, Npe, Ncha] = size(ParsAndDataForRecon.kspaceOP);

% Create SPIRIT kernel
if strcmp(ParsAndDataForRecon.estimateMissingLinesMethod, 'spirit_pocs') || ...
        strcmp(ParsAndDataForRecon.estimateMissingLinesMethod, 'spirit_cg')
    spiritKernel = create_spirit_kernel(ParsAndDataForRecon.refData, ParsAndDataForRecon.spiritKernelSize);
end

if strcmp(ParsAndDataForRecon.estimateMissingLinesMethod, 'spirit_pocs')
    % SPIRIT-POCS   
    if strcmp(ParsAndDataForRecon.halfKspaceSpiritFlag, 'no')
        % Slow version: full kspace SPIRIT recon
        kspaceOPestimated = spirit_pocs(ParsAndDataForRecon.kspaceOP, spiritKernel, ParsAndDataForRecon.spiritNiter);
        kspaceEPestimated = spirit_pocs(ParsAndDataForRecon.kspaceEP, spiritKernel, ParsAndDataForRecon.spiritNiter);
    elseif strcmp(ParsAndDataForRecon.halfKspaceSpiritFlag, 'yes')
        % Fast version: half kspace SPIRIT recon
        ParsAndDataForRecon.kspaceOP = ParsAndDataForRecon.kspaceOP(:, Npe / 2 + 1:end, :); % half kspace
        ParsAndDataForRecon.kspaceEP = ParsAndDataForRecon.kspaceEP(:, Npe / 2 + 1:end, :); % half kspace
        
        kspaceOPestimated_halfKspace = spirit_pocs(ParsAndDataForRecon.kspaceOP, spiritKernel, ParsAndDataForRecon.spiritNiter); % half kspace SPIRIT recon
        kspaceEPestimated_halfKspace = spirit_pocs(ParsAndDataForRecon.kspaceEP, spiritKernel, ParsAndDataForRecon.spiritNiter); % half kspace SPIRIT recon
        
        if ~ismember(Npe / 2 + 1, ParsAndDataForRecon.indxLinesEP)
            kspaceEPestimated_halfKspace(:, 1, :) = 0; % if EP does not have k0 line, set it to 0
        end
        
        kspaceOPestimated = [zeros(Nfe, Npe / 2, Ncha), kspaceOPestimated_halfKspace(:, 1 : end, :)]; % full kspace
        kspaceEPestimated = [zeros(Nfe, Npe / 2, Ncha), kspaceEPestimated_halfKspace(:, 1 : end, :)]; % full kspace
    end
elseif strcmp(ParsAndDataForRecon.estimateMissingLinesMethod, 'spirit_cg')
    % SPIRIT-cg
    GOP = SPIRiT(spiritKernel, 'fft', [Nfe, Npe]);
    kspaceOPestimated = cgSPIRiT(ParsAndDataForRecon.kspaceOP, GOP, ParsAndDataForRecon.spiritNiter, 1e-2);
    kspaceEPestimated = cgSPIRiT(ParsAndDataForRecon.kspaceEP, GOP, ParsAndDataForRecon.spiritNiter, 1e-2);
elseif strcmp(ParsAndDataForRecon.estimateMissingLinesMethod, 'zeros')
    % Zero filling
    kspaceOPestimated = ParsAndDataForRecon.kspaceOP;
    kspaceEPestimated = ParsAndDataForRecon.kspaceEP;
end
end

function spiritKernel = create_spirit_kernel(refData, kernelSize)
% Compute SPIRIT kernel

[~, ~, Ncha] = size(refData);
opts.SYM = true;
opts.POSDEF = true;

% Collect calibration data
calibData = [];
for chaNo = 1:Ncha
    calibData = [calibData, im2col(refData(:,:,chaNo), [kernelSize, kernelSize], 'sliding').'];
end

% Initialize kernel
spiritKernel = zeros(kernelSize,kernelSize, Ncha, Ncha);
% Sample offset
offset = floor(kernelSize * kernelSize / 2) + 1;
lambda = norm(calibData'*calibData, 'fro') / size(calibData, 2) * 1e-2; % regularization
for chaNo = 1:Ncha
    % Index of estimated sample
    sampleIndx = offset + (chaNo - 1) * kernelSize * kernelSize;
    
    % Find weights
    A = [calibData(:,1:sampleIndx - 1), calibData(:,sampleIndx + 1:end)];
    At = A';
    AtA = At * A;
    lhs = AtA + eye(size(AtA)) * lambda;
    rhs = At * calibData(:,sampleIndx);
    wts = linsolve(lhs, rhs, opts);
    
    % Add a zero placeholder
    wts = [wts(1:sampleIndx-1).' 0 wts(sampleIndx:end).'];
    
    % Save kernel
    spiritKernel(:,:,:,chaNo)  = reshape(wts, kernelSize, kernelSize, Ncha);
end
end