# GS-Memetic experiments: main integration and stage-4A smoke

`main.m` is the single manual formal-experiment entry (stage 4B).
It delegates to the reusable service
`runGSMemeticExperiment(overrides,outputDirectory,progressFcn)`.
It loads config() and the same read-only data/inputs as main, validates them,
runs `fcfsSequence(tasks)` through simulateSchedule without precedence repair,
builds GS mapping with cfg.businessEdges if present, and injects
`@(ts)gaEvaluateSimulation(ts,tasks,data,cfg)` into runGSGeneticAlgorithm.
Both algorithms and the best replay receive the identical tasks/data/cfg.

## Stage 4B: open main.m and click Run

The parameter block passes populationSize=12, offspringCount=8,
tournamentSize=3, crossoverProbability=0.8, mutationProbability=0.2,
localSearchEvaluations=3 (existing first improvement), maxUniqueEvaluations=100,
seed=42, enableStallStop=false, stallGenerations=4 and maxGenerations=100.
Algorithm defaults are unchanged. Budget 100 is an upper bound, not a promise
to consume all evaluations: the existing space/novelty and generation limits
still apply. FCFS and best replay are outside the search evaluation budget.

main calls the service once, with an empty export path. The service runs FCFS
once, searches once and replays the best once. main displays the complete
comparison, then exports once after replayExact is asserted. No simulation
or algorithm is reimplemented in main, and no second baseline is launched.

Optional progressFcn is forwarded as the fourth argument of
runGSGeneticAlgorithm. It receives (historyRow,options) after generation 0
and each completed generation. printGSMemeticProgress only prints generation,
unique count / configured budget, cache hits, best SystemMakespan and feasibility.
Existing callers omitting the observer retain the same behavior and defaults.
The observer is not stored in algorithm options/results, and errors propagate.

Exports go to a new `results/gs_memetic_<timestamp>_<unique-token>/`.
The directory is created only after search/replay. Existing paths are rejected.
comparison.csv retains totalDistance in map units and adds
TotalDistanceMapUnits, TotalDistanceMeters and MetersPerMapUnit from cfg.
Additional empty/loaded/exit/home distances remain map units. Infeasible
completion metrics are NaN, and improvement percentages remain unavailable
unless both candidates are feasible with positive FCFS makespan.

Files prepared: comparison.csv, convergence.csv, search_history.csv,
best_gs.csv, best_ts.csv, precedence_constraints.csv, run_log.txt and
experiment.mat. Per-solution fcfs/gs_memetic prefixes produce tasks, events,
slots, cargo, moves, finalize CSVs and status text. Current enableAnimation
and enablePlots settings produce HTML playback, convergence.png and feasible
solutions' Gantt/utilization PNGs. GIF is optional under enableAnimationGIF.
Existing exporters/renderers are reused; the search observer writes no files.
Full options, stop reason, raw history and all results remain in experiment.mat.

Stage 4B was prepared using static checks only: no MATLAB execution, main run,
simulation, optimization, exporter invocation or regression execution. The
formal run, callback rendering, CSV/MAT exports and plots await user validation.

## Stage-4A API defaults and smoke (retained)

Safe invocation defaults are 3 unique GS evaluations and at most 2 generations.
These are local call overrides; gaOptions and config defaults are unchanged.
With the normal population size 12, budget 3 is consumed during initialization.
The smoke test temporarily sets populationSize=2 and tournamentSize=2 to
exercise breeding/cache/local search with the same small budget. No formal
100-evaluation experiment is executed by tests.

```matlab
% Run ONLY this smoke test in a fresh MATLAB process:
addpath('tests');
smokeGSExperiment;
```

Search produces no CSV, MAT, plots, HTML or GIF. The entry returns an in-memory
experiment struct: cfg/data/tasks/mapping, original FCFS sequence/result,
search/history/stats, unique evaluation trace (keys/TS/metrics), full best
replay, comparison table, guarded makespan improvement percentage and
replayExact. Each actual evaluator call is traced and checked against the
cache's uniqueEvaluationCount. No Random sequence or baseline is used.

The best TS is simulated once more after optimization. Every projected metric,
including feasibility, deadlock, failureReason and completed-customer count,
must match the cached best by isequaln or the entry throws. This replay is a
validation/export preparation call, not another optimization evaluation.
The smoke therefore makes five actual simulator calls: original FCFS once,
three unique GS evaluations, and one best replay. It verifies no formal
artifacts changed, then writes only diagnostic evidence to
results/validation/stage4a_smoke.mat. Console output records the comparison,
best GS/TS, budget, cache counts and termination reason.

Infeasible/deadlocked results retain flags/reasons and NaN completion metrics.
Improvement percentages are NaN unless both results are feasible and FCFS's
SystemMakespan is positive. They are diagnostics, not an experimental claim.
Strict improvement uses feasibility and optimization metrics/progress only;
canonical keys retain deterministic sorting without resetting stall counts
or ending local search on a pure string tie.

## Prepared post-search outputs

No output directory is supplied in the smoke run. For a later authorized
experiment, supply an explicitly new independent directory as the second
argument, or call `exportGSMemeticExperiment(experiment,newDirectory)` after
reviewing an in-memory result. Existing directories/files are rejected before
export, so current FCFS results are not overwritten.

The exporter prepares comparison.csv, best_gs.csv, best_ts.csv, convergence.csv
and experiment.mat with complete metrics/history/stats/stop reason. Separate
fcfs/gs_memetic prefixes preserve task, event, move, final-slot/cargo and
FINALIZE records. It reuses exportScheduleAnimation/exportScheduleGIF and the
existing Gantt/utilization functions according to the original output flags.
No new animation engine or simulator is introduced. Search and exports are
strictly separated; exports occur only after the best replay checks pass.

`testGSExperiment` tests objective ties, failure/cache handling and isolated
synthetic export wiring with animation/plots disabled. `smokeGSExperiment`
is deliberately not called by the general test suite, so ordinary regression
does not accidentally start real demo50 optimization.

If a fresh real-smoke process suffers MATLAB native corruption, stop the
experiment and report it; do not classify that process failure as a deadlock
or infeasible candidate and do not retry the real experiment silently.

## Stage 4A observed smoke result

The isolated R2022a run completed without exceptions: 3 unique GS calls,
2 cache hits, 1 generation, budgetExhausted, and exact best-metric replay.
Five total simulator invocations include the separate FCFS and replay calls.
No formal artifacts were created or modified during search/replay.

| Result | Feasible | SystemMakespan | CustomerCompletionMakespan | Moves | Distance (map units) | Relocation | Filling |
|---|---|---|---|---|---|---|---|
| Original FCFS | true | 799.33 | 761.72 | 26 | 255882 | 8 | 8 |
| Small-budget GS best | true | 873.74 | 838.13 | 28 | 276618 | 10 | 8 |

Best GS: `42 88 89 86 90 10 38 90 25 56`.
Best TS (task rows): `4 7 1 3 2 5 6 10 9 8`.
All three real candidates were feasible; deadlock/failure-cache handling was
tested with an explicit synthetic returned result. The smoke result is worse
than FCFS and is not evidence for an optimization benefit. Numbers displayed
above are rounded; replay assertions use isequaln without tolerance.

New experiment tests, stage-1/2/3 algorithm regression and a separate full
tests/runTests.m process passed, including A01-A08. No MATLAB native failure
occurred in these stage-4A processes. Only test fixtures/diagnostic evidence
were exported; the optional formal export path was tested with synthetic
tables and all animation/plot flags off, not with a formal demo50 experiment.
