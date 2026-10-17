% Function: loadSimulationData
% Purpose: Read original exported tables with explicit string Pocket keys.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function data = loadSimulationData(cfg)
names = {'stations.csv','lanes.csv','distance_matrix.csv','metadata.txt'};
fields = {'stationFile','laneFile','distanceFile','metadataFile'};
paths = cell(size(names));
for k=1:numel(names)
 paths{k}=fullfile(cfg.projectRoot,names{k});
 if isfield(cfg,fields{k}), paths{k}=cfg.(fields{k}); end
 assert(isfile(paths{k}), 'AGV:MissingFile','Missing file: %s',paths{k});
end
data.stations = readtable(paths{1},'TextType','string');
opts = detectImportOptions(paths{2},'TextType','string');
opts = setvartype(opts,{'PocketKey','PocketName','StationType'},'string');
data.lanes = readtable(paths{2},opts);
data.distanceRows = readtable(paths{3});
data.metadata = fileread(paths{4});
[data.distanceMatrix,data.stationMarks,data.stationToIndex] = buildDistanceMatrix(data.stations,data.distanceRows);
end
