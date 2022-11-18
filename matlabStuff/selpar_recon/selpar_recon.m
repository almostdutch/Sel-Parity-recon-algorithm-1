function [kspaceOP_spiritRecon, imgOP_spiritRecon, kspaceEP_spiritRecon, imgEP_spiritRecon, ...
    kspaceOP_spRecon, imgOP_spRecon, kspaceEP_spRecon, imgEP_spRecon, cpmgPhaseMap, residuals] = selpar_recon(ParsAndDataForRecon)
% function [kspaceOP_spiritRecon, imgOP_spiritRecon, kspaceEP_spiritRecon, imgEP_spiritRecon, ...
%     kspaceOP_spRecon, imgOP_spRecon, kspaceEP_spRecon, imgEP_spRecon, cpmgPhaseMap, residuals] = selpar_recon(ParsAndDataForRecon)
%
% Script implementing selpar recon algorithm #1 (old version)
%

% kspace dims
[Nfe, Npe, Ncha] = size(ParsAndDataForRecon.kspaceOP);

% Weighting scheme to control kspace signal decay and image PSF
wts_func_handle = @(a, b, t) 1 - a.*exp(-b.*t);
a_coef = ParsAndDataForRecon.a_coef;
b_coef = ParsAndDataForRecon.b_coef;
t = 1:Npe;
wts2 = wts_func_handle(a_coef, b_coef, t);
wts2_OP = wts2(ParsAndDataForRecon.echoParityArray == 1);
wts2_EP = wts2(ParsAndDataForRecon.echoParityArray == 0);
wts = ones(1, Npe);
wts(ParsAndDataForRecon.indxLinesOP) = wts2_OP;
wts(ParsAndDataForRecon.indxLinesEP) = wts2_EP;
wts = repmat(wts, [Nfe, 1]);

% Apply weighting coefficients to kspace
ParsAndDataForRecon.kspaceOP = bsxfun(@times, ParsAndDataForRecon.kspaceOP, wts);
ParsAndDataForRecon.kspaceEP = bsxfun(@times, ParsAndDataForRecon.kspaceEP, wts);

if strcmp(ParsAndDataForRecon.selparReconFlag, 'no')
    % Effectively just SPIRIT recon

    % No phase difference, hence safe to combine OP and EP kspace data
    ParsAndDataForRecon.kspaceOP = ParsAndDataForRecon.kspaceOP + ParsAndDataForRecon.kspaceEP;
    ParsAndDataForRecon.kspaceEP = ParsAndDataForRecon.kspaceOP;
    
    % Estimate the missing kspace data
    [kspaceOP_spiritRecon, kspaceEP_spiritRecon] = estimate_missing_kspace_lines(ParsAndDataForRecon);
    imgOP_spiritRecon = ifftshift(ifft2(fftshift(kspaceOP_spiritRecon)));
    imgEP_spiritRecon = ifftshift(ifft2(fftshift(kspaceEP_spiritRecon)));
    
    % Selective parity recon
    kspaceOP_spRecon = kspaceOP_spiritRecon;
    kspaceEP_spRecon = kspaceEP_spiritRecon;
    imgOP_spRecon = imgOP_spiritRecon;
    imgEP_spRecon = imgEP_spiritRecon;
    
    % CPMG phase map
    cpmgPhaseMap = angle(imgOP_spiritRecon);
    
    % Residuals
    residuals =  0;
    
    return;
end

% step 1 
% Estimate the missing lines
[kspaceOP_spiritRecon, kspaceEP_spiritRecon] = estimate_missing_kspace_lines(ParsAndDataForRecon);
imgOP_spiritRecon = ifftshift(ifft2(fftshift(kspaceOP_spiritRecon)));
imgEP_spiritRecon = ifftshift(ifft2(fftshift(kspaceEP_spiritRecon)));

