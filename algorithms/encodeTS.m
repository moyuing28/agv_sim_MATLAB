function gs = encodeTS(ts,mapping)
%ENCODETS Encode a complete precedence-feasible task ROW permutation.
assert(isnumeric(ts) && isreal(ts) && (isvector(ts) || isempty(ts)), 'AGV:TS','TS must be a numeric vector.');
ts=reshape(ts,1,[]); n=numel(mapping.taskRows);
assert(numel(ts)==n && isequal(sort(double(ts)),1:n),'AGV:TS','TS must contain each task row exactly once.');
positions=zeros(1,n); positions(ts)=1:n; edges=mapping.constraints;
assert(all(positions(edges(:,1))<positions(edges(:,2))),'AGV:TS','TS violates static precedence.');
gs=reshape(mapping.taskPocketKey(ts),1,[]);
end
