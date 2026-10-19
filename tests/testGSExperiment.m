function testGSExperiment()
%TESTGSEXPERIMENT Strict objective ties, deadlocks/cache and output safety.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'algorithms'),fullfile(root,'data'),fullfile(root,'visualization'));
e=struct('isFeasible',true,'isDeadlocked',false,'SystemMakespan',10, ...
 'CustomerCompletionMakespan',9,'TotalMoveCount',2,'totalDistance',20, ...
 'RelocationCount',0,'FillingCount',0,'failureReason',"",'CompletedCustomerCount',2);
a=struct('key',"z",'evaluation',e); b=a; b.key="a";
assert(~gaIsStrictlyBetter(a,b) && ~gaIsStrictlyBetter(b,a));
assert(isequal(gaRankCandidates([a b]),[2 1])); % Sorting remains deterministic.
b.evaluation.TotalMoveCount=1; assert(gaIsStrictlyBetter(b,a));
b.evaluation=e; b.evaluation.totalDistance=19; assert(gaIsStrictlyBetter(b,a));
a.evaluation.isFeasible=false; a.evaluation.isDeadlocked=true;
a.evaluation.SystemMakespan=NaN;
assert(gaIsStrictlyBetter(b,a) && ~gaIsStrictlyBetter(a,b));
b.evaluation=a.evaluation; assert(~gaIsStrictlyBetter(b,a));
b.evaluation.CompletedCustomerCount=1; assert(gaIsStrictlyBetter(a,b));
% A returned deadlock is cached as failure with NaN makespan, never a penalty score.
lanes=table(["A";"B"],["A";"B"],[0;0],[901;902],["Slot";"Slot"], ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
tasks=table([1;2],["x";"y"],[901;902],'VariableNames',{'TaskID','CargoID','DropoffStation'});
m=buildGSMapping(tasks,lanes); deadlock=a.evaluation; deadlock.SystemMakespan=1e12;
deadlock.failureReason="mock deadlock";
[evaluate,stats]=gaCreateEvaluator(m,@(~)deadlock,1);
first=evaluate(["A" "B"]); second=evaluate(["A" "B"]);
assert(isequaln(first,second) && ~first.evaluation.isFeasible && first.evaluation.isDeadlocked);
assert(isnan(first.evaluation.SystemMakespan) && first.evaluation.failureReason=="mock deadlock");
assert(stats().uniqueEvaluationCount==1 && stats().cacheHitCount==1);
% A lexically smaller GS with tied metrics must not end first-improvement LS.
[evaluate,getStats]=gaCreateEvaluator(m,@(~)e,3);
start=evaluate(["B" "A"]);
[selected,local]=gaFirstImprovement(start,m,evaluate,getStats,3);
assert(~local.improved && selected.key==start.key && local.newEvaluationCount==1);
% Existing output paths must be rejected before any files are written.
rejected=false;
try
 exportGSMemeticExperiment(struct(),root);
catch err
 assert(strcmp(err.identifier,'AGV:ExperimentOutput')); rejected=true;
end
assert(rejected,'TEST:Expected','Existing output directory was not rejected.');
% Isolated synthetic export tests output wiring without running an optimizer.
cfg=struct('enableAnimation',false,'enableAnimationGIF',false,'enablePlots',false);
result=struct('isFeasible',false,'taskTable',table(1,'VariableNames',{'Fixture'}));
best=struct('gs',["A" "B"],'ts',[1 2]);
h=struct('generation',0,'globalBestSystemMakespan',NaN,'stats',stats());
fixture=struct('cfg',cfg,'comparison',table("fixture",'VariableNames',{'Algorithm'}), ...
 'search',struct('best',best,'history',h),'resultFCFS',result,'bestResult',result);
folder=tempname(fullfile(root,'results')); cleanup=onCleanup(@()removeFixture(folder)); %#ok<NASGU>
exportGSMemeticExperiment(fixture,folder);
for name={'comparison.csv','convergence.csv','best_gs.csv','best_ts.csv','fcfs_tasks.csv','gs_memetic_tasks.csv','experiment.mat'}
 assert(isfile(fullfile(folder,name{1})));
end
assert(isempty(dir(fullfile(folder,'*.html'))) && isempty(dir(fullfile(folder,'*.gif'))));
fprintf('GS experiment unit tests passed (objective ties, deadlocks/cache, isolated export safety).\n');
end
function removeFixture(folder)
if isfolder(folder), rmdir(folder,'s'); end
end
