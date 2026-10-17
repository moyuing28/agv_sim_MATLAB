function writeAcceptanceReport4x4(summary,runs,path)
% Human-auditable evidence, including failed cases.
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# Stage 7D: 4 x 4 Runtime Acceptance\n\n');
fprintf(fid,'Synthetic deterministic validation map, not a ProfControl export. Production Runtime and nearest LoadedDistance selectors unchanged. Fixed task row priorities; no algorithm comparison.\n\n');
fprintf(fid,'L1/L2/L3/L4 x=1000/1300/1400/1800; Seq0..3 y=400/300/200/100; entrances y=0. Home 1..4 share (1000,200): equal empty travel and deterministic AGVID tie-breaks. All 576 directed distances are static Manhattan values, diagonal zero. meterPerUnit=0.01, speed=1, pick/drop=5 seconds.\n\n');
mdtable(fid,summary);
for k=1:numel(runs)
 run=runs{k}; r=run.result;
 fprintf(fid,'\n## %s\n\nAGVs: %d; seed: %d; priority: 1:%d; business row-index edges: %s.\n\n',run.name,run.cfg.numAGV,run.cfg.randomSeed,height(run.tasks),mat2str(run.cfg.businessEdges));
 fprintf(fid,'Cargo: `%s`\n\nTasks: `%s`\n\n',run.cfg.cargoFile,run.cfg.taskFile);
 if ~isempty(run.data) && isfield(run.data,'cargoInitial')
  fprintf(fid,'### Initial layout (deep to entrance)\n\n'); layout(fid,run.data.cargoInitial);
 end
 fprintf(fid,'### Customer tasks\n\n'); mdtable(fid,run.tasks);
 if ~isempty(r) && isfield(r,'moveTable')
  fprintf(fid,'### Runtime Move trace\n\n'); mdtable(fid,r.moveTable);
  fprintf(fid,'RelocationKind explains each RELOCATION: SOURCE_CLEARING removes the live source outer cargo; TARGET_CLEARING removes target outer cargo; TERMINAL_PROTECTION protects unfinished deeper customer cargo; SELF_TEMPORARY reconstructs a same-lane target. FILLING supplies the next legal slot using ordinary cargo. CUSTOMER_MOVE physically completes the parent. ParentTaskID means ParentCustomerTaskID, not row index.\n\n');
  fprintf(fid,'### FINALIZE (zero moves)\n\n'); mdtable(fid,r.finalizeLog);
  fprintf(fid,'### Final layout\n\n'); layout(fid,r.finalSlotState);
  fprintf(fid,'### Metrics\n\n'); mdtable(fid,summary(k,:));
  fprintf(fid,'### Event trace\n\n'); mdtable(fid,r.eventLog);
  fprintf(fid,'### Task status after each event\n\n'); mdtable(fid,run.snapshots);
  fprintf(fid,'### Live ReadySet before each dispatch\n\n'); mdtable(fid,run.rebuildEvidence);
  fprintf(fid,'Production ReadySet builds: %d. Audit calls buildReadyActions on replayed live inventory/reservations and compares the complete committed ActionPayload.\n\n',r.ReadySetBuildCount);
  fprintf(fid,'### Final tasks / reservations / lane locks / cargo\n\n');
  mdtable(fid,r.taskTable); mdtable(fid,r.finalSlotState); mdtable(fid,r.finalState.laneLocks); mdtable(fid,r.finalCargoState);
  if isfield(r,'deadlockDiagnostics'), mdtable(fid,removevars(r.deadlockDiagnostics.Tasks,'Assessment')); end
 end
 fprintf(fid,'### Assertion results\n\n'); mdtable(fid,run.checks);
 if strlength(run.exception)>0, fprintf(fid,'```text\n%s\n```\n\n',run.exception); end
 label="FAIL"; if summary.Pass(k), label="PASS"; end
 fprintf(fid,'Result: **%s**. %s\n\n',label,summary.FailureReason(k));
 fprintf(fid,'### Observation / Potential Optimization\n\n');
 if k==7
  fprintf(fid,'Initial Target and Source builders both prefer L3. Target wins normalization. After its reservation commits, Source rebuilds and selects L4. Current conservative reservation/baseline behavior; no global optimality claim.\n\n');
 else
  fprintf(fid,'No obviously redundant physical move identified in this fixed trace. No optimality claim: nearest loaded-distance ignores future travel and cooperation.\n\n');
 end
end
fprintf(fid,'## Reproduction\n\nFrom project root: `addpath(''acceptance/4x4''); runAcceptance4x4`. Full regression: `run(''tests/runTests.m'')`. Per-scenario failures retain diagnostics; testAcceptance4x4 fails on any FAIL. A07 repeats with the same seed and compares the entire moveTable and FINALIZE log via isequaln. Full result, payloads, resources and exception are in each diagnostics MAT.\n');
end
function layout(fid,cargo)
fprintf(fid,'| Lane | Seq0 | Seq1 | Seq2 | Seq3 |\n|---|---|---|---|---|\n');
for l=1:4
 fprintf(fid,'| L%d ',l);
 for q=1:4
  id=cargo.CargoID(cargo.StationMark==100*l+q); if id=="", id="."; end
  fprintf(fid,'| %s ',id);
 end
 fprintf(fid,'|\n');
end
fprintf(fid,'\n');
end
function mdtable(fid,t)
if isempty(t), fprintf(fid,'(none)\n\n'); return; end
fprintf(fid,'| %s |\n',strjoin(t.Properties.VariableNames,' | '));
fprintf(fid,'| %s |\n',strjoin(repmat({'---'},1,width(t)),' | '));
for i=1:height(t)
 cells=strings(1,width(t));
 for j=1:width(t)
  value=t{i,j};
  if iscell(value), cells(j)="(see diagnostics MAT)"; else, cells(j)=join(string(value),', '); end
  cells(j)=fillmissing(cells(j),'constant',"");
  cells(j)=replace(replace(replace(cells(j),"|","&#124;"),newline," "),char(13),"");
 end
 fprintf(fid,'| %s |\n',join(cells,' | '));
end
fprintf(fid,'\n');
end
