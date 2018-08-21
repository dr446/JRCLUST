%--------------------------------------------------------------------------
% 12/28/17 JJJ: Support for cviShank added (reintroduced in v3.2.1)
% 9/26/17 JJJ: Added prb directory
function P = loadProbe(probeFilename, P)
    % append probe file to P
    if nargin < 2
        P = [];
    end

    % Find the probe file
    probeFilename = find_prb_(probeFilename);
    if isempty(probeFilename)
        error(['Probe file does not exist: ', probeFilename]);
    end

    try
        S_prb = load(probeFilename, '-mat');
    catch
        P.probeFile = probeFilename;
        S_prb = file2struct_(probeFilename);
    end

    P.chanMap = S_prb.channels;
    P.mrSiteXY = S_prb.geometry;
    P.vrSiteHW = S_prb.pad;
    shank = get_(S_prb, 'shank');
    cviShank = get_(S_prb, 'cviShank');

    if isempty(shank) && ~isempty(cviShank)
        shank = cviShank;
    end

    if isempty(shank)
        P.viShank_site = ones(size(S_prb.channels));
    elseif iscell(shank)
        P.viShank_site = cell2mat(arrayfun(@(i)i*ones(size(shank{i})), 1:numel(shank), 'UniformOutput', 0));
        assert(numel(P.viShank_site) == numel(S_prb.channels), 'cviShank must index all sites');
    else
        P.viShank_site = S_prb.shank;
    end

    S_prb = remove_struct_(S_prb, 'channels', 'geometry', 'pad', 'ref_sites', ...
        'viHalf', 'i', 'vcFile_file2struct', 'shank', 'cviShank');

    if isfield(P, 'nChans')
        P.viChan_aux = setdiff(1:P.nChans, 1:max(P.chanMap)); %aux channel. change for
    else
        P.viChan_aux = [];
    end

    P = mergeStructs(P, S_prb);
end %func