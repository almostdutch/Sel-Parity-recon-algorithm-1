res = [2.3, 2.3, 3]; % image resolution
% img = images to generate bias field ('sosimg.mat')
save_nii(make_nii(double(img), res),['SelParNonBiasCorr.nii']); % convert "*.mat" file to "*.nii" file for FSL
% Linux command line to generate bias field in FSL
unix('/usr/local/fsl/bin/fast -t 2 -n 2 -b -B SelParNonBiasCorr.nii'); % generate bias field
% Save bias field in MATLAB
bias = load_nii('SelParNonBiasCorr_bias.nii.gz');
save BiasMatrix bias


