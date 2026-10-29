# Project guidance

## Scope and current status

This is USM CPC351/CPM351 Assignment 01, implemented in R. Read `README.md`,
`data/README.md`, and the relevant question's README before changing code.
The current assignment brief is `S261_CPC351_Assignment_01_v01.pdf` at the root.

The baseline only inventories Q1 inputs and checks Q2 CSV column names.
Assignment cleaning, scheduling, cost matrices, and routing are pending.
Do not describe these algorithms as complete until implemented and validated.

## Shared documents

- Drive: https://drive.google.com/drive/u/0/folders/19dXocKj3UaWQLkAHBNtxY1Q45Rxe5zI_
- Report: https://docs.google.com/document/d/1GAB7_rqw0hhjneBch7KhtM-GNt_AlFTzSP1gphYUyOE/edit?usp=drive_link

The report is maintained in **Google Docs**. Do not create a `report/` folder,
LaTeX report, or competing local report source. Keep these links discoverable
in the root README. For a report task, read the shared document before editing
it through the connected Google Drive/Docs tools. Keep its existing sharing and
location unless the user asks to change them.

Drive contains a previous group's reference project with a different brief.
Use this repository's current brief for requirements. Keep reference documents
on Drive instead of introducing a `materials/` folder or duplicate input ZIP.

Generate figures and tables in `outputs/q1/` or `outputs/q2/` and insert selected
results into Google Docs. Export the final PDF into the ignored `submission/`
area for packaging. The report must fit within 12 pages including its cover.

## File ownership and data handling

- `code/q1/` and `code/q2/`: question-specific R functions.
- `code/common/`: shared helpers; `code/run.R`: command-line entry point.
- `code/examples/`: original learning example and plot, separate from the
  assignment runner.
- `data/raw/q1/`: preserve the supplied files unchanged.
  `data/raw/manifest.json` records SHA-256 hashes of the committed input bytes
  and the original source ZIP's hash for provenance.
  Raw data is excluded from Git line-ending conversion by `.gitattributes`.
- `data/raw/q2/ahmad_travel_logs.csv`: optional input, absent from the supplied
  materials. Do not invent a grading dataset or hardcode hidden data results.
- `data/processed/q1/` and `data/processed/q2/`: generated cleaned data.
- `outputs/q1/` and `outputs/q2/`: generated results and report figures.
- `submission/`: generated final PDF and archive; retain its tracked README.

Keep synthetic Q2 development data clearly labeled and separate from supplied
or grading inputs. Keep generated files and local R session state out of Git.
Use project-relative paths and avoid adding packages without a concrete need.

## Validation

From the repository root, run `Rscript code/run.R` for the baseline smoke check.
Q1 should write `outputs/q1/input_inventory.csv` for six courses; Q2 should
skip cleanly when no CSV exists. To check an available Q2 CSV, run
`Rscript code/run.R q2 "path/to/ahmad_travel_logs.csv"`.

Check raw-file hashes against `data/raw/manifest.json` after moving files or
changing Git attributes. Check `git diff --check` before committing. If R is
unavailable, state that execution was not verified instead of claiming success.

When implementing algorithms, validate simultaneous room slots as the same
exam period (1/2, 3/4, 5/6, 7/8). For Q2, validate unseen data with the stated
schema; derive costs and routes from the input rather than row indices or
manual overrides. Record decisions and explain the resulting logic in the
shared report when report work is requested.
