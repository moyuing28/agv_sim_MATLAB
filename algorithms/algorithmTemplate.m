% Function: algorithmTemplate
% Purpose: Show the optimization interface using one baseline candidate.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function [bestSequence,bestFitness,history] = algorithmTemplate(tasks,data,cfg)
% Replace candidate generation here with a future optimizer.
bestSequence=fcfsSequence(tasks);
[bestFitness,result]=evaluateSequence(bestSequence,tasks,data,cfg);
if ~isempty(result.prioritySequence), bestSequence=result.prioritySequence; end
history=bestFitness;
end
