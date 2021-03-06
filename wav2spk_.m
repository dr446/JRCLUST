%--------------------------------------------------------------------------
function [tnWav_spk_raw, tnWav_spk, trFet_spk, miSite_spk, viTime_spk, vnAmp_spk, vnThresh_site, fGpu] = ...
    wav2spk_(mnWav1, vrWav_mean1, P, viTime_spk, viSite_spk, mnWav1_pre, mnWav1_post)
    % tnWav_spk: spike waveform. nSamples x nSites x nSpikes
    % trFet_spk: nSites x nSpk x nFet
    % miSite_spk: nSpk x nFet
    % spikes are ordered in time
    % viSite_spk and viTime_spk is uint32 format, and tnWav_spk: single format
    % mnWav1: raw waveform (unfiltered)
    % wav2spk_(mnWav1, vrWav_mean1, P)
    % wav2spk_(mnWav1, vrWav_mean1, P, viTime_spk, viSite_spk)
    % 6/27/17 JJJ: accurate spike detection at the overlap region
    % 6/29/17 JJJ: matched filter supported

    if nargin<4, viTime_spk = []; end
    if nargin<5, viSite_spk = []; end
    if nargin<6, mnWav1_pre = []; end
    if nargin<7, mnWav1_post = []; end
    [tnWav_spk_raw, tnWav_spk, trFet_spk, miSite_spk] = deal([]);
    nFet_use = get_set_(P, 'nFet_use', 2);
    fMerge_spk = 1; %debug purpose
    fShift_pos = 0; % shift center position based on center of mass
    % fRecenter_spk = 0;
    nSite_use = P.maxSite*2+1 - P.nSites_ref;
    if nSite_use==1, nFet_use=1; end
    vnThresh_site = get0_('vnThresh_site');
    nPad_pre = size(mnWav1_pre,1);

    %-----
    % Filter
    fprintf('\tFiltering spikes...'); t_filter = tic;
    if ~isempty(mnWav1_pre) || ~isempty(mnWav1_post)
        mnWav1 = [mnWav1_pre; mnWav1; mnWav1_post];
    end
    % [mnWav2, vnWav11, mnWav1, P.fGpu] = wav_preproces_(mnWav1, P);
    mnWav1_ = mnWav1; % keep a copy in CPU
    try
        [mnWav1, P.fGpu] = gpuArray_(mnWav1, P.fGpu);
        if P.fft_thresh>0, mnWav1 = fft_clean_(mnWav1, P); end
        [mnWav2, vnWav11] = filt_car_(mnWav1, P);
    catch % GPu failure
        P.fGpu = 0;
        mnWav1 = mnWav1_;
        if P.fft_thresh>0, mnWav1 = fft_clean_(mnWav1, P); end
        [mnWav2, vnWav11] = filt_car_(mnWav1, P);
    end
    mnWav1_ = []; %remove from memory


    %-----
    % common mode rejection
    if P.blank_thresh > 0
        if isempty(vnWav11)
            vnWav11 = mr2ref_(mnWav2, P.vcCommonRef, P.viSiteZero); %vrWav_mean1(:);
        end
        vlKeep_ref = car_reject_(vnWav11(:), P);
        fprintf('Rejecting %0.3f %% of time due to motion\n', (1-mean(vlKeep_ref))*100 );
    else
        vlKeep_ref = [];
    end
    % set0_(vlKeep_ref);
    fprintf('\ttook %0.1fs\n', toc(t_filter));

    switch get_set_(P, 'vcFilter_detect', '')
        case {'', 'none'}, mnWav3 = mnWav2;
        case 'ndist'
        [mnWav3, nShift_post] = filter_detect_(mnWav1, P); % pass raw trace
        otherwise
        [mnWav3, nShift_post] = filter_detect_(mnWav2, P); % pass filtered trace
    end

    %-----
    % detect spikes or use the one passed from the input (importing)
    if isempty(vnThresh_site)
        try
            vnThresh_site = gather_(int16(mr2rms_(mnWav3, 1e5) * P.qqFactor));
        catch
            vnThresh_site = int16(mr2rms_(gather_(mnWav3), 1e5) * P.qqFactor);
            P.fGpu = 0;
        end
    end
    if isempty(viTime_spk) || isempty(viSite_spk)
        P_ = setfield(P, 'nPad_pre', nPad_pre);
        [viTime_spk, vnAmp_spk, viSite_spk] = detect_spikes_(mnWav3, vnThresh_site, vlKeep_ref, P_);
    else
        viTime_spk = viTime_spk + nPad_pre;
        vnAmp_spk = mnWav3(sub2ind(size(mnWav3), viTime_spk, viSite_spk)); % @TODO read spikes at the site and time
    end
    vnAmp_spk = gather_(vnAmp_spk);
    % if nShift_post~=0, viTime_spk = viTime_spk + nShift_post; end % apply possible shift due to filtering

    % reject spikes within the overlap region
    if ~isempty(mnWav1_pre) || ~isempty(mnWav1_post)
        ilim_spk = [nPad_pre+1, size(mnWav3,1) - size(mnWav1_post,1)]; %inclusive
        viKeep_spk = find(viTime_spk >= ilim_spk(1) & viTime_spk <= ilim_spk(2));
        [viTime_spk, vnAmp_spk, viSite_spk] = multifun_(@(x)x(viKeep_spk), viTime_spk, vnAmp_spk, viSite_spk);
    end %if
    if isempty(viTime_spk), return; end


    %-----
    % Extract spike waveforms and build a spike table
    fprintf('\tExtracting features'); t_fet = tic;
    % mnWav2 = gather_(mnWav2); %do in CPU. 10.2s in GPU, 10.4s in CPU
    % if fRecenter_spk % center site is where the energy is the highest, if disabled min is chosen
    %     tnWav_spk = mn2tn_wav_spk2_(mnWav2, viSite_spk, viTime_spk, P);
    %     %[~, viMaxSite_spk] = max(squeeze_(std(single(tnWav_spk))));
    %     [~, viMaxSite_spk] = max(squeeze_(max(tnWav_spk) - min(tnWav_spk)));
    %     viSite_spk = P.miSites(sub2ind(size(P.miSites), viMaxSite_spk(:), viSite_spk));
    % end
    viSite_spk_ = gpuArray_(viSite_spk);
    [tnWav_spk_raw, tnWav_spk, viTime_spk] = mn2tn_wav_(mnWav1, mnWav2, viSite_spk_, viTime_spk, P); fprintf('.');
    if nFet_use >= 2
        viSite2_spk = find_site_spk23_(tnWav_spk, viSite_spk_, P);
        tnWav_spk2 = mn2tn_wav_spk2_(mnWav2, viSite2_spk, viTime_spk, P);
    else
        [viSite2_spk, tnWav_spk2] = deal([]);
    end

    %-----
    % Cancel overlap
    if get_set_(P, 'fCancel_overlap', 0)
        try
            [tnWav_spk, tnWav_spk2] = cancel_overlap_spk_(tnWav_spk, tnWav_spk2, viTime_spk, viSite_spk, viSite2_spk, vnThresh_site, P);
        catch
            fprintf(2, 'fCancel_overlap failed\n');
        end
    end

    tnWav_spk_raw = gather_(tnWav_spk_raw);
    assert_(nSite_use >0, 'nSites_use = maxSite*2+1 - nSites_ref must be greater than 0');
    switch nFet_use
        case 3
        [viSite2_spk, viSite3_spk] = find_site_spk23_(tnWav_spk, viSite_spk_, P); fprintf('.');
        mrFet1 = trWav2fet_(tnWav_spk, P); fprintf('.');
        mrFet2 = trWav2fet_(tnWav_spk2, P); fprintf('.');
        mrFet3 = trWav2fet_(mn2tn_wav_spk2_(mnWav2, viSite3_spk, viTime_spk, P), P); fprintf('.');
        trFet_spk = permute(cat(3, mrFet1, mrFet2, mrFet3), [1,3,2]); %nSite x nFet x nSpk
        miSite_spk = [viSite_spk_(:), viSite2_spk(:), viSite3_spk(:)]; %nSpk x nFet
        case 2
        mrFet1 = trWav2fet_(tnWav_spk, P); fprintf('.');
        mrFet2 = trWav2fet_(tnWav_spk2, P); fprintf('.');
        trFet_spk = permute(cat(3, mrFet1, mrFet2), [1,3,2]); %nSite x nFet x nSpk
        miSite_spk = [viSite_spk_(:), viSite2_spk(:)]; %nSpk x nFet
        case 1
        mrFet1 = trWav2fet_(tnWav_spk, P); fprintf('.');
        trFet_spk = permute(mrFet1, [1,3,2]); %nSite x nFet x nSpk
        miSite_spk = [viSite_spk_(:)];
        otherwise
        error('wav2spk_: nFet_use must be 1, 2 or 3');
    end

    if nPad_pre > 0, viTime_spk = viTime_spk - nPad_pre; end
    [viTime_spk, trFet_spk, miSite_spk, tnWav_spk] = ...
    gather_(viTime_spk, trFet_spk, miSite_spk, tnWav_spk);
    fGpu = P.fGpu;
    fprintf('\ttook %0.1fs\n', toc(t_fet));
end %func
