% Function: repairSequence
% Purpose: Repair a permutation using stable priority topological sorting.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function repaired = repairSequence(sequence,constraints)
sequence=sequence(:)'; n=numel(sequence);
assert(isequal(sort(sequence),1:n),'AGV:Permutation','Sequence must contain task indices 1:N exactly once.');
assert(size(constraints,2)==2 && all(constraints(:)>=1 & constraints(:)<=n & constraints(:)==fix(constraints(:))),'AGV:Constraints','Invalid constraint indices.');
repaired=zeros(1,n); completed=false(1,n);
for k=1:n
 chosen=0;
 for t=sequence
  if ~completed(t) && checkTaskFeasible(t,completed,constraints), chosen=t; break; end
 end
 assert(chosen~=0,'AGV:Cycle','Precedence constraints contain a cycle.');
 repaired(k)=chosen; completed(chosen)=true;
end
end
