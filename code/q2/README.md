# Question 2: travel costs and routing

`main.R` currently checks the column names of an available travel log. It skips
the check when the file is absent. Value validation, cleaning, aggregation, and
routing have not been implemented.

Run `Rscript code/run.R q2` to use
`data/raw/q2/ahmad_travel_logs.csv`, or pass a different CSV path:

```powershell
Rscript code/run.R q2 "C:/path/to/ahmad_travel_logs.csv"
```

## Implementation sequence

1. Generate a small, clearly labeled synthetic dataset for local development.
   Store synthetic data separately from the eventual grading input.
2. Validate coordinates, conditions, and travel times using the documented
   schema. Filter the relevant observations for a rainy morning and justify
   anomaly handling, including `NA` and `-1` road closure records.
3. Construct a 10 x 10 cost matrix using each route's 75th percentile valid
   travel time. Assign a documented severe penalty where no valid route history
   remains. Make directionality, missing observations, and diagonal treatment
   explicit; do not assume opposite directions have identical costs.
4. Implement Nearest Neighbour with a deterministic tie rule. Visit every point
   once, return to the start, and calculate the full tour cost.
5. Check behavior on blocked routes, missing route histories, reordered rows,
   and unseen datasets with the same schema. Explain when any penalty edge is
   used in a resulting tour.

The ten point coordinates and CSV schema are fixed assignment inputs. Row
indices, route costs, chosen routes, and results must come from the dataset and
algorithm rather than manual overrides.

Write cleaned or aggregated data to `data/processed/q2/` and cost matrices,
route summaries, validation output, and figures to `outputs/q2/`. Insert selected
results into the Question 2 section of the
[shared Google Docs report](https://docs.google.com/document/d/1GAB7_rqw0hhjneBch7KhtM-GNt_AlFTzSP1gphYUyOE/edit?usp=drive_link)
and explain the cleaning, penalties, and route selection there.
