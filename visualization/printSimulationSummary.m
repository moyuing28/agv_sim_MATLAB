% Function: printSimulationSummary
% Purpose: Print baseline objectives, execution sequences and allocations.
% Inputs: See function signature (main/config have no inputs).
% Outputs: See function signature and README.
%
% Notes: Directed distances and NaN are preserved; algorithms remain separate.
function printSimulationSummary(results,names,tasks,cfg)
fprintf('========== AGV Simulation ==========\nTasks: %d\nAGVs: %d\n',height(tasks),cfg.numAGV);
for k=1:numel(results)
 r=results{k}; fprintf('\n%s: feasible=%d\nMakespan = %.6f s\nTotal Distance = %.6f m\n',names{k},r.isFeasible,r.makespan,r.totalDistance*cfg.meterPerUnit);
 fprintf('Sequence (TaskID): '); fprintf('%g ',tasks.TaskID(r.finalSequence)); fprintf('\n');
 if r.isFeasible, disp(r.taskTable); else, disp(r.failureReason); end
end
fprintf('====================================\n');
end
