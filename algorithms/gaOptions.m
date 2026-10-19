function options = gaOptions(overrides)
%GAOPTIONS Central search defaults; no simulator/config changes.
options=struct('populationSize',12,'offspringCount',8,'tournamentSize',3, ...
 'crossoverProbability',0.8,'mutationProbability',0.2,'maxGenerations',5, ...
 'seed',1,'minPositionDistance',0.2,'maxInitializationAttempts',10000, ... % Legacy distance option; selector no longer uses it.
 'maxUniqueEvaluations',100,'localSearchEvaluations',3, ...
 'enableStallStop',true,'stallGenerations',4, ...
 'eliteCount',6,'qualityPoolSize',18,'makespanToleranceLevels',[0.02 0.05 0.10]);
if nargin<1, overrides=struct(); end
assert(isstruct(overrides) && isscalar(overrides),'AGV:GAOptions','Overrides must be a scalar struct.');
names=fieldnames(overrides);
for k=1:numel(names)
 assert(isfield(options,names{k}),'AGV:GAOptions','Unknown option: %s',names{k});
 options.(names{k})=overrides.(names{k});
end
positive={'populationSize','offspringCount','tournamentSize','maxInitializationAttempts','maxUniqueEvaluations','stallGenerations','eliteCount','qualityPoolSize'};
for k=1:numel(positive)
 v=options.(positive{k});
 assert(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v>=1 && v==fix(v),'AGV:GAOptions','Expected positive integer: %s',positive{k});
end
levels=options.makespanToleranceLevels;
assert(isnumeric(levels) && isreal(levels) && isvector(levels) && ~isempty(levels) && ...
 all(isfinite(levels)) && all(levels>=0) && all(diff(levels)>0), ...
 'AGV:GAOptions','Makespan tolerance levels must be finite, nonnegative and strictly increasing.');
options.makespanToleranceLevels=reshape(levels,1,[]);
for name={'seed','maxGenerations','localSearchEvaluations'}
 v=options.(name{1});
 assert(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v>=0 && v==fix(v),'AGV:GAOptions','Expected nonnegative integer: %s',name{1});
end
assert(options.localSearchEvaluations<=3,'AGV:GAOptions','Local search permits at most three new evaluations per generation.');
assert(isscalar(options.enableStallStop) && (islogical(options.enableStallStop) || isnumeric(options.enableStallStop)) && ...
 ismember(options.enableStallStop,[0 1]),'AGV:GAOptions','enableStallStop must be logical.');
assert(options.seed<=2^32-1 && options.tournamentSize<=options.populationSize,'AGV:GAOptions','Invalid seed or tournament size.');
for name={'crossoverProbability','mutationProbability','minPositionDistance'}
 v=options.(name{1});
 assert(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v>=0 && v<=1,'AGV:GAOptions','Expected probability/distance in [0,1].');
end
end
