% Function: plotAGVUtilization
% Purpose: Plot busy time divided by makespan.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function fig = plotAGVUtilization(result,cfg,label)
fig=figure('Name',['Utilization - ' label]); bar(1:cfg.numAGV,100*result.agvUtilization);
xticks(1:cfg.numAGV); xticklabels(compose('AGV%02d',cfg.agvIDs)); ylabel('Utilization / %'); ylim([0 100]); title(label); grid on;
end
