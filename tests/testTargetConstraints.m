function testTargetConstraints()
% Targets in A have sequences 1,3,4; other Lanes have depths 2 and 1.
lanes=table([repmat("A",5,1);repmat("B",2,1);"C"],repmat("SAME",8,1), ...
 [(0:4)';(0:1)';0],[(101:105)';201;202;301],repmat("Slot",8,1), ...
 'VariableNames',{'PocketKey','PocketName','Sequence','StationMark','StationType'});
lanes=lanes([5 2 8 4 6 1 7 3],:); % Do not depend on map row order.
tasks=table([50;30;20],["C5";"C3";"C2"],[105;103;102],[102;104;105], ...
 'VariableNames',{'TaskID','CargoID','PickupStation','DropoffStation'});
% 1: adjacent deep-to-shallow target edges, row indices rather than IDs.
e=buildTargetConstraints(tasks,lanes); assert(isequal(e,[1 2;2 3]));
assert(isequal(buildLaneConstraints(tasks,lanes),e));
% 2: source depth reversed or changed has no effect.
reverse=tasks; reverse.PickupStation=flipud(tasks.PickupStation);
assert(isequal(buildTargetConstraints(reverse,lanes),e));
noSource=removevars(tasks,'PickupStation'); assert(isequal(buildTargetConstraints(noSource,lanes),e));
% 3-4: shared Source Lane, different Target Lanes, no hard edge.
separate=tasks(1:2,:); separate.PickupStation=[105;101]; separate.DropoffStation=[201;301];
assert(isempty(buildTargetConstraints(separate,lanes)));
assert(isempty(buildLaneConstraints(separate,lanes)));
% 5-6: temporary future and ordinary cargo locations cannot affect static edges.
separate.CurrentStation=[201;101]; separate.OrdinaryCargoStation=[102;104];
assert(isempty(buildTargetConstraints(separate,lanes)));
separate.CurrentStation=[301;105]; separate.OrdinaryCargoStation=[201;202];
assert(isempty(buildTargetConstraints(separate,lanes)));
% 7: duplicate targets include TaskID, CargoID and TargetStation in error.
duplicate=tasks(1:2,:); duplicate.DropoffStation(:)=102;
try
 buildTargetConstraints(duplicate,lanes); error('TEST:Expected','Expected duplicate target');
catch err
 assert(strcmp(err.identifier,'AGV:DuplicateCustomerTarget'));
 assert(contains(err.message,'102') && contains(err.message,'50') && contains(err.message,'30') && contains(err.message,'C5') && contains(err.message,'C3'));
end
% 8-9: different depths, same PocketName, grouping only by real PocketKey.
extra=table([60;70;80],["C6";"C7";"C8"],[101;102;103],[202;201;301], ...
 'VariableNames',tasks.Properties.VariableNames);
allTasks=[tasks;extra]; edges=buildTargetConstraints(allTasks,lanes);
assert(isequal(edges,[1 2;2 3;5 4]));
% 10: repair and predecessor feasibility continue to consume unchanged Nx2 edges.
repaired=repairSequence([3 2 1],e); assert(isequal(repaired,[1 2 3]));
assert(~checkTaskFeasible(2,[false false false],e));
assert(checkTaskFeasible(2,[true false false],e));
% 11: a legal priority permutation retains unrelated tasks' relative order.
legal=[6 5 1 2 4 3]; assert(isequal(repairSequence(legal,edges),legal));
% Business extension is explicit row-index edges, never inferred from Source.
assert(isequal(buildTargetConstraints(separate,lanes,[2 1]),[2 1]));
% Uniform DAG validation reports actual cycle tasks, excluding downstream nodes.
try
 buildTargetConstraints(allTasks,lanes,[2 1]); error('TEST:Expected','Expected cycle');
catch err
 assert(strcmp(err.identifier,'AGV:CyclicTaskPrecedence'));
 assert(contains(err.message,'TaskID=50') && contains(err.message,'TaskID=30') && ~contains(err.message,'TaskID=20'));
end
expectCycle(@()validateTaskPrecedence([1 1],tasks));
expectCycle(@()buildLaneConstraints(tasks,lanes,[3 1]));
assert(isequal(size(buildTargetConstraints(tasks([],:),lanes)),[0 2]));
fprintf('All Target precedence tests passed.\n');
end
function expectCycle(action)
try, action(); catch err, assert(strcmp(err.identifier,'AGV:CyclicTaskPrecedence')); return; end
error('Expected AGV:CyclicTaskPrecedence');
end