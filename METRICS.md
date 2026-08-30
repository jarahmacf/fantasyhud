# Metric definitions

These formulas define future analytics. No metric is implemented in Task 001.

```text
Player exposure
= rosters containing player / filtered user rosters

NFL-team breadth exposure
= rosters containing at least one player from team / filtered user rosters

NFL-team roster-slot share
= roster slots occupied by players from team / all filtered roster slots

Draft-capital exposure
= normalized acquisition capital allocated to entity / eligible draft capital

Stack rate
= rosters containing at least one qualifying stack / filtered user rosters
```

## Interpretation rules

- Best-ball analytics treat every rostered player as a holding.
- Starter and bench designations never alter exposure.
- Exact pick numbers must be preserved.
- A pick-value model must be explicit, versioned, and tested before use.
- Market ADP and portfolio-sample ADP are different concepts.
