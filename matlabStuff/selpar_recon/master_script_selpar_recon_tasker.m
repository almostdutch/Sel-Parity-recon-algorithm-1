% Put all the recon tasks to run (sequentially) here

% selpar recon interface
% function master_script_selpar_recon(prefixOutputName, filePathInput, estimateMissingLinesMethod, halfKspaceSpiritFlag, coilCompressionFlag, NchaCoilCompression, ...
%     spiritKernelSize, spiritNiter, spNiter, sliceArray, repArray, exp_wts_a, exp_wts_b, selparReconFlag, refDataType, refDataFullFilePath, cpmgPhaseMapFullFilePath, R)

close all, clc
path = strcat(pwd, ''); % path to top directory

% SP-DW-HASTE recon
a_coef = 0.0; 
b_coef = 0.0;
seq = 'sp'; % sequence = SP-DW-HASTE

b_value = 'b0';
R = 2;
file = sprintf('%s/%s/%s/R%i/', path, seq, b_value, R);
master_script_selpar_recon('', file, 'spirit_cg', 'no', 'no', 22, 5, 100, 30, 1:5, 1, a_coef, b_coef, 'no', 'int', '', '', R)

b_value = 'b1000p';
R = 2;
file = sprintf('%s/%s/%s/R%i/', path, seq, b_value, R);
master_script_selpar_recon('', file, 'spirit_cg', 'no', 'no', 22, 5, 100, 30, 1:5, 1, a_coef, b_coef, 'yes', 'int', '', '', R)


% DW-HASTE recon
a_coef = 0.0; 
b_coef = 0.0;
seq = 'haste'; % sequence = DW-HASTE

b_value = 'b0';
R = 2;
file = sprintf('%s/%s/%s/R%i/', path, seq, b_value, R);
master_script_selpar_recon('', file, 'spirit_cg', 'no', 'no', 22, 5, 100, 30, 1:5, 1, a_coef, b_coef, 'no', 'int', '', '', R)

b_value = 'b1000p';
R = 2;
file = sprintf('%s/%s/%s/R%i/', path, seq, b_value, R);
master_script_selpar_recon('', file, 'spirit_cg', 'no', 'no', 22, 5, 100, 30, 1:5, 1, a_coef, b_coef, 'no', 'int', '', '', R)
