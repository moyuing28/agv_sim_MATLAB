function [child,accepted] = gaSwapMutation(parent,mapping,positions)
%GASWAPMUTATION Swap distinct positions; reject static precedence violations.
parent=validateGS(parent,mapping); n=numel(parent);
assert(isnumeric(positions) && numel(positions)==2 && all(isfinite(positions)) && ...
 all(positions==fix(positions)) && all(positions>=1 & positions<=n) && positions(1)~=positions(2), ...
 'AGV:GAMutation','Two distinct valid swap positions required.');
child=parent; child(positions)=child(fliplr(reshape(positions,1,[]))); accepted=true;
try
 child=validateGS(child,mapping);
catch err
 if ~strcmp(err.identifier,'AGV:TS'), rethrow(err); end
 child=parent; accepted=false;
end
end
