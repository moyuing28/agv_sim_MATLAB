function [cargoID,station,sequence,hasCargo] = getOuterCargoValues(pocketKey,state,data)
%GETOUTERCARGOVALUES Internal scalar counterpart of the public table wrapper.
% Always queries live occupancy and runs the same frontier/No-hole checks.
[station,sequence,cargoID]=getLaneFrontier(pocketKey,state,data);
hasCargo=sequence~=-1;
if hasCargo
 cargoID=string(cargoID); station=double(station); sequence=double(sequence);
end
end
