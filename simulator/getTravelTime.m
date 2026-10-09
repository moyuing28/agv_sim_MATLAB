% Function: getTravelTime
% Purpose: Convert map distance units to travel seconds.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function time = getTravelTime(distance,cfg)
time=distance*cfg.meterPerUnit/cfg.agvSpeed;
end
