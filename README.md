# CPC351 Assignment 01

USM CPC351/CPM351 Principles of Data Analytics, Semester 1, 2026/2027.

This R assignment processes the Q1 registration lists and Q2 travel logs. The runnable scripts and supplied inputs are together in `assignment_files/`; generated results are written to `outputs/`.

## Project links

- [Shared Drive](https://drive.google.com/drive/u/0/folders/19dXocKj3UaWQLkAHBNtxY1Q45Rxe5zI_)
- [Google Docs report](https://docs.google.com/document/d/1GAB7_rqw0hhjneBch7KhtM-GNt_AlFTzSP1gphYUyOE/edit?usp=drive_link)

## Run

Install R. Open `CPC351-Assignment-1.Rproj` in RStudio, or run from the assignment folder:

```sh
Rscript assignment_files/run_assignment.R
```

The runner processes Q1 and Q2. Q1 writes an input inventory to `outputs/q1/`. For Q2, place the provided grading file beside the scripts and name it `ahmad_travel_logs.csv`. The included `ahmad_travel_logs_synthetic.csv` is development data; run it explicitly with:

```sh
Rscript assignment_files/run_assignment.R q2 assignment_files/ahmad_travel_logs_synthetic.csv
```

Q2 matrices, routes, plots, and filtered logs are written to `outputs/q2/`. The `assignment_files/` folder is self-contained for scripts and inputs.

For packaging guidance, see the [submission guide](submission/README.md).
