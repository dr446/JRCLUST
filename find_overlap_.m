%--------------------------------------------------------------------------
% find overlapping spikes
function [cviSpk_o_1, cviSpk_o_12, cviDelay1] = find_overlap_(S0, S_clu, P)
    global trFet_spk

    snr_thresh_clu = get_set_(P, 'snr_thresh_clu', 7);

    mrDist_clu = squareform(pdist(P.mrSiteXY(S_clu.viSite_clu,:)));
    mrDist_site = squareform(pdist(P.mrSiteXY));
    nlimit = diff(P.spkLim);
    [cviDelay1, cviSpk_o_1, cviSpk_o_12] = deal(cell(1, S_clu.nClu));
    % [viTime_spk, vrAmp_spk, viSite_spk] = multifun_(@gpuArray_, S0.viTime_spk, abs(squeeze(trFet_spk(1,1,:))), S0.viSite_spk);
    [viTime_spk, vrAmp_spk, viSite_spk] = deal(S0.viTime_spk, abs(squeeze(trFet_spk(1,1,:))), S0.viSite_spk);
    [vrSnr_clu, viSite_clu, maxDist_site_um] = deal(S_clu.vrSnr_clu, S_clu.viSite_clu, P.maxDist_site_um);
    cviSpk_clu = cellfun(@int32, S_clu.cviSpk_clu, 'UniformOutput', 0);
    viTime_spk_bin = int32(round(double(viTime_spk) / double(nlimit)));
    for iClu1 = 1:S_clu.nClu
        if vrSnr_clu(iClu1) < snr_thresh_clu, continue; end
        % subtract waveform from others
        % find largest and second largest
        % fix two copies of the fet
        viSpk_clu1 = cviSpk_clu{iClu1};
        viTime_clu1 = viTime_spk(viSpk_clu1);

        % find other spikes within clu1
        viClu12 = find(mrDist_clu(:,iClu1) <= maxDist_site_um); % find nearby clu
        viClu12(viClu12 == iClu1) = []; %exclude self
        viSpk_clu12 = cell2mat(cviSpk_clu(viClu12)');
        viSite_near1 = find(mrDist_site(:,viSite_clu(iClu1)) <= maxDist_site_um);
        viSpk_clu12 = viSpk_clu12(ismember(viSite_spk(viSpk_clu12), viSite_near1));
        if isempty(viSpk_clu12), continue; end
        viSpk_clu12 = sort(viSpk_clu12);
        viSpk_clu12 = coarse_find_(viTime_spk_bin, viSpk_clu1, viSpk_clu12);
        viTime_clu12 = viTime_spk(viSpk_clu12);
        [vrAmp_spk1, vrAmp_spk12] = deal(vrAmp_spk(viSpk_clu1), vrAmp_spk(viSpk_clu12));

        % find overlapping spikes that has smaller amplitudes and within site limit
        [viOverlap1, viDelay1] = deal(zeros(size(viTime_clu1), 'like', viTime_clu1));
        vlOverlap1 = false(size(viTime_clu1));
        for iDelay = -nlimit:nlimit
            [vl_, vi12_] = ismember(viTime_clu1 + iDelay, viTime_clu12);
            vi_ = find(vl_);
            vi_(vrAmp_spk1(vi_) < vrAmp_spk12(vi12_(vi_))) = []; %ignore amplitudes larger than self
            if isempty(vi_), continue; end
            viOverlap1(vi_) = vi12_(vi_);
            viDelay1(vi_) = iDelay;
            vlOverlap1(vi_) = 1;
        end
        if ~any(vlOverlap1), continue; end
        [viOverlap1, cviDelay1{iClu1}] = multifun_(@(x)gather_(x(vlOverlap1)), viOverlap1, viDelay1);
        [cviSpk_o_1{iClu1}, cviSpk_o_12{iClu1}] = deal(viSpk_clu1(vlOverlap1), viSpk_clu12(viOverlap1));
    end %for
end %func
