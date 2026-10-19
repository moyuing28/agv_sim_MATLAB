function options = gaOptions(overrides)
%GAOPTIONS Central stage-2 defaults; no simulator/config changes.
options=struct('populationSize',12,'offspringCount',8,'tournamentSize',3, ...
 'crossoverProbability',0.8,'mutationProbability',0.2,'maxGenerations',5, ...
 'seed',1,'minPositionDistance',0.2,'maxInitializationAttempts',10000);
if nargin<1, overrides=struct(); end
assert(isstruct(overrides) && isscalar(overrides),'AGV:GAOptions','Overrides must be a scalar struct.');
names=fieldnames(overrides);
for k=1:numel(names)
 assert(isfield(options,names{k}),'AGV:GAOptions','Unknown option: %s',names{k});
 options.(names{k})=overrides.(names{k});
end
positive={'populationSize','offspringCount','tournamentSize','maxInitializationAttempts'};
for k=1:numel(positive)
 v=options.(positive{k});
 assert(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v>=1 && v==fix(v),'AGV:GAOptions','Expected positive integer: %s',positive{k});
end
for name={'seed','maxGenerations'}
 v=options.(name{1});
 assert(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v>=0 && v==fix(v),'AGV:GAOptions','Expected nonnegative integer: %s',name{1});
end
assert(options.seed<=2^32-1 && options.tournamentSize<=options.populationSize,'AGV:GAOptions','Invalid seed or tournament size.');
for name={'crossoverProbability','mutationProbability','minPositionDistance'}
 v=options.(name{1});
 assert(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v>=0 && v<=1,'AGV:GAOptions','Expected probability/distance in [0,1].');
end
end
