function [evaluate,getStats,getBudget] = gaCreateEvaluator(mapping,evaluator,maxUniqueEvaluations)
%GACREATEEVALUATOR New in-memory cache per run; evaluator takes decoded TS.
assert(isa(evaluator,'function_handle'),'AGV:GAEvaluator','Evaluator must be a function handle.');
if nargin<3, defaults=gaOptions(); maxUniqueEvaluations=defaults.maxUniqueEvaluations; end
assert(isnumeric(maxUniqueEvaluations) && isreal(maxUniqueEvaluations) && isscalar(maxUniqueEvaluations) && ...
 isfinite(maxUniqueEvaluations) && maxUniqueEvaluations>=0 && maxUniqueEvaluations==fix(maxUniqueEvaluations), ...
 'AGV:GABudget','Budget must be a nonnegative integer.');
cache=containers.Map('KeyType','char','ValueType','any');
stats=struct('candidateGeneratedCount',0,'uniqueEvaluationCount',0,'cacheHitCount',0);
budgetDenied=0; localDenied=0;
evaluate=@lookup; getStats=@snapshot; getBudget=@budgetSnapshot;
 function [candidate,status]=lookup(gs,allowNew)
  if nargin<2, allowNew=true; end
  assert(isscalar(allowNew) && ismember(allowNew,[0 1]),'AGV:GABudget','allowNew must be logical.');
  key=gsCanonicalString(gs,mapping); ts=decodeGS(gs,mapping);
  if isKey(cache,char(key))
   stats.candidateGeneratedCount=stats.candidateGeneratedCount+1;
   stats.cacheHitCount=stats.cacheHitCount+1; candidate=cache(char(key)); status="cacheHit"; return;
  end
  candidate=[];
  if stats.uniqueEvaluationCount>=maxUniqueEvaluations
   budgetDenied=budgetDenied+1; status="budgetExhausted"; return;
  end
  if ~allowNew, localDenied=localDenied+1; status="localLimit"; return; end
  % Reserve before invoking user code. Exceptions propagate and are never cached.
  stats.uniqueEvaluationCount=stats.uniqueEvaluationCount+1;
  stats.candidateGeneratedCount=stats.candidateGeneratedCount+1;
  e=evaluator(ts); e=normalize(e);
  assert(isnan(e.CompletedCustomerCount) || e.CompletedCustomerCount<=numel(ts), ...
   'AGV:GAEvaluation','Completed-customer count exceeds task count.');
  candidate=struct('gs',reshape(gs,1,[]),'ts',ts,'key',key,'evaluation',e);
  cache(char(key))=candidate; status="evaluated";
 end
 function value=snapshot()
  value=stats;
 end
 function value=budgetSnapshot()
  value=struct('limit',maxUniqueEvaluations,'remaining',maxUniqueEvaluations-stats.uniqueEvaluationCount, ...
   'budgetDeniedCount',budgetDenied,'localDeniedCount',localDenied);
 end
end
function e=normalize(e)
assert(isstruct(e) && isscalar(e),'AGV:GAEvaluation','Evaluator must return a scalar result struct.');
required={'isFeasible','isDeadlocked','SystemMakespan','CustomerCompletionMakespan', ...
 'TotalMoveCount','totalDistance','RelocationCount','FillingCount','failureReason'};
assert(all(isfield(e,required)),'AGV:GAEvaluation','Evaluator result is missing required metrics.');
for name={'isFeasible','isDeadlocked'}
 value=e.(name{1});
 assert((islogical(value) || isnumeric(value)) && isreal(value) && isscalar(value) && ismember(value,[0 1]),'AGV:GAEvaluation','Invalid boolean flag.');
 e.(name{1})=logical(value);
end
for name=required(3:8)
 value=e.(name{1});
 assert(isnumeric(value) && isreal(value) && isscalar(value),'AGV:GAEvaluation','Metrics must be real numeric scalars.');
 if e.isFeasible
  assert(isfinite(value) && value>=0,'AGV:GAEvaluation','Feasible metrics must be finite and nonnegative.');
 end
end
assert(~e.isFeasible || ~e.isDeadlocked,'AGV:GAEvaluation','A deadlocked result cannot be feasible.');
e.failureReason=string(e.failureReason);
assert(isscalar(e.failureReason) && ~ismissing(e.failureReason),'AGV:GAEvaluation','Invalid failure reason.');
if ~e.isFeasible
 e.SystemMakespan=NaN; e.CustomerCompletionMakespan=NaN;
end
% Only this explicit contract field is used; never infer progress from time/moves.
if ~isfield(e,'CompletedCustomerCount'), e.CompletedCustomerCount=NaN; end
v=e.CompletedCustomerCount;
assert(isnumeric(v) && isreal(v) && isscalar(v) && (isnan(v) || (isfinite(v) && v>=0 && v==fix(v))), ...
 'AGV:GAEvaluation','Invalid completed-customer count.');
end
