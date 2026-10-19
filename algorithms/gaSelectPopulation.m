function [selected,info] = gaSelectPopulation(candidates,count,minDistance)
%GASELECTPOPULATION Ranked elite, deterministic Hamming-distance gate, refill.
assert(isscalar(minDistance) && isfinite(minDistance) && minDistance>=0 && minDistance<=1,'AGV:GADiversity','Invalid normalized distance.');
order=gaRankCandidates(candidates); candidates=candidates(order);
[~,uniqueRows]=unique(string({candidates.key}),'stable'); candidates=candidates(uniqueRows);
assert(numel(candidates)>=count,'AGV:GAPopulation','Not enough distinct GS to fill next population.');
chosen=1; % The best individual is mandatory, even when diversity rejects others.
for k=2:numel(candidates)
 if numel(chosen)==count, break; end
 separated=true;
 for j=chosen
  a=candidates(k).gs; b=candidates(j).gs;
  d=sum(a~=b)/max(1,numel(a));
  if d<minDistance, separated=false; break; end
 end
 if separated, chosen(end+1)=k; end %#ok<AGROW>
 if numel(chosen)==count, break; end
end
% count=1 needs no diversity scan.
if count==1, chosen=1; end
diversityCount=min(numel(chosen),count); chosen=chosen(1:diversityCount);
for k=1:numel(candidates)
 if numel(chosen)==count, break; end
 if ~ismember(k,chosen), chosen(end+1)=k; end %#ok<AGROW>
end
selected=candidates(chosen); selected=selected(gaRankCandidates(selected));
info=struct('uniqueMergedCount',numel(candidates),'diversitySelectedCount',diversityCount, ...
 'refillCount',count-diversityCount);
end
