% Function: fcfsSequence
% Purpose: Return task input order.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function sequence = fcfsSequence(tasks)
sequence=1:height(tasks); % FCFS uses input row order, independent of TaskID.
end