% Memory preallocation
kspaceOP_spRecon = kspaceOP_spiritRecon;
kspaceEP_spRecon = kspaceEP_spiritRecon;
imgOP_spRecon = zeros(Nfe, Npe, Ncha);
imgEP_spRecon = zeros(Nfe, Npe, Ncha);
cpmgPhaseMap_all_channels = zeros(Nfe, Npe, Ncha);
residuals = zeros(1, ParsAndDataForRecon.spNiter);
for iterNo = 1:ParsAndDataForRecon.spNiter
    for chaNo = 1:Ncha
        % step 2: transform to image domain
        imgOP_spReconTemp = ifftshift(ifft2(fftshift(kspaceOP_spRecon(:, :, chaNo))));
        imgEP_spReconTemp = ifftshift(ifft2(fftshift(kspaceEP_spRecon(:, :, chaNo))));
        
        % step 3: estimate CPMG phase map
        cpmgImg = (imgOP_spReconTemp + imgEP_spReconTemp) / 2; % CPMG image
        acpmgImg = (imgOP_spReconTemp - imgEP_spReconTemp) / 2; % aCPMG image
        
        cpmgPhaseMap = angle(cpmgImg); % CPMG angle
        acpmgPhaseMap = angle(acpmgImg); % aCPMG angle
        
        % CPMG and aCPMG angles are orthogonal, use the angle coresponding to the max amplitude
        cpmgPhaseMap(abs(cpmgImg) < abs(acpmgImg)) = acpmgPhaseMap(abs(cpmgImg) < abs(acpmgImg)) + pi / 2; 
        cpmgPhaseMap_all_channels(:, :, chaNo) = cpmgPhaseMap; % bookkeeping
        
        % step 4: generate pseudo images for OP and EP
        imgOP_pseudo = conj(imgEP_spReconTemp.*exp(-1i.*cpmgPhaseMap)).*exp(1i.*cpmgPhaseMap);
        imgEP_pseudo = conj(imgOP_spReconTemp.*exp(-1i.*cpmgPhaseMap)).*exp(1i.*cpmgPhaseMap);
        
        % step 5: force information sharing between either parity and its
        % pseudo equivalent
        imgOP_new = (imgOP_spReconTemp + imgOP_pseudo) / 2;
        imgEP_new = (imgEP_spReconTemp + imgEP_pseudo) / 2;
        
        % step 6: transform to kspace
        kspaceOP_new = fftshift(fft2(ifftshift(imgOP_new)));
        kspaceEP_new = fftshift(fft2(ifftshift(imgEP_new)));
        
        % step 7: force data consistency
        kspaceOP_new(:,ParsAndDataForRecon.indxLinesOP) = ParsAndDataForRecon.kspaceOP(:, ParsAndDataForRecon.indxLinesOP, chaNo);
        kspaceEP_new(:,ParsAndDataForRecon.indxLinesEP) = ParsAndDataForRecon.kspaceEP(:, ParsAndDataForRecon.indxLinesEP, chaNo);
        
        % step 8: update selpar kspace data for subsequent iterations
        kspaceOP_spRecon(:, :, chaNo) = kspaceOP_new;
        kspaceEP_spRecon(:, :, chaNo) = kspaceEP_new;
        
        % keep track of residuals
        imgOP_spRecon(:, :, chaNo) = ifftshift(ifft2(fftshift(kspaceOP_new)));
        imgEP_spRecon(:, :, chaNo) = ifftshift(ifft2(fftshift(kspaceEP_new)));
    end
    % residuals based on SoS images
    residuals(iterNo) = norm(sos(imgOP_spRecon, 3) - sos(imgEP_spRecon, 3), 'fro') / norm(sos(imgOP_spRecon, 3), 'fro');
end
kspaceOP_spRecon = fftshift(fft2(ifftshift(imgOP_spRecon)));
kspaceEP_spRecon = fftshift(fft2(ifftshift(imgEP_spRecon)));
cpmgPhaseMap = cpmgPhaseMap_all_channels; % all channels
end