# GS/TS encoding (stage 1)

Add `algorithms`, `data` and `tasks` to the MATLAB path. This module does not
change FCFS or invoke the simulator.

```matlab
mapping = buildGSMapping(tasks,data.lanes);
gs = encodeTS(legalTaskRowPermutation,mapping);
ts = decodeGS(gs,mapping);
key = gsCanonicalString(gs,mapping);
```

- `buildGSMapping(tasks,lanes,businessEdges)` returns task rows, per-task
  `taskPocketKey` and `targetSequence`, sorted unique `labels`, `counts`,
  per-label `laneTasks`, and `constraints`. Optional business edges default
  to none and use the existing `buildTargetConstraints` interface.
- `encodeTS(ts,mapping)` validates a complete numeric task-row permutation
  and every static edge, then returns a row string vector of PocketKeys.
- `decodeGS(gs,mapping)` validates a string vector and consumes each lane's
  fixed task list, returning a numeric row permutation.
- `[gs,ts] = validateGS(gs,mapping)` rejects unknown/missing labels, wrong
  multiplicities and static precedence violations; it returns normalized
  row vectors. Validation errors throw; inputs are never repaired.
- `gsCanonicalString(gs,mapping)` validates GS and returns one string.
  Format `GS1|length:label|length:label...` uses character lengths, so
  multi-digit keys and even embedded delimiters remain unambiguous.

Fixed lists follow ascending target Sequence, exactly as the existing
constraint builder. Missing/ambiguous Slot membership, empty keys, nonfinite
depths and within-lane depth ties are rejected. Treat a mapping as immutable
and rebuild it whenever its input tasks, lanes or business edges change.

For lane-only constraints the number of legal GS permutations is
`factorial(n)/prod(factorial(mapping.counts))`. Additional cross-lane business
edges can reduce that number; decoding rejects sequences violating them.
FCFS remains independent and is never repaired or encoded by this module.

Run the independent checks with `addpath('tests'); testGSEncoding`.
