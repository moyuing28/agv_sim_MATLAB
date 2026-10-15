function constraints = buildTargetConstraints(tasks,lanes,businessEdges)
%BUILDTARGETCONSTRAINTS Final-placement edges, deep to shallow per PocketKey.
% Output and optional businessEdges use task ROW indices, never TaskID.
% No source station, current cargo position or occupancy is consulted.
if nargin<3, businessEdges=zeros(0,2); end
n=height(tasks); constraints=zeros(0,2);
for station=unique(tasks.DropoffStation)'
 rows=find(tasks.DropoffStation==station);
 if numel(rows)>1
  details="TaskID="+string(tasks.TaskID(rows))+" CargoID="+tasks.CargoID(rows);
  error('AGV:DuplicateCustomerTarget','TargetStation %g is shared by Customer Tasks: %s.',station,char(join(details,'; ')));
 end
end
slots=lanes(lanes.StationType=="Slot",:);
[present,loc]=ismember(tasks.DropoffStation,slots.StationMark);
assert(all(present),'AGV:DropoffType','Every Customer Target must be a Slot.');
assert(numel(unique(slots.StationMark))==height(slots),'AGV:SlotState','Each Slot must have one real Lane membership.');
keys=slots.PocketKey(loc); depth=slots.Sequence(loc);
for pocket=unique(keys)'
 rows=find(keys==pocket);
 [~,order]=sort(depth(rows),'ascend'); rows=rows(order);
 constraints=[constraints;rows(1:end-1),rows(2:end)]; %#ok<AGROW>
end
% Extension point only: no new business input/configuration system.
assert(size(businessEdges,2)==2 && all(isfinite(businessEdges(:)) & businessEdges(:)>=1 & businessEdges(:)<=n & businessEdges(:)==fix(businessEdges(:))), ...
 'AGV:Constraints','Business precedence must contain valid task row index pairs.');
constraints=unique([constraints;businessEdges],'rows');
validateTaskPrecedence(constraints,tasks);
end