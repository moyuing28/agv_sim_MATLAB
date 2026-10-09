% Function: config
% Purpose: Central configuration; edit physical assumptions and initial stations here.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function cfg = config()
cfg.projectRoot = fileparts(mfilename('fullpath'));
cfg.meterPerUnit = 0.01;
cfg.agvSpeed = 1.0;
cfg.pickTime = 5;
cfg.dropTime = 5;
cfg.numAGV = 4;
cfg.agvIDs = [2 3 4 5]; % Actual vehicle IDs: AGV02, AGV03, AGV04, AGV05
cfg.agvInitialStations = [2 4 0 3]; % Same order as agvIDs
cfg.randomSeed = 1;
cfg.invalidCost = 1e12;
cfg.enablePlots = true;
cfg.verbose = true;
cfg.exampleTaskCount = 15;
cfg.exampleDropoffStation = 6;
cfg.resultsDir = fullfile(cfg.projectRoot,'results');
end
