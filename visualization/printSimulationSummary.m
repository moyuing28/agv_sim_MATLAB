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
 fprintf('Exit Distance = %.6f m; Return Home Distance = %.6f m\n',r.ExitDistance*cfg.meterPerUnit,r.ReturnHomeDistance*cfg.meterPerUnit);
 fprintf('Actual dispatch sequence (TaskID): '); fprintf('%g ',tasks.TaskID(r.finalSequence)); fprintf('\n');
 if isfield(r,'taskTable'), disp(r.taskTable); end
 if isfield(r,'TotalMoveCount')
  fprintf('Moves: %d; Relocation: %d; Filling: %d; Customer: %d\n',r.TotalMoveCount,r.RelocationCount,r.FillingCount,r.CustomerMoveCount);
 end
 if isfield(r,'SystemMakespan')
  fprintf('SystemMakespan=%.6f; CustomerCompletionMakespan=%.6f; Finalize=%d\n', ...
   r.SystemMakespan,r.CustomerCompletionMakespan,r.FinalizeCount);
 end
 if ~r.isFeasible, fprintf('Reason: %s\n',r.failureReason); end
end
fprintf('====================================\n');
end
