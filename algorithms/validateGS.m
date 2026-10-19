function [gs,ts] = validateGS(gs,mapping)
%VALIDATEGS Validate multiplicities and all precedence; return normalized GS/TS.
assert(isstring(gs) && (isvector(gs) || isempty(gs)), 'AGV:GS','GS must be a string vector.');
gs=reshape(gs,1,[]);
assert(numel(gs)==numel(mapping.taskRows) && all(~ismissing(gs)), 'AGV:GS','Invalid GS length or missing label.');
[known,idx]=ismember(gs,mapping.labels);
assert(all(known),'AGV:GS','Unknown PocketKey in GS.');
counts=zeros(numel(mapping.labels),1);
if ~isempty(idx), counts=accumarray(idx(:),ones(numel(idx),1),size(counts)); end
assert(isequal(counts,mapping.counts),'AGV:GS','Incorrect PocketKey multiplicities.');
ts=zeros(1,numel(gs)); used=zeros(size(mapping.counts));
for k=1:numel(gs)
 lane=idx(k); used(lane)=used(lane)+1;
 ts(k)=mapping.laneTasks{lane}(used(lane));
end
encodeTS(ts,mapping);
end
