%--------------------------------------------------------------------------
% 122917 JJJ: modified
function figData = rescaleFigProj(event, hFig, figData, S0)

    if nargin < 2
        hFig = [];
    end
    if nargin < 3
        figData = [];
    end
    if nargin < 4 || isempty(S0)
        S0 = get(0, 'UserData');
    end

    if isempty(hFig) || isempty(figData)
        [hFig, figData] = getCachedFig('FigProj');
    end

    P = S0.P;

    if isnumeric(event)
        figData.maxAmp = event;
    else
        figData.maxAmp = change_amp_(event, figData.maxAmp);
    end

    maxAmp = figData.maxAmp;

    hPlots = [figData.hPlotBG, figData.hPlotFG, figData.hPlotFG2];
    if isempty(S0.secondarySelectedCluster)
        hPlots(end) = [];
    end

    % rescaleProj_(hPlots, figData.maxAmp, S0.P);
    for iPlot = 1:numel(hPlots)
        hPlot = hPlots(iPlot);
        plotData = get(hPlot, 'UserData');

        if isfield(plotData, 'hPoly')
            delete(plotData.hPoly);
        end

        if isempty(plotData)
            continue;
        end

        switch lower(P.displayFeature)
            case 'kilosort'
                bounds = maxAmp*[-1 1];
                maxPair = [];

                plotFeaturesX = plotData.PC1;
                plotFeaturesY = plotData.PC2;
                vpp = 0;

            otherwise % vpp et al.
                bounds = maxAmp*[0 1];
                maxPair = P.maxSite_show;

                plotFeaturesX = plotData.mrMax;
                plotFeaturesY = plotData.mrMin;
                vpp = 1;
        end

        [vrX, vrY, viPlot, ~] = featuresToSiteGrid(plotFeaturesX, plotFeaturesY, bounds, maxPair, vpp);

        plotData = struct_add_(plotData, viPlot, vrX, vrY, maxAmp);
        updatePlot(hPlot, vrX, vrY, plotData);
    end

    switch lower(P.displayFeature)
        case {'vpp', 'vmin', 'vmax'}
            figData.vcXLabel = 'Site # (%0.0f \\muV; upper: V_{min}; lower: V_{max})';
            figData.vcYLabel = 'Site # (%0.0f \\muV_{min})';

        case 'kilosort'
            figData.vcXLabel = sprintf('Site # (PC %d)', S0.pcPair(1));
            figData.vcYLabel = sprintf('Site # (PC %d)', S0.pcPair(2));

        otherwise
            figData.vcXLabel = sprintf('Site # (%%0.0f %s; upper: %s1; lower: %s2)', P.displayFeature, P.displayFeature, P.displayFeature);
            figData.vcYLabel = sprintf('Site # (%%0.0f %s)', P.displayFeature);
    end

    xlabel(figData.hAx, sprintf(figData.vcXLabel, figData.maxAmp));
    ylabel(figData.hAx, sprintf(figData.vcYLabel, figData.maxAmp));

    if nargout == 0
        set(hFig, 'UserData', figData);
    end
end