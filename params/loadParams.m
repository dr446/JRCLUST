%--------------------------------------------------------------------------
function [P, paramFile] = loadParams(paramFile, fEditFile)
    % Load prm file

    if nargin<2, fEditFile = 1; end
    assert(fileExists(paramFile), sprintf('.prm file does not exist: %s\n', paramFile));
    P0 = file2struct_(jrcpath_(read_cfg_('default_prm', 0))); %P = defaultParam();
    P = file2struct_(paramFile);
    if ~isfield(P, 'template_file'), P.template_file = ''; end
    if ~isempty(P.template_file)
        dialogAssert(fileExists(P.template_file), sprintf('template file does not exist: %s', P.template_file));
        P = mergeStructs(file2struct_(P.template_file), P);
    end
    P.paramFile = paramFile;
    dialogAssert(isfield(P, 'vcFile'), sprintf('Check "%s" file syntax', paramFile));

    if ~fileExists(P.vcFile) && isempty(get_(P, 'multiFilenames'))
        P.vcFile = replacePath_(P.vcFile, paramFile);
        if ~fileExists(P.vcFile)
            fprintf('vcFile not specified. Assuming multi-file format ''csFiles_merge''.\n');
        end
    end


    %-----
    % Load prb file
    if ~isfield(P, 'probeFile'), P.probeFile = P0.probeFile; end
    try
        probeFile_ = find_prb_(P.probeFile);
        if isempty(probeFile_)
            P.probeFile = replacePath_(P.probeFile, paramFile);
            dialogAssert(fileExists(P.probeFile), 'prb file does not exist');
        else
            P.probeFile = probeFile_;
        end
        P0 = loadProbe(P.probeFile, P0);
    catch
        fprintf(2, 'loadParams: %s not found.\n', P.probeFile);
    end
    P = mergeStructs(P0, P);
    P = calc_maxSite_(P);

    % check GPU
    P.useGPU = ifeq_(license('test', 'Distrib_Computing_Toolbox'), P.useGPU, 0);
    if P.useGPU
        P.useGPU = (gpuDeviceCount() > 0);
    end

    % Legacy support
    if isfield(P, 'fTranspose'), P.fTranspose_bin = P.fTranspose; end

    % Compute fields
    P = struct_default_(P, 'fWav_raw_show', 0);
    P = struct_default_(P, 'paramFile', subsFileExt_(P.vcFile, '.prm'));
    P = struct_default_(P, 'groundTruthFile', '');
    if ~isfield(P, 'groundTruthFile') || isempty(P.groundTruthFile), P.groundTruthFile = subsFileExt_(P.paramFile, '_gt.mat'); end
    P.spkRefrac = round(P.spkRefrac_ms * P.sampleRateHz / 1000);
    P.spkLim = round(P.spkLim_ms * P.sampleRateHz / 1000);
    P.spkLim_raw = calc_spkLim_raw_(P);

    if isempty(get_(P, 'nDiff_filt'))
        if isempty(get_(P, 'nDiff_ms_filt'))
            P.nDiff_filt = 0;
        else
            P.nDiff_filt = ceil(P.nDiff_ms_filt * P.sampleRateHz / 1000);
        end
    end
    if ~isempty(get_(P, 'viChanZero')) && isempty(P.viSiteZero)
        [~, viSiteZero] = ismember(P.viChanZero, P.chanMap);
        P.viSiteZero = viSiteZero(viSiteZero>0);
    end
    if ~isempty(get_(P, 'viSiteZero')), P.viSiteZero(P.viSiteZero > numel(P.chanMap)) = []; end
    if ~isfield(P, 'viShank_site'), P.viShank_site = []; end
    try P.miSites = findNearSites_(P.mrSiteXY, P.maxSite, P.viSiteZero, P.viShank_site); catch; end %find closest sites
    % LFP sampling rate
    if ~isempty(get_(P, 'nSkip_lfp'))
        P.sampleRateHz_lfp = P.sampleRateHz / P.nSkip_lfp;
    else
        P.sampleRateHz_lfp = getOr(P, 'sampleRateHz_lfp', 2500);
        P.nSkip_lfp = round(P.sampleRateHz / P.sampleRateHz_lfp);
    end
    P.bytesPerSample = bytesPerSample_(P.dataType);
    P = struct_default_(P, 'paramFile', subsFileExt_(P.vcFile, '.prm'));
    if ~isempty(get_(P, 'gain_boost')), P.uV_per_bit = P.uV_per_bit / P.gain_boost; end
    P.spkThresh = P.spkThresh_uV / P.uV_per_bit;
    P = struct_default_(P, 'cvrDepth_drift', {});
    P = struct_default_(P, {'maxSite_fet', 'maxSite_detect', 'maxSite_sort','maxSite_pix', 'maxSite_dip', 'maxSite_merge', 'maxSite_show'}, P.maxSite);
    P = struct_default_(P, 'mrColor_proj', [.75 .75 .75; 0 0 0; 1 0 0]);
    P.mrColor_proj = reshape(P.mrColor_proj(:), [], 3); %backward compatible
    P = struct_default_(P, {'blank_thresh', 'thresh_corr_bad_site', 'tlim_load'}, []);
    if numel(P.tlim)==1, P.tlim = [0, P.tlim]; end
    if isfield(P, 'rejectSpk_mean_thresh'), P.blank_thresh = P.rejectSpk_mean_thresh; end
    P.vcFilter = get_filter_(P);
    if isempty(get_(P, 'vcFilter_show'))
        P.vcFilter_show = P.vcFilter;
    end
    dialogAssert(validate_param_(P), 'Parameter file contains error.');
    if fEditFile, edit(P.paramFile); end % Show settings file
end % function
