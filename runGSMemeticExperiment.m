function experiment = runGSMemeticExperiment(overrides,outputDirectory,progressFcn)
%RUNGSMEMETICEXPERIMENT Reusable service; main supplies formal call overrides.
% Direct API calls retain the stage-4A safe three-evaluation default.
% No files are exported unless a NEW outputDirectory is explicitly supplied.
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'data'),fullfile(root,'tasks'),fullfile(root,'simulator'), ...
 fullfile(root,'algorithms'),fullfile(root,'visualization'));
if nargin<1, overrides=struct(); end
if nargin<2, outputDirectory=""; end
if nargin<3, progressFcn=[]; end
assert(isempty(progressFcn) || isa(progressFcn,'function_handle'),'AGV:GAProgress','Expected a progress observer.');
assert(isstruct(overrides) && isscalar(overrides),'AGV:Experiment','Overrides must be a scalar struct.');
outputDirectory=string(outputDirectory);
assert(isscalar(outputDirectory) && ~ismissing(outputDirectory),'AGV:ExperimentOutput','Expected one output directory.');
if strlength(outputDirectory)>0
 assert(~isfolder(outputDirectory) && ~isfile(outputDirectory),'AGV:ExperimentOutput','Output path already exists.');
end
% Override only this invocation, never gaOptions/config defaults.
if ~isfield(overrides,'maxUniqueEvaluations'), overrides.maxUniqueEvaluations=3; end
if ~isfield(overrides,'maxGenerations'), overrides.maxGenerations=2; end
gaOptions(overrides); % Fail invalid invocation parameters before any simulation.
cfg=config(); data=loadSimulationData(cfg); dataReport=validateInputData(data);
[tasks,cargoInitial]=loadTaskConfiguration(data,cfg);
data.cargoInitial=cargoInitial; validateInputData(data,tasks,cfg);
business=zeros(0,2); if isfield(cfg,'businessEdges'), business=cfg.businessEdges; end
mapping=buildGSMapping(tasks,data.lanes,business);
seqFCFS=fcfsSequence(tasks); % Original row order, no precedence repair/encoding.
resultFCFS=simulateSchedule(seqFCFS,tasks,data,cfg);
evaluations=struct('key',{},'ts',{},'evaluation',{});
search=runGSGeneticAlgorithm(mapping,@evaluate,overrides,progressFcn);
assert(search.stats.uniqueEvaluationCount==numel(evaluations),'AGV:Experiment','Evaluator count mismatch.');
assert(numel(unique(string({evaluations.key})))==numel(evaluations),'AGV:Experiment','A unique evaluation was repeated.');
assert(isequal(decodeGS(search.best.gs,mapping),search.best.ts),'AGV:Experiment','Best GS/TS mismatch.');
% One validation replay outside the optimization budget; also supplies full logs.
bestResult=simulateSchedule(search.best.ts,tasks,data,cfg);
metrics=fieldnames(search.best.evaluation); replay=project(bestResult);
for k=1:numel(metrics)
 assert(isequaln(search.best.evaluation.(metrics{k}),replay.(metrics{k})), ...
  'AGV:ExperimentReplay','Best replay differs in %s.',metrics{k});
end
comparison=table(["FCFS";"GS-Memetic"],'VariableNames',{'Algorithm'});
names={'isFeasible','isDeadlocked','SystemMakespan','CustomerCompletionMakespan', ...
 'TotalMoveCount','totalDistance','RelocationCount','FillingCount','failureReason'};
baseline=project(resultFCFS);
for k=1:numel(names)
 name=names{k}; comparison.(name)=[baseline.(name);replay.(name)];
end
% Preserve totalDistance in map units and add explicitly labelled units.
comparison.TotalDistanceMapUnits=comparison.totalDistance;
comparison.TotalDistanceMeters=comparison.totalDistance*cfg.meterPerUnit;
comparison.MetersPerMapUnit=repmat(cfg.meterPerUnit,2,1);
for name={'emptyDistance','loadedDistance','CustomerMoveCount','FinalizeCount','ExitDistance','ReturnHomeDistance'}
 comparison.(name{1})=[resultFCFS.(name{1});bestResult.(name{1})];
end
comparison.CompletedCustomerCount=[baseline.CompletedCustomerCount;replay.CompletedCustomerCount];
improvement=NaN;
if baseline.isFeasible && replay.isFeasible && baseline.SystemMakespan>0
 improvement=100*(baseline.SystemMakespan-replay.SystemMakespan)/baseline.SystemMakespan;
end
experiment=struct('cfg',cfg,'data',data,'dataReport',dataReport,'tasks',tasks, ...
 'mapping',mapping,'seqFCFS',seqFCFS,'resultFCFS',resultFCFS,'search',search, ...
 'evaluations',evaluations,'bestResult',bestResult,'comparison',comparison, ...
 'SystemMakespanImprovementPercent',improvement,'replayExact',true, ...
 'simulationCallCount',numel(evaluations)+2,'outputDirectory',string(outputDirectory));
if strlength(string(outputDirectory))>0
 exportGSMemeticExperiment(experiment,outputDirectory);
end
 function e=evaluate(ts)
  e=gaEvaluateSimulation(ts,tasks,data,cfg);
  gs=encodeTS(ts,mapping);
  evaluations(end+1)=struct('key',gsCanonicalString(gs,mapping),'ts',ts,'evaluation',e);
 end
end
function e=project(r)
names={'isFeasible','isDeadlocked','SystemMakespan','CustomerCompletionMakespan', ...
 'TotalMoveCount','totalDistance','RelocationCount','FillingCount','failureReason'};
e=struct();
for k=1:numel(names), e.(names{k})=r.(names{k}); end
e.CompletedCustomerCount=sum(r.taskStatus=="Completed");
if ~e.isFeasible, e.SystemMakespan=NaN; e.CustomerCompletionMakespan=NaN; end
end
