function kspaceRecon = spirit_pocs(kspace, kernel, Niter)
%
% SPIRIT-POCS recon
%

% Mask of acquired data
knownData = (kspace  ~= 0);
% Mask of non-acquired data
unknownData = (kspace == 0);
% Initialize reconstruction
kspaceRecon = kspace;

% SPIRIT-POCS
for n =1:Niter
    kspaceRecon = spirit_pocs_1iter(kspaceRecon, kernel);
    kspaceRecon = (kspace.*knownData) + kspaceRecon.*unknownData;
end
end

function kspaceRecon = spirit_pocs_1iter(kspace, kernel)
%
% SPIRIT-POCS 1 iteration
%

[Nfe, Npe, Ncha] = size(kspace);
% Initialize reconstruction
kspaceRecon = zeros(Nfe, Npe, Ncha);

for chaNo = 1:Ncha
    for chaNo2 = 1:Ncha
        kspaceRecon(:,:,chaNo)  = kspaceRecon(:,:,chaNo) + filter2(kernel(:,:,chaNo2, chaNo), kspace(:,:,chaNo2));
    end
end
end