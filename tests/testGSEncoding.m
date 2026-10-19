function testGSEncoding()
%TESTGSENCODING Independent, data-driven encoding tests; no simulation changes.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'data'),fullfile(root,'tasks'),fullfile(root,'algorithms'));
cfg=config(); data=loadSimulationData(cfg); [tasks,~]=loadTaskConfiguration(data,cfg);
m=buildGSMapping(tasks,data.lanes);
assert(numel(m.taskRows)==height(tasks));
slots=data.lanes(data.lanes.StationType=="Slot",:);
[~,loc]=ismember(tasks.DropoffStation,slots.StationMark);
assert(isequal(m.taskPocketKey,slots.PocketKey(loc)));
assert(isequal(m.constraints,buildTargetConstraints(tasks,data.lanes)));
for k=1:numel(m.labels)
 rows=find(slots.PocketKey(loc)==m.labels(k));
 [~,order]=sort(slots.Sequence(loc(rows)),'ascend');
 assert(isequal(m.laneTasks{k},rows(order)'));
 assert(m.counts(k)==numel(rows));
end
% Snapshot checks supplement (rather than replace) the dynamic checks above.
assert(height(tasks)==10 && numel(m.labels)==9);
assert(isequal(reshape(tasks.TaskID(m.constraints),size(m.constraints)),[2 10]));
numberOfGS=factorial(height(tasks))/prod(factorial(m.counts));
assert(numberOfGS==factorial(height(tasks))/2);
fprintf('demo50: %d tasks, %d labels, %.0f lane-valid permutations.\n',height(tasks),numel(m.labels),numberOfGS);
disp(table(m.taskRows,tasks.TaskID,m.taskPocketKey,m.targetSequence, ...
 'VariableNames',{'TaskRow','TaskID','PocketKey','TargetSequence'}));
disp(m.constraints);
% Interleave lists deterministically in several orders; preserve RNG state.
state=rng; cleanup=onCleanup(@()rng(state)); rng(17,'twister'); %#ok<NASGU>
for k=1:30
 gs=m.taskPocketKey(randperm(height(tasks)))';
 ts=decodeGS(gs,m);
 assert(isequal(sort(ts),1:height(tasks)));
 assert(isequal(decodeGS(encodeTS(ts,m),m),ts));
 assert(isequal(encodeTS(ts,m),gs));
 assert(gsCanonicalString(gs,m)==gsCanonicalString(gs,m));
end
gs=encodeTS(decodeGS(m.taskPocketKey',m),m);
bad=gs; bad(1)="unknown"; rejected(@()decodeGS(bad,m));
bad=gs; bad(1)=m.labels(find(m.labels~=gs(1),1)); rejected(@()decodeGS(bad,m));
rejected(@()decodeGS(gs(1:end-1),m));
rejected(@()decodeGS(double(1:height(tasks)),m));
ts=decodeGS(gs,m); bad=ts; bad(1)=bad(2); rejected(@()encodeTS(bad,m));
rejected(@()encodeTS(ts(1:end-1),m));
bad=ts; bad(1)=height(tasks)+1; rejected(@()encodeTS(bad,m));
bad=ts; a=find(bad==m.constraints(1,1)); b=find(bad==m.constraints(1,2));
bad([a b])=bad([b a]); rejected(@()encodeTS(bad,m));
% Exhaust a small multiset with multi-digit and delimiter-containing labels.
small=tasks(1:3,:); lane=slots(1:3,:); lane.StationMark=(901:903)';
lane.PocketKey=["1";"12";"1"]; lane.Sequence=[0;0;1];
small.DropoffStation=lane.StationMark; sm=buildGSMapping(small,lane);
orders=unique(perms([1 1 2]),'rows'); keys=strings(size(orders,1),1);
for k=1:size(orders,1)
 s=sm.labels(orders(k,:))'; keys(k)=gsCanonicalString(s,sm);
 assert(isequal(encodeTS(decodeGS(s,sm),sm),s));
end
assert(numel(unique(keys))==factorial(3)/prod(factorial(sm.counts)));
business=buildGSMapping(small,lane,[2 1]);
rejected(@()validateGS(["1" "12" "1"],business));
assert(isequal(decodeGS(["12" "1" "1"],business),[2 1 3]));
lane.PocketKey=["a|b";"a";"a|b"]; sm=buildGSMapping(small,lane);
assert(gsCanonicalString(["a" "a|b" "a|b"],sm)~=gsCanonicalString(["a|b" "a" "a|b"],sm));
badLane=lane; badLane.Sequence(3)=0; rejected(@()buildGSMapping(small,badLane));
badTasks=small; badTasks.DropoffStation(1)=-1; rejected(@()buildGSMapping(badTasks,lane));
badLane=lane; badLane.PocketKey(1)=missing; rejected(@()buildGSMapping(small,badLane));
empty=buildGSMapping(tasks([],:),data.lanes);
assert(isempty(decodeGS(strings(1,0),empty)) && isempty(encodeTS([],empty)));
fprintf('All GS encoding tests passed (round trips, invalid inputs, canonical keys).\n');
end
function rejected(action)
try
 action();
catch err
 assert(startsWith(err.identifier,'AGV:'),err.message); return;
end
error('TEST:ExpectedRejection','Expected invalid input rejection.');
end
