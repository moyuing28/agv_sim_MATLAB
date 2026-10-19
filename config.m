% Function: config
% Purpose: Central configuration; edit physical assumptions and initial stations here.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function cfg = config()
cfg.projectRoot = fileparts(mfilename('fullpath'));
cfg.stationFile = fullfile(cfg.projectRoot,'stations.csv');
cfg.laneFile = fullfile(cfg.projectRoot,'lanes.csv');
cfg.distanceFile = fullfile(cfg.projectRoot,'distance_matrix.csv');
cfg.metadataFile = fullfile(cfg.projectRoot,'metadata.txt');
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
cfg.enableAnimation = true; % Export self-contained browser playback, including blocked schedules.
cfg.animationSpeed = 5; % Simulation seconds per real second at 1x playback.
cfg.enableAnimationGIF = false; % Export looping GIFs for PowerPoint.
cfg.gifFPS = 8; % Full-map GIF: balance motion smoothness and file size.
cfg.gifMaxDuration = 20; % Maximum motion playback seconds; long schedules are accelerated.
cfg.gifResolution = [1920 1080]; % Full-map, 16:9 slide-friendly image size.
cfg.gifShowAllStations = true; % Match browser replay: all lanes, slots and initial cargo.
cfg.verbose = true;
cfg.cargoFile = fullfile(cfg.projectRoot,'tasks','cargo_initial50.csv');
cfg.taskFile = fullfile(cfg.projectRoot,'tasks','tasks_demo2.csv');
cfg.resultsDir = fullfile(cfg.projectRoot,'results');
end
