%--------------------------------------------------------------------------
% 12/20/17 JJJ: Export to LFP file
function import_lfp_(P)
    % % Merge LFP file for IMEC3 probe
    % try
    %     if ~isempty(strfind(lower(vcFile), '.imec.ap.bin'))
    %         func_ap2lf = @(x)strrep(lower(x), '.imec.ap.bin', '.imec.lf.bin');
    %         vcFile_lf = func_ap2lf(vcFile);
    %         csFile_merge_lf = cellfun(@(x)func_ap2lf(x), csFile_merge1, 'UniformOutput', 0);
    %         merge_binfile_(vcFile_lf, csFile_merge_lf);
    %     end
    % catch
    %     disp('Merge LFP file error for IMEC3.');
    % end
    P.vcFile_lfp = strrep(P.vcFile_prm, '.prm', '.lfp.jrc');
    t1 = tic;
    if isempty(P.csFile_merge)
        % single file
        if is_new_imec_(P.vcFile) % don't do anything, just set the file name
            P.vcFile_lfp = strrep(P.vcFile, '.imec.ap.bin', '.imec.lf.bin');
            P.nSkip_lfp = 12;
            P.sRateHz_lfp = 2500;
        else
            bin_file_copy_(P.vcFile, P.vcFile_lfp, P);
        end
    else % craete a merged output file
        csFiles_bin = filter_files_(P.csFile_merge);
        fid_lfp = fopen(P.vcFile_lfp, 'w');
        % multiple files merging
        P_ = P;
        for iFile = 1:numel(csFiles_bin)
            vcFile_ = csFiles_bin{iFile};
            if is_new_imec_(vcFile_)
                vcFile_ = strrep(vcFile_, '.imec.ap.bin', '.imec.lf.bin');
                P_.nSkip_lfp = 1;
            end
            bin_file_copy_(vcFile_, fid_lfp, P_);
        end
        fclose(fid_lfp);
    end
    % update the lfp file name in the parameter file
    edit_prm_file_(P, P.vcFile_prm);
    fprintf('\tLFP file (vcFile_lfp) updated: %s\n\ttook %0.1fs\n', P.vcFile_lfp, toc(t1));
end %func
