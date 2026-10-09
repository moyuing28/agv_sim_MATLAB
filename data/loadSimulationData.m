% Function: loadSimulationData
% Purpose: Read original exported tables with explicit string Pocket keys.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function data = loadSimulationData(cfg)
names = {'stations.csv','lanes.csv','distance_matrix.csv','metadata.txt'};
for k=1:numel(names)
 assert(isfile(fullfile(cfg.projectRoot,names{k})), 'AGV:MissingFile','Missing file: %s',names{k});
end
data.stations = readtable(fullfile(cfg.projectRoot,names{1}),'TextType','string');
opts = detectImportOptions(fullfile(cfg.projectRoot,names{2}),'TextType','string');
opts = setvartype(opts,{'PocketKey','PocketName','StationType'},'string');
data.lanes = readtable(fullfile(cfg.projectRoot,names{2}),opts);
data.distanceRows = readtable(fullfile(cfg.projectRoot,names{3}));
data.metadata = fileread(fullfile(cfg.projectRoot,names{4}));
[data.distanceMatrix,data.stationMarks,data.stationToIndex] = buildDistanceMatrix(data.stations,data.distanceRows);
end
