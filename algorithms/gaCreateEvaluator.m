function [evaluate,getStats] = gaCreateEvaluator(mapping,evaluator)
%GACREATEEVALUATOR New in-memory cache per run; evaluator takes decoded TS.
assert(isa(evaluator,'function_handle'),'AGV:GAEvaluator','Evaluator must be a function handle.');
cache=containers.Map('KeyType','char','ValueType','any');
stats=struct('candidateGeneratedCount',0,'uniqueEvaluationCount',0,'cacheHitCount',0);
evaluate=@lookup; getStats=@snapshot;
 function candidate=lookup(gs)
  key=gsCanonicalString(gs,mapping); ts=decodeGS(gs,mapping);
  stats.candidateGeneratedCount=stats.candidateGeneratedCount+1;
  if isKey(cache,char(key))
   stats.cacheHitCount=stats.cacheHitCount+1; candidate=cache(char(key)); return;
  end
  e=evaluator(ts); e=normalize(e);
  assert(isnan(e.CompletedCustomerCount) || e.CompletedCustomerCount<=numel(ts), ...
   'AGV:GAEvaluation','Completed-customer count exceeds task count.');
  candidate=struct('gs',reshape(gs,1,[]),'ts',ts,'key',key,'evaluation',e);
  cache(char(key))=candidate; stats.uniqueEvaluationCount=stats.uniqueEvaluationCount+1;
 end
 function value=snapshot()
  value=stats;
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
