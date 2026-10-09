% Function: evaluateSequence
% Purpose: Expose makespan fitness and optional detailed result.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function [fitness,result] = evaluateSequence(sequence,tasks,data,cfg)
result=simulateSchedule(sequence,tasks,data,cfg);
fitness=result.makespan;
end
