% Function: loadTaskConfiguration
% Purpose: Read manual cargo/task inputs and derive pickup stations.
% Inputs: See function signature.
% Outputs: See function signature and README.
%
% Notes: Input CSVs are read-only; no automatic obstacle relocation.
function [tasks,cargo] = loadTaskConfiguration(data,cfg)
paths={cfg.cargoFile,cfg.taskFile};
for k=1:2
 assert(isfile(paths{k}),'AGV:MissingFile','Missing input configuration: %s',paths{k});
end
opts=detectImportOptions(paths{1},'TextType','string');
assert(all(ismember({'StationMark','CargoID','PocketName','Sequence'},opts.VariableNames)), 'AGV:CargoColumns','Cargo table requires StationMark,CargoID,PocketName,Sequence.');
opts=setvartype(opts,{'CargoID','PocketName'},'string');
opts=setvartype(opts,{'StationMark','Sequence'},'double');
cargo=readtable(paths{1},opts);
cargo.CargoID=strip(fillmissing(cargo.CargoID,'constant',""));
opts=detectImportOptions(paths{2},'TextType','string','Delimiter',',','VariableNamesLine',1);
opts.DataLines=[2 Inf];
assert(all(ismember({'TaskID','CargoID','DropoffStation','ReleaseTime'},opts.VariableNames)), 'AGV:TaskColumns','Task table requires TaskID,CargoID,DropoffStation,ReleaseTime.');
opts=setvartype(opts,'CargoID','string');
opts=setvartype(opts,{'TaskID','DropoffStation','ReleaseTime'},'double');
tasks=readtable(paths{2},opts);
tasks.CargoID=strip(fillmissing(tasks.CargoID,'constant',""));
validateCargoConfiguration(cargo,tasks,data);
[~,loc]=ismember(tasks.CargoID,cargo.CargoID);
tasks.PickupStation=cargo.StationMark(loc);
tasks.TaskType=repmat("Transport",height(tasks),1);
tasks.Status=repmat("Pending",height(tasks),1);
end
