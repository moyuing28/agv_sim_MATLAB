function better = gaIsStrictlyBetter(candidate,reference)
%GAISSTRICTLYBETTER Reuse the stage-2 total order, including canonical ties.
if candidate.key==reference.key, better=false; return; end
order=gaRankCandidates([reference candidate]);
better=order(1)==2;
end
