function [child,accepted] = gaCrossover(parentA,parentB,mapping,cuts)
%GACROSSOVER Preserve A segment; fill outside left-to-right from B quotas.
parentA=validateGS(parentA,mapping); parentB=validateGS(parentB,mapping);
n=numel(parentA);
assert(isnumeric(cuts) && numel(cuts)==2 && all(isfinite(cuts)) && ...
 all(cuts==fix(cuts)) && all(cuts>=1 & cuts<=n) && cuts(1)~=cuts(2), ...
 'AGV:GACrossover','Two distinct valid cut positions required.');
cuts=sort(cuts); segment=cuts(1):cuts(2); child=strings(1,n);
child(segment)=parentA(segment); remaining=mapping.counts;
[~,segmentLabels]=ismember(parentA(segment),mapping.labels);
for k=segmentLabels, remaining(k)=remaining(k)-1; end
outside=setdiff(1:n,segment,'stable'); next=1;
[~,labelsB]=ismember(parentB,mapping.labels);
for k=1:n
 label=labelsB(k);
 if remaining(label)>0
  child(outside(next))=parentB(k); next=next+1; remaining(label)=remaining(label)-1;
 end
end
assert(all(remaining==0) && next==numel(outside)+1,'AGV:GACrossover','Label quota invariant failed.');
accepted=true;
try
 child=validateGS(child,mapping);
catch err
 if ~strcmp(err.identifier,'AGV:TS'), rethrow(err); end
 child=parentA; accepted=false; % Reject cross-lane business precedence violation.
end
end
