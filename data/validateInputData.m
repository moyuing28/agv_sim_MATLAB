% Function: validateInputData
% Purpose: Validate memberships, directed distances, lane positions and task routes.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function report = validateInputData(data,tasks,cfg)
s=data.stations; L=data.lanes; D=data.distanceMatrix;
% Export has one row per station/pocket membership, so repeated marks are valid.
key=string(s.StationMark)+"|"+string(s.PocketKey);
assert(numel(unique(key))==height(s),'AGV:DuplicateMembership','Duplicate station/pocket membership.');
marks=data.stationMarks; n=numel(marks);
assert(isequal(size(D),[n n]),'AGV:MatrixSize','Incorrect distance matrix size.');
assert(all(diag(D)==0),'AGV:Diagonal','Self distances must be zero.');
assert(all(isnan(D(:)) | (isfinite(D(:)) & D(:)>=0)),'AGV:DistanceValue','Distances must be nonnegative finite values or NaN.');
assert(all(ismember(L.StationMark,marks)),'AGV:LaneStation','Unknown lane station.');
assert(all(isfinite(L.Sequence) & L.Sequence>=0 & L.Sequence==fix(L.Sequence)),'AGV:LaneSequence','Invalid lane sequence.');
key=string(L.PocketKey)+"|"+string(L.Sequence);
assert(numel(unique(key))==height(L),'AGV:DuplicateLaneSequence','Duplicate sequence in a pocket.');
report.uniqueStations=n; report.stationRows=height(s); report.pockets=numel(unique(L.PocketKey));
report.nanCount=sum(isnan(D(:))); report.isolatedStations=marks(sum(isfinite(D),2)==1 & sum(isfinite(D),1)'==1);
if nargin>=3
 assert(numel(cfg.agvIDs)==cfg.numAGV && numel(unique(cfg.agvIDs))==cfg.numAGV && all(isfinite(cfg.agvIDs) & cfg.agvIDs>=0 & cfg.agvIDs==fix(cfg.agvIDs)),'AGV:Config','AGV IDs must be unique nonnegative integers, one per AGV.');
 assert(cfg.numAGV>=1 && cfg.numAGV==fix(cfg.numAGV) && numel(cfg.agvInitialStations)==cfg.numAGV,'AGV:Config','Invalid AGV configuration.');
 assert(all(ismember(cfg.agvInitialStations,marks)),'AGV:InitialStation','Unknown initial station.');
 assert(cfg.agvSpeed>0 && isfinite(cfg.agvSpeed) && cfg.meterPerUnit>0 && isfinite(cfg.meterPerUnit) && cfg.pickTime>=0 && isfinite(cfg.pickTime) && cfg.dropTime>=0 && isfinite(cfg.dropTime) && cfg.invalidCost>0 && isfinite(cfg.invalidCost),'AGV:Config','Invalid time, speed, scale or penalty.');
end
if nargin>=2 && ~isempty(tasks)
 assert(numel(unique(tasks.TaskID))==height(tasks),'AGV:TaskID','Task IDs must be unique.');
 assert(all(ismember(tasks.PickupStation,marks)) && all(ismember(tasks.DropoffStation,marks)),'AGV:TaskStation','Unknown task station.');
 assert(all(isfinite(tasks.ReleaseTime) & tasks.ReleaseTime>=0),'AGV:ReleaseTime','Invalid release time.');
 slots=L.StationMark(L.StationType=="Slot");
 assert(all(ismember(tasks.PickupStation,slots)),'AGV:PickupType','Pickup must be a Slot.');
 assert(all(ismember(tasks.DropoffStation,slots)),'AGV:DropoffType','Dropoff must be a Slot; Entrance/Unknown cannot store cargo.');
 assert(isfield(data,'cargoInitial'),'AGV:CargoConfiguration','Missing cargo initial configuration.');
 validateCargoConfiguration(data.cargoInitial,tasks,data);
 for k=1:height(tasks)
  assert(isfinite(getTravelDistance(tasks.PickupStation(k),tasks.DropoffStation(k),data)),'AGV:UnreachableTask','Task %g loaded route is unreachable.',tasks.TaskID(k));
 end
 repairSequence(1:height(tasks),buildLaneConstraints(tasks,L));
end
end
