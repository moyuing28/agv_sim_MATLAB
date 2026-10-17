function cfg = acceptanceConfig4x4()
%ACCEPTANCECONFIG4X4 Independent static synthetic dataset; production defaults stay intact.
cfg=config(); base=fileparts(mfilename('fullpath')); map=fullfile(base,'map');
cfg.stationFile=fullfile(map,'stations_acceptance_4x4.csv');
cfg.laneFile=fullfile(map,'lanes_acceptance_4x4.csv');
cfg.distanceFile=fullfile(map,'distance_matrix_acceptance_4x4.csv');
cfg.metadataFile=fullfile(map,'metadata_acceptance_4x4.txt');
cfg.cargoFile=fullfile(base,'scenarios','A01_source_pipeline_cargo.csv');
cfg.taskFile=fullfile(base,'scenarios','A01_source_pipeline_tasks.csv');
cfg.enablePlots=false; cfg.enableAnimation=false; cfg.enableAnimationGIF=false;
cfg.verbose=false; cfg.numAGV=4; cfg.agvIDs=1:4; cfg.agvInitialStations=1:4;
cfg.businessEdges=zeros(0,2);
cfg.resultsDir=fullfile(cfg.projectRoot,'results','acceptance_4x4');
end
