% Function: validateCargoConfiguration
% Purpose: Validate all Slot inventory and unique cargo transport requests.
% Inputs: See function signature.
% Outputs: See function signature and README.
%
% Notes: Input CSVs are read-only; no automatic obstacle relocation.
function validateCargoConfiguration(cargo,tasks,data)
required={'StationMark','CargoID','PocketName','Sequence'};
assert(all(ismember(required,cargo.Properties.VariableNames)),'AGV:CargoColumns','Missing cargo configuration columns.');
slots=data.lanes(data.lanes.StationType=="Slot",:);
marks=unique(slots.StationMark);
assert(height(cargo)==numel(marks) && numel(unique(cargo.StationMark))==height(cargo) && all(ismember(cargo.StationMark,marks)), 'AGV:CargoSlots','Cargo table must contain each Slot exactly once; Entrance/Unknown cannot store cargo.');
assert(all(~ismissing(cargo.CargoID)),'AGV:CargoID','Normalize empty cargo cells to empty strings.');
occupied=cargo.CargoID~="";
assert(~any(cargo.CargoID=="空"),'AGV:CargoID','Leave empty slots blank; do not use the literal cargo name 空.');
assert(numel(unique(cargo.CargoID(occupied)))==sum(occupied),'AGV:DuplicateCargo','Each CargoID must identify exactly one cargo at one Slot.');
for k=1:height(cargo)
 rows=slots(slots.StationMark==cargo.StationMark(k),:);
 assert(any(rows.PocketName==cargo.PocketName(k) & rows.Sequence==cargo.Sequence(k)), 'AGV:CargoMetadata','Slot %g PocketName/Sequence does not match lanes.csv.',cargo.StationMark(k));
end
validateNoHoleState(cargo,data.lanes);
assert(all(ismember({'TaskID','CargoID','DropoffStation','ReleaseTime'},tasks.Properties.VariableNames)), 'AGV:TaskColumns','Missing task input columns.');
assert(all(isfinite(tasks.TaskID) & tasks.TaskID==fix(tasks.TaskID)) && numel(unique(tasks.TaskID))==height(tasks),'AGV:TaskID','TaskID must be unique finite integers.');
assert(all(~ismissing(tasks.CargoID) & tasks.CargoID~=""),'AGV:TaskCargo','Every task must name a cargo.');
assert(numel(unique(tasks.CargoID))==height(tasks),'AGV:RepeatedCargoTask','Each cargo may occur only once in this task set.');
[known,loc]=ismember(tasks.CargoID,cargo.CargoID(occupied));
if ~all(known)
 missing=join(tasks.CargoID(~known),', ');
 error('AGV:MissingCargo','Tasks refer to cargo not configured in cargo_initial.csv: %s. Fill its CargoID at the actual Slot.',char(missing));
end
assert(all(ismember(tasks.DropoffStation,marks)),'AGV:DropoffType','Every destination must be a Slot; Entrance/Unknown are not storage locations.');
buildTargetConstraints(tasks,data.lanes); % Static duplicate-target and DAG validation.
assert(all(isfinite(tasks.ReleaseTime) & tasks.ReleaseTime>=0),'AGV:ReleaseTime','ReleaseTime must be nonnegative finite seconds.');
sources=cargo.StationMark(occupied); sources=sources(loc);
assert(all(sources~=tasks.DropoffStation),'AGV:SameStation','Pickup and Dropoff must differ.');
if ismember('PickupStation',tasks.Properties.VariableNames)
 assert(all(tasks.PickupStation==sources),'AGV:CargoPosition','Task pickup must match its cargo initial Slot.');
end
end
