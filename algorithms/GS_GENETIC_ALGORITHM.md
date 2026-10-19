# GS genetic algorithm (stage 2)

This documents the stage-2 genetic component. Stage 3 now extends the same
loop with optional local search, a shared budget and stopping controls; see
[GS_MEMETIC_ALGORITHM.md](GS_MEMETIC_ALGORITHM.md) for current interfaces,
defaults and accounting. main.m integration and formal optimization experiments
remain outside scope. FCFS and the simulator remain unchanged.

## Interfaces

| Function | Inputs | Output / responsibility |
|---|---|---|
| `gaOptions(overrides)` | Optional scalar struct | Validated centralized defaults; unknown fields rejected |
| `gaInitializePopulation(mapping,options,stream)` | Stage-1 mapping, options, private RandStream | Cell array of unique valid GS; proposal count |
| `gaTournamentSelect(population,k,stream)` | Evaluated unique candidates, tournament size, stream | Winning population index and sampled indices |
| `gaCrossover(a,b,mapping,cuts)` | Valid parents; two distinct positions | Child and accepted flag |
| `gaSwapMutation(gs,mapping,positions)` | Valid GS; two distinct positions | Child and accepted flag |
| `gaRankCandidates(candidates)` | Evaluated candidates | Best-first indices with one deterministic total order |
| `gaSelectPopulation(candidates,count,options,historicalBestKey)` | Merged candidates, desired size, centralized options, optional incumbent key | Unique next population and quality/diversity/refill diagnostics |
| `gaCreateEvaluator(mapping,evaluator)` | Mapping and `evaluator(ts)` function handle | `evaluate(gs)` and `getStats()` closure handles, fresh run-local cache |
| `gaEvaluateSimulation(ts,tasks,data,cfg)` | Decoded TS and original simulator inputs | Required metrics and reliable completed-customer count |
| `runGSGeneticAlgorithm(mapping,evaluator,overrides)` | Mapping, injected evaluator, optional parameters | `best`, final `population`, `history`, `options`, `stats` |

Each candidate stores `gs`, `ts`, `key` (from `gsCanonicalString`) and
`evaluation`. Evaluators return a scalar struct with `isFeasible`,
`isDeadlocked`, `SystemMakespan`, `CustomerCompletionMakespan`,
`TotalMoveCount`, `totalDistance`, `RelocationCount`, `FillingCount` and
`failureReason`. Optional `CompletedCustomerCount` must be a truthful
nonnegative integer, or NaN when unknown. Invalid evaluator contracts and
unexpected exceptions fail explicitly rather than becoming invented penalties.

## Parameters and randomness

Defaults: population 12, offspring 8, tournament 3, crossover probability 0.8,
swap mutation probability 0.2, next population 12, generations 5, seed 1,
initialization attempt limit 10,000. Selection now uses eliteCount=6,
qualityPoolSize=18 and makespanToleranceLevels=[0.02 0.05 0.10]. The retained
minPositionDistance=0.2 option is legacy and is not read by the selector.
Change options with an override struct; no simulator config is edited.
The run owns an `mt19937ar` RandStream and never sets the global RNG. An
injected evaluator is responsible for its own random-state side effects.

Initialization randomly chooses an available task in a topological order,
then encodes it using the unchanged stage-1 encoder. This is not claimed to
sample legal GS uniformly. Canonical keys enforce uniqueness. A multinomial
upper bound detects obviously insufficient lane-label spaces; the finite
attempt limit gives a diagnostic for constrained spaces or unlucky sampling,
without claiming to prove insufficiency when sampling merely exhausted.

## Operators and ordering

Tournaments sample distinct population members without replacement. Both
parents are selected independently. When crossover is skipped the child is
a copy of parent A. Otherwise choose two distinct positions uniformly,
preserve A's inclusive segment in place, scan B left-to-right accepting only
remaining label quotas, and fill positions outside the segment left-to-right.
Mutation independently swaps two distinct positions; swapping equal labels is
a valid no-op. Both operators validate with stage 1. A cross-lane business
precedence violation rejects the proposed operation and returns its input
(A for crossover, pre-mutation child for mutation); no repair is performed.
Rejected operations are counted. Lengths below two skip positional operators.

Feasible candidates rank before failures, then by ascending SystemMakespan,
TotalMoveCount, totalDistance and canonical key. Failures rank by descending
CompletedCustomerCount and ascending canonical key; unknown progress ranks
after known progress. The real adapter derives progress only from the
existing `result.taskStatus == "Completed"`, which includes true FINALIZE
completions and excludes unfinished moves. No progress is inferred from
partial times or move counts. Infeasible SystemMakespan and
CustomerCompletionMakespan are normalized to NaN and never compared as
completion objectives; original failureReason and deadlock flag are kept.

Merge parents, offspring and the historical elite, rank and de-duplicate by
key. Protect the first min(6,count) individuals. When feasible candidates
suffice, take the remaining diversity candidates from the top 18 quality ranks,
first within 2% of the best feasible SystemMakespan, then 5%, then 10%.
Within each band greedily maximize distance to the nearest selected GS,
recomputing after every addition; equal distances use original quality rank.
The distance is the fraction of unequal positions, not a rejection threshold.
Fill unfilled positions by quality without the pool/band restriction.

When feasible candidates are fewer than count, retain all feasible candidates
and fill failures strictly by the existing ranking. Return actual available
individuals with insufficientCandidates diagnostics when unique candidates
are too few. Zero best time admits only zero-time individuals in bands;
feasible NaN/Inf/negative makespans fail explicitly. No feasible candidate
means rank-only failure selection. The algorithm passes its historical best
key; absence is an error. Direct callers omitting it receive an explicit
unverified-contract diagnostic. The merged rank-1 individual is always
protected; an old incumbent can be superseded by better merged candidates.
Full mapping validation remains at the evaluator; selection additionally
checks consistent GS lengths/multiplicities. It evaluates no new candidate.

## Cache and statistics

One cache per run stores the complete evaluated candidate under its canonical
key. A hit returns it without evaluator invocation. `candidateGeneratedCount`
counts accepted initial/offspring GS sent to the cache, including duplicates;
`uniqueEvaluationCount` counts evaluator calls and `cacheHitCount` counts hits.
For a completed run their sum equals candidateGeneratedCount. In stage-2-only
mode, with no early termination, it equals populationSize + maxGenerations *
offspringCount. Initialization's raw
topological proposals are separately recorded as initializationProposalCount;
rejected operator proposals are recorded separately too. These counts are
historical stage-2 accounting; the stage-3 shared budget now limits new calls.
History includes generation 0, best metrics/key,
population keys and cumulative cache statistics.

## Testing and future use

```matlab
addpath('tests');
testGSGeneticAlgorithm; % Mock evaluator; no real optimization simulation
testGAEvaluationAdapter; % Tiny A06 adapter fixture; no optimization loop
testGSEncoding;
run('tests/runTests.m');
```

Tests cover repeated-label quotas, exact segment filling, uniqueness, RNG
reproducibility, finite initialization failure, static-edge rejection,
lexicographic/tournament ties, positional diversity/refill, elite retention,
cache isolation/counts and short multi-generation mock runs.
The separate adapter test compares all projected fields exactly against a
direct A06 simulation and checks invalid-input normalization.

For a later explicitly authorized real experiment, build the mapping with
the same optional businessEdges as cfg, load data.cargoInitial as main does,
and inject `@(ts)gaEvaluateSimulation(ts,tasks,data,cfg)`. The adapter calls
the existing simulateSchedule directly; it contains no scheduling policy
and writes no formal results. Do not run an optimization merely to test wiring.
