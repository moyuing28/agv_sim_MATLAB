# GS-Memetic stage 3: first improvement and shared evaluation budget

This extends the existing genetic loop; it does not change the simulator,
FCFS, stage-1 encoding, main.m, production configuration or input files.
There is no formal algorithm comparison or demo50 optimization experiment.

## Interfaces and defaults

- Existing `runGSGeneticAlgorithm(mapping,evaluator,overrides)` now runs the
  genetic loop plus one optional first-improvement search per generation.
- `[evaluate,getStats,getBudget] = gaCreateEvaluator(mapping,evaluator,limit)`
  owns the shared cache and hard evaluation budget. The optional limit
  defaults to `gaOptions().maxUniqueEvaluations` (100).
- `[candidate,status] = evaluate(gs,allowNew)` returns an evaluated candidate,
  or `[]` if a cache miss cannot be evaluated. allowNew defaults to true.
  Status is `evaluated`, `cacheHit`, `budgetExhausted` or `localLimit`.
  Cache lookup precedes both limits, so cached results remain available even
  when either limit is exhausted. No placeholder evaluation is fabricated.
- `[selected,info] = gaFirstImprovement(start,mapping,evaluate,getStats,maxNew)`
  uses the **same** evaluator/stats handles as the genetic loop. start must
  be an already evaluated candidate. maxNew is an integer 0..3; 0 disables
  local search. It returns start unchanged unless it finds strict improvement.
- `gaIsStrictlyBetter(candidate,reference)` delegates to gaRankCandidates,
  including its deterministic canonical-key tie-break; identical keys are
  never considered improvements. There is no separate local-search objective.
- `gaInitializePopulation(...,allowPartial)` adds an optional fourth argument
  and third output complete. The original three-input behavior still rejects
  insufficient spaces. The integrated loop requests a bounded partial result
  and returns a diagnostic if initialization cannot fill the requested size.

New centralized options: maxUniqueEvaluations=100,
localSearchEvaluations=3, enableStallStop=true, stallGenerations=4.
Existing options, private RandStream, crossover, mutation, ranking and
diversity semantics are retained. No simulator settings are changed.

## Local search

Start at the best evaluated member of parents + actual offspring. Traverse
all distinct position pairs in deterministic lexicographic order:
(1,2), (1,3), ..., (1,N), (2,3), ..., (N-1,N). Each pair is tried once.
Equal-label swaps skip validation/evaluation. Other swaps are checked by
validateGS; a static cross-lane precedence violation is skipped without repair.
Unexpected exceptions propagate.

Stop at the first candidate strictly better than the fixed start under the
unchanged stage-2 total order. Otherwise retain start. The canonical key is
the final tie-break in that order, so equal scheduling metrics can still
improve deterministically by key. Each call permits at most three new unique
evaluations, measured as the shared counter delta. After using that allowance,
continue the finite traversal with allowNew=false: later cached improvements
can still be accepted. Global exhaustion similarly prevents new calls while
leaving cached neighbors available. Different-label single swaps from a fixed
start identify distinct neighbors, so attemptedNeighborCount has no duplicate
position-pair retries. It includes static-invalid neighbors, reported separately.

Merge the local result only when improved, then reuse gaSelectPopulation
for unique elite-preserving selection. No unevaluated GS enters the population.
Budget exhaustion can leave fewer than eight offspring or fewer than twelve
initial evaluated individuals; selection handles the available unique count.

## Budget and stopping

All initialization, offspring and local evaluations use one closure. A cache
miss checks the global limit **before** invoking the evaluator and reserves
one count immediately. A hit costs zero. Exceptions are neither swallowed nor
cached as normal scheduling failures; a failed invocation remains reserved and
the optimization aborts. The normal return path never exceeds the configured
limit, including a remaining allowance of one. Budget 0 is supported by the
standalone evaluator; the optimizer requires a positive budget so it can return
an actual evaluated best candidate.

Stop reasons (priority when simultaneous):

1. `budgetExhausted`: no unique-evaluation allowance remains.
2. `spaceExhausted`: the cache covers the multinomial lane-label upper bound,
   which proves exhaustion even if additional static edges were supplied.
3. `stallGenerations`: enabled and no strictly better global best for the
   configured consecutive generations (default four).
4. `maxGenerations`: maximum generation count reached.
5. `noNewCandidates`: no new unique evaluation for stallGenerations consecutive
   generations, even with fitness-stall stopping disabled. This diagnoses the
   actual search's lack of novelty; it does not prove all legal GS were visited.

`candidatesInsufficient` is returned immediately after bounded partial
initialization if the requested unique population cannot be obtained. This
may mean small legal space or sampling exhaustion; it is not a proof of exact
space size with additional business edges. A budget stop has priority there.
Generation 0 covers initialization; maxGenerations=0 returns without breeding.
If no stop condition applies earlier, the maximum generation limit is always
finite even when cache hits prevent the budget from being used up.

## History and accounting

History retains stage-2 fields and adds generationBestSystemMakespan,
globalBestSystemMakespan, globalBestGS, globalBestTS, globalBestIsFeasible,
offspringCount, localSearch, stallCount and stopReason. bestEvaluation includes
all original metrics. Infeasible makespans remain NaN. Generation-best is the
best of the selected merged generation; elitism makes it the global best too.
The terminal history row and run.stopReason record the final reason;
run.generationsCompleted and run.budget record the final generation/budget.

localSearch includes attemptedNeighborCount, newEvaluationCount, cacheHitCount,
improved, equalLabelSkipCount, invalidNeighborCount, localLimitSkipCount,
budgetSkipCount and its own stopReason. Cache stats preserve the three-field
interface from stage 2: candidateGeneratedCount counts requests yielding an
evaluated/cached candidate (including local-search requests),
uniqueEvaluationCount counts reserved evaluator invocations and cacheHitCount
counts hits. On successful runs, generated = unique + hits. Denied requests
are not included; run.budget reports their global/local counts separately.
Initialization proposal and rejected genetic-operator counts remain separate.
The old population + generations * offspring formula applies only with local
search disabled and no early termination.

## Tests

```matlab
addpath('tests');
testGSMemeticAlgorithm;   % Synthetic mappings and mock evaluators only
testGSGeneticAlgorithm;   % Original GA mode with new optional features disabled
testGSEncoding;
testGAEvaluationAdapter;  % Short A06 adapter fixture; no optimization loop
run('tests/runTests.m');
```

Budget boundaries include exactly 100 calls, remaining one, already exhausted,
partial initialization/offspring, cached improvements at zero remaining budget,
and exception propagation. Other tests cover equal-label skips, first strict
improvement, no improvement, local limit three, shared-cache counts, elitism,
unique populations, four-generation stall, disabled stall, maximum generation,
novelty/space termination, reproducibility and unchanged global RNG state.
