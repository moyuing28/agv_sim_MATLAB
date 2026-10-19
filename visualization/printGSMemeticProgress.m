function printGSMemeticProgress(row,options)
%PRINTGSMEMETICPROGRESS One formatter for stages, evaluation events and generations.
type="generation"; if isfield(row,'type'), type=row.type; end
if startsWith(type,"stage")
 if type=="stageStart"
  fprintf('[%s] starting (outside GS evaluation budget).\n',row.stage);
 else
  fprintf('[%s] completed | elapsed=%.3f s',row.stage,row.elapsedSeconds);
  if isfield(row,'SystemMakespan'), fprintf(' | SystemMakespan=%.6f s | feasible=%d',row.SystemMakespan,row.isFeasible); end
  fprintf('\n');
 end
 drawnow limitrate; return;
end
if type=="evaluationError"
 fprintf(2,'[GS-Memetic] generation=%d | evaluation %d/%d FAILED after %.3f s | search=%.3f s | %s\n%s\n', ...
  row.generation,row.evaluationNumber,options.maxUniqueEvaluations,row.evaluationSeconds, ...
  row.timing.searchElapsedSeconds,row.errorIdentifier,row.errorReport);
 drawnow limitrate; return;
end
if type=="evaluationStart"
 fprintf('[GS-Memetic] generation=%d | Evaluating %d/%d',row.generation,row.evaluationNumber,options.maxUniqueEvaluations);
elseif type=="evaluationComplete"
 fprintf('[GS-Memetic] generation=%d | Evaluated %d/%d | this=%.3f s | candidate feasible=%d', ...
  row.generation,row.evaluationNumber,options.maxUniqueEvaluations,row.evaluationSeconds,row.candidateIsFeasible);
else
 fprintf('[GS-Memetic] generation=%d | unique=%d/%d',row.generation,row.stats.uniqueEvaluationCount,options.maxUniqueEvaluations);
end
fprintf(' | cache hits=%d | best SystemMakespan=%.6f s | feasible=%d', ...
 row.stats.cacheHitCount,row.globalBestSystemMakespan,row.globalBestIsFeasible);
if isfield(row,'timing')
 t=row.timing;
 fprintf(' | completed=%d/%d | search=%.3f s | mean=%s | remaining (estimate)=%s', ...
  t.completedEvaluationCount,options.maxUniqueEvaluations,t.searchElapsedSeconds, ...
  secondsText(t.meanEvaluationSeconds),secondsText(t.estimatedRemainingSeconds));
end
fprintf('\n');
drawnow limitrate;
end
function value=secondsText(seconds)
if isnan(seconds), value='estimating'; else, value=sprintf('%.3f s',seconds); end
end
