function mapping = buildGSMapping(tasks,lanes,businessEdges)
%BUILDGSMAPPING Build immutable row-index/lane lists from actual targets.
% Optional businessEdges has the same meaning as buildTargetConstraints.
if nargin<3, businessEdges=zeros(0,2); end
slots=lanes(lanes.StationType=="Slot",:);
[present,loc]=ismember(tasks.DropoffStation,slots.StationMark);
assert(all(present),'AGV:GSMapping','Every target must identify a Slot.');
assert(numel(unique(slots.StationMark))==height(slots),'AGV:GSMapping','Slot membership must be unique.');
keys=string(slots.PocketKey(loc)); depth=slots.Sequence(loc);
assert(all(~ismissing(keys) & strlength(strip(keys))>0) && all(isfinite(depth)), ...
 'AGV:GSMapping','Targets require a nonempty PocketKey and finite Sequence.');
mapping.taskRows=(1:height(tasks))';
mapping.taskPocketKey=keys(:); mapping.targetSequence=depth(:);
mapping.labels=unique(keys(:));
mapping.laneTasks=cell(numel(mapping.labels),1);
mapping.counts=zeros(numel(mapping.labels),1);
for k=1:numel(mapping.labels)
 rows=find(keys==mapping.labels(k));
 assert(numel(unique(depth(rows)))==numel(rows),'AGV:GSMapping','Target Sequence ties within a PocketKey are ambiguous.');
 [~,order]=sort(depth(rows),'ascend');
 mapping.laneTasks{k}=rows(order)'; mapping.counts(k)=numel(rows);
end
mapping.constraints=buildTargetConstraints(tasks,lanes,businessEdges);
end
