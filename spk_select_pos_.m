%--------------------------------------------------------------------------
% 17/12/5 JJJ: If lim_y criteria is not found return the original
function [viSpk_clu2, viSite_clu2] = spk_select_pos_(viSpk_clu1, vrPosY_spk1, lim_y, nSamples_max, viSite_clu1);
    vlSpk2 = vrPosY_spk1 >= lim_y(1) & vrPosY_spk1 < lim_y(2);
    if ~any(vlSpk2)
        [viSpk_clu2, viSite_clu2] = deal(viSpk_clu1, viSite_clu1);
        return;
    end
    viSpk_clu2 = subsample_vr_(viSpk_clu1(vlSpk2), nSamples_max);
    if nargout>=2
        viSite_clu2 = subsample_vr_(viSite_clu1(vlSpk2), nSamples_max);
    end
end %func
