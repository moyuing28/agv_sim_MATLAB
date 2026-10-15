function validateTaskPrecedence(edges,tasks)
%VALIDATETASKPRECEDENCE Validate row-index edges and report actual cycle tasks.
n=height(tasks);
assert(size(edges,2)==2 && all(isfinite(edges(:)) & edges(:)>=1 & edges(:)<=n & edges(:)==fix(edges(:))), ...
 'AGV:Constraints','Precedence must contain valid task row index pairs.');
if isempty(edges), return; end
G=digraph(edges(:,1),edges(:,2),[],n);
groups=conncomp(G,'Type','strong'); counts=accumarray(groups(:),1);
cyclic=counts(groups(:))>1;
self=edges(edges(:,1)==edges(:,2),1); cyclic(self)=true;
if any(cyclic)
 details="TaskID="+string(tasks.TaskID(cyclic))+" CargoID="+tasks.CargoID(cyclic);
 error('AGV:CyclicTaskPrecedence','Cyclic Customer Task precedence involves: %s.',char(join(details,'; ')));
end
end