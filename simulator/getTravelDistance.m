% Function: getTravelDistance
% Purpose: Look up one directed distance using StationMark mapping.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function distance = getTravelDistance(fromStation,toStation,data)
assert(isKey(data.stationToIndex,fromStation) && isKey(data.stationToIndex,toStation),'AGV:UnknownStation','Unknown route endpoint.');
distance=data.distanceMatrix(data.stationToIndex(fromStation),data.stationToIndex(toStation));
end
