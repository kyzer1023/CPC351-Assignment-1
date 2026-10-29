# CPC351 Assignment 01

USM CPC351/CPM351 Principles of Data Analytics, Semester 1, 2026/2027.

This repository holds the current assignment brief, original registration data,
and an R project scaffold. Q1 currently inventories the supplied inputs; Q2
checks the CSV schema when data is available. Cleaning, scheduling, cost
matrices, and routing are still to be implemented.

## Shared workspace and report

- [Google Drive project folder](https://drive.google.com/drive/u/0/folders/19dXocKj3UaWQLkAHBNtxY1Q45Rxe5zI_)
- [Google Docs report: CPC351_Group01_A01_Report](https://docs.google.com/document/d/1GAB7_rqw0hhjneBch7KhtM-GNt_AlFTzSP1gphYUyOE/edit?usp=drive_link)

**Google Docs is the source of truth for the report.** Write and revise the
report there. There is no `report/` folder or local LaTeX report in this project.
Generate tables and figures under `outputs/`, then insert the selected results
into the shared document. Export the completed report as a PDF into
`submission/` when preparing the final package.

Drive also contains a previous group's reference project. Use the current
[assignment brief](S261_CPC351_Assignment_01_v01.pdf) in this repository for
this semester's requirements. Keep shared reference documents on Drive; a
separate `materials/` folder and duplicate data ZIP are unnecessary here.

Future agents should read [AGENTS.md](AGENTS.md) before making changes.

## Project structure

```text
CPC351-Assignment-1/
|-- AGENTS.md                      Project guidance for coding agents
|-- CPC351-Assignment-1.Rproj       RStudio project
|-- S261_CPC351_Assignment_01_v01.pdf  Current assignment brief and rubric
|-- code/
|   |-- run.R                      Entry point for either question or both
|   |-- common/                    Shared input/output helpers
|   |-- q1/                        Registration and exam scheduling work
|   |-- q2/                        Travel data and routing work
|   `-- examples/                  Original student.R example and its plot
|-- data/
|   |-- raw/
|   |   |-- q1/                    Six original registration lists
|   |   |-- q2/                    Place ahmad_travel_logs.csv here when available
|   |   `-- manifest.json          Original archive and extracted file hashes
|   `-- processed/                 Generated cleaned data, by question
|-- outputs/
|   |-- q1/                        Generated inventories, schedules, and figures
|   `-- q2/                        Generated costs, routes, and figures
`-- submission/                    Final PDF and assignment archive, when ready
```

`code/` separates question logic from shared helpers. `data/raw/` keeps the
inputs needed to run a fresh clone; `data/processed/` keeps derived data apart
from those inputs. `outputs/` holds results to use in Google Docs, while
`submission/` holds only final exports and packaging. Generated contents are
ignored by Git; the folder placeholders and guidance remain tracked.

## Run the baseline

Install R and make `Rscript` available on your PATH. RStudio is optional; open
`CPC351-Assignment-1.Rproj` to work from the project root. Only base R is used,
so no R packages need to be installed.

Run from the repository root:

```sh
Rscript code/run.R
Rscript code/run.R q1
Rscript code/run.R q2
Rscript code/run.R q2 "path/to/ahmad_travel_logs.csv"
```

The default mode is `all`. An optional CSV path is also accepted after `all`.
Relative CSV paths are resolved from the current working directory. In an
interactive RStudio session, `source("code/run.R")` runs both baseline checks.
The runner can also be invoked by its absolute path from another directory.

- Q1 reads the six raw lists without changing student identifiers and writes
  `outputs/q1/input_inventory.csv` with raw row, blank row, and exact duplicate
  counts.
- Q2 checks the seven required CSV column names when the input exists. Missing
  data is reported as skipped because no Q2 dataset is supplied. This check
  does not validate values or calculate a route.
- The original `code/examples/student.R` uses `View()` and is intended for an
  interactive RStudio session. Its original `Rplots.pdf` is preserved as
  `code/examples/student-scores.pdf`; neither is part of the assignment runner.

Keep raw inputs unchanged. Derived data, generated outputs, R session state,
and final submission artifacts are ignored by Git.

## Implementation guidance

- [Q1 plan](code/q1/README.md): cleaning, conflict matrix, room capacities,
  concurrent exams, and the back-to-back constraint.
- [Q2 plan](code/q2/README.md): rainy-morning cost matrix, invalid travel times,
  blocked-route penalties, and Nearest Neighbour routing.
- [Data notes](data/README.md): provenance, input inventory, and Q2 schema.
- [Submission guide](submission/README.md): report export and packaging.

The brief specifies four group members, `.R` source files, and a PDF report of
at most 12 pages including the cover page. The stated deadline is 15 November
2026 at 11:59 p.m. All members must be prepared for the code demonstration and
grading interview.
