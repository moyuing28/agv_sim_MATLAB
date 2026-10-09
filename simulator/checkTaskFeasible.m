% Function: checkTaskFeasible
% Purpose: Check whether every predecessor is complete.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function feasible = checkTaskFeasible(taskIndex,completedTasks,constraints)
pred=constraints(constraints(:,2)==taskIndex,1);
feasible=all(completedTasks(pred));
end
