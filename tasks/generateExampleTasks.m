% Function: generateExampleTasks
% Purpose: Generate reachable test tasks from actual Slot memberships.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function tasks = generateExampleTasks(data,cfg)
slots=data.lanes(data.lanes.StationType=="Slot",:);
[~,idx]=unique(slots.StationMark,'stable'); slots=slots(idx,:);
valid=false(height(slots),1);
for k=1:height(slots)
 s=slots.StationMark(k);
 valid(k)=s~=5 && isfinite(getTravelDistance(cfg.exampleDropoffStation,s,data)) && isfinite(getTravelDistance(s,cfg.exampleDropoffStation,data)) && all(arrayfun(@(a)isfinite(getTravelDistance(a,s,data)),cfg.agvInitialStations));
end
slots=slots(valid,:); n=cfg.exampleTaskCount;
assert(n>=10 && n<=20 && height(slots)>=n,'AGV:ExampleTasks','Need 10-20 reachable Slot tasks.');
slots=slots(1:n,:);
assert(any(histcounts(categorical(slots.PocketKey))>=2),'AGV:ExampleLane','Example must include two pickups in one pocket.');
tasks=table((1:n)',slots.StationMark,repmat(cfg.exampleDropoffStation,n,1),zeros(n,1),slots.PocketKey,slots.Sequence,repmat("Pending",n,1),'VariableNames',{'TaskID','PickupStation','DropoffStation','ReleaseTime','Lane','Sequence','Status'});
writetable(tasks,fullfile(cfg.projectRoot,'tasks','tasks_example.csv'));
end
