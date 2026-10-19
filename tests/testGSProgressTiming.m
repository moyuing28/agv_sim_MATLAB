function testGSProgressTiming()
%TESTGSPROGRESSTIMING Fake evaluations only; no optimizer/simulator/export call.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'algorithms'),fullfile(root,'visualization'));
lanes=table(["A";"B";"C"],["A";"B";"C"],zeros(3,1),(901:903)',repmat("Slot",3,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
tasks=table((1:3)',["x";"y";"z"],lanes.StationMark,'VariableNames',{'TaskID','CargoID','DropoffStation'});
m=buildGSMapping(tasks,lanes); options=gaOptions(struct('maxUniqueEvaluations',3)); state=rng;
events={}; calls=0;
[evaluate,getStats,getBudget,getTiming]=gaCreateEvaluator(m,@fake,3,@collect);
first=evaluate(["A" "B" "C"]);
assert(calls==1 && numel(events)==2 && events{1}.type=="evaluationStart" && events{2}.type=="evaluationComplete");
assert(events{1}.evaluationNumber==1 && events{1}.timing.completedEvaluationCount==0);
assert(events{2}.timing.completedEvaluationCount==1 && events{2}.candidateIsFeasible);
assert(isnan(events{2}.timing.estimatedRemainingSeconds));
duplicate=evaluate(first.gs);
assert(isequaln(first,duplicate) && calls==1 && numel(events)==2 && getStats().cacheHitCount==1);
failedSchedule=evaluate(["B" "A" "C"]);
assert(~failedSchedule.evaluation.isFeasible && failedSchedule.evaluation.isDeadlocked);
assert(events{3}.stats.cacheHitCount==1 && events{3}.timing.completedEvaluationCount==1);
assert(events{4}.globalBestSystemMakespan==first.evaluation.SystemMakespan);
t=events{4}.timing;
assert(t.meanEvaluationSeconds==sum(t.evaluationSeconds)/2 && t.estimatedRemainingSeconds==t.meanEvaluationSeconds);
best=evaluate(["C" "A" "B"]);
assert(events{6}.globalBestSystemMakespan==best.evaluation.SystemMakespan && events{6}.globalBestIsFeasible);
assert(calls==3 && getTiming().completedEvaluationCount==3 && getTiming().estimatedRemainingSeconds==0);
[none,status]=evaluate(["A" "C" "B"]);
assert(isempty(none) && status=="budgetExhausted" && calls==3 && numel(events)==6);
evaluate(best.gs); assert(numel(events)==6 && getStats().cacheHitCount==2 && getBudget().remaining==0);
for k=1:numel(events)
 assert(events{k}.timing.searchElapsedSeconds>=0);
 if k>1, assert(events{k}.timing.searchElapsedSeconds>=events{k-1}.timing.searchElapsedSeconds); end
end
% Formatting uses completed rather than reserved count, and labels ETA as estimate.
event=events{1}; event.generation=0;
text=evalc('printGSMemeticProgress(event,options)');
assert(contains(text,'Evaluating 1/3') && contains(text,'completed=0/3') && contains(text,'estimating'));
event=events{4}; event.generation=0;
text=evalc('printGSMemeticProgress(event,options)');
assert(contains(text,'Evaluated 2/3') && contains(text,'candidate feasible=0') && contains(text,'remaining (estimate)'));
row=struct('type',"generation",'generation',1,'stats',getStats(), ...
 'globalBestSystemMakespan',best.evaluation.SystemMakespan,'globalBestIsFeasible',true,'timing',getTiming());
text=evalc('printGSMemeticProgress(row,options)');
assert(contains(text,'generation=1') && contains(text,'cache hits=2') && contains(text,'mean='));
stage=struct('type',"stageStart",'stage',"FCFS",'elapsedSeconds',0);
text=evalc('printGSMemeticProgress(stage,options)'); assert(contains(text,'outside GS evaluation budget'));
stage.type="stageComplete"; stage.elapsedSeconds=1.25; stage.SystemMakespan=42; stage.isFeasible=true;
text=evalc('printGSMemeticProgress(stage,options)'); assert(contains(text,'1.250 s') && contains(text,'42.000000 s'));
% Optional observers/timers cannot alter cached candidate values or old stats schema.
[silent,silentStats]=gaCreateEvaluator(m,@metrics,3);
assert(isequaln(silent(first.gs),first)); silent(first.gs);
assert(isequal(silentStats(),struct('candidateGeneratedCount',2,'uniqueEvaluationCount',1,'cacheHitCount',1)));
% A thrown MATLAB exception is an error event, never a normal failed schedule.
errors={}; [crash,crashStats,~,crashTiming]=gaCreateEvaluator(m,@explode,1,@collectError);
try
 crash(first.gs); error('TEST:Expected','Exception was swallowed.');
catch err
 assert(strcmp(err.identifier,'TEST:EvaluationFailure'));
end
assert(numel(errors)==2 && errors{2}.type=="evaluationError" && errors{2}.errorIdentifier=="TEST:EvaluationFailure");
assert(errors{2}.evaluationSeconds>=0 && strlength(errors{2}.errorReport)>0);
assert(crashTiming().completedEvaluationCount==0 && crashStats().uniqueEvaluationCount==1);
event=errors{2}; event.generation=0;
text=evalc('printGSMemeticProgress(event,options)');
assert(contains(text,'FAILED after') && contains(text,'TEST:EvaluationFailure'));
% Even a broken error-reporting observer cannot replace the evaluator exception.
[broken,~]=gaCreateEvaluator(m,@explode,1,@brokenObserver);
try
 broken(first.gs); error('TEST:Expected','Exception was swallowed.');
catch err
 assert(strcmp(err.identifier,'TEST:EvaluationFailure'));
end
assert(isequal(rng,state));
fprintf('Progress/timing tests passed: initialization events, cache silence, completed counts, mean/ETA, best metrics, stages, original exception, unchanged budget/RNG.\n');
 function e=fake(ts)
  assert(events{end}.type=="evaluationStart"); calls=calls+1; e=metrics(ts);
 end
 function collect(event)
  events{end+1}=event;
 end
 function collectError(event)
  errors{end+1}=event;
 end
 function brokenObserver(event)
  if event.type=="evaluationError", error('TEST:ObserverFailure','Injected observer failure.'); end
 end
end
function e=metrics(ts)
score=sum(ts.*(1:numel(ts))); feasible=ts(1)~=2;
e=struct('isFeasible',feasible,'isDeadlocked',~feasible,'SystemMakespan',score, ...
 'CustomerCompletionMakespan',score,'TotalMoveCount',3,'totalDistance',20, ...
 'RelocationCount',0,'FillingCount',0,'failureReason',"fake only",'CompletedCustomerCount',3*feasible);
end
function e=explode(~) %#ok<STOUT>
error('TEST:EvaluationFailure','Injected test exception; no simulator invoked.');
end
