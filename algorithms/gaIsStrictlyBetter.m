function better = gaIsStrictlyBetter(candidate,reference)
%GAISSTRICTLYBETTER Same objective order, excluding deterministic key ties.
if candidate.key==reference.key, better=false; return; end
% Canonical keys order tied individuals but are not optimization objectives.
candidate.key="same"; reference.key="same";
order=gaRankCandidates([reference candidate]);
better=order(1)==2;
end
