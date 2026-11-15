# CPC351 Assignment 01

USM CPC351/CPM351 Principles of Data Analytics, Semester 1, 2026/2027.

This R assignment processes the Q1 registration lists and Q2 travel logs. The runnable scripts and supplied inputs are together in `assignment_files/`; generated tables, plots, and cleaned lists are written to `outputs/`.

## Project links

- [Shared Drive](https://drive.google.com/drive/u/0/folders/19dXocKj3UaWQLkAHBNtxY1Q45Rxe5zI_)
- [Google Docs report](https://docs.google.com/document/d/1GAB7_rqw0hhjneBch7KhtM-GNt_AlFTzSP1gphYUyOE/edit?usp=drive_link)

## Run

Install R. Open `CPC351-Assignment-1.Rproj` in RStudio, or run from the repository root:

```sh
Rscript assignment_files/run_assignment.R
```

The runner processes both questions. Q1 writes cleaned lists, the conflict matrix, an initial timetable, and an updated no-back-to-back timetable to `outputs/q1/`. The original eight slots share four time periods over two days. The supplied data needs five time periods over three days for Q1(c), and five days for Q1(d). The console shows both schedules with their restrictions; exams on consecutive days are allowed.

Each course stays together in one room, and each room holds one course per period. Venue 1 seats 40 students and Venue 2 seats 70. A **period** means one morning or afternoon across both venues; a **slot** means one venue in one period. Two days therefore provide four periods and eight room slots.

To follow the Q1 code, start with `q1_main.R`. It calls `q1_clean.R` for Q1(a), `q1_conflict.R` for Q1(b), and `q1_schedule.R` for Q1(c-d). The scheduler tries smaller period/day limits first. For each course it tries a placement, checks room capacity and student conflicts, then works on the remaining courses. If a later course cannot fit, it returns to the previous choice and tries another. The first complete assignment gives the minimum number of periods for (c), or days for (d). Both timetables are validated before export. Q1 uses the six supplied registration lists.

Within `q1_schedule.R`, functions follow assignment order: the period search, timetable builder, and validator for Q1(c), then the day search, builder, and validator for Q1(d). `generate_q1_timetables()` runs both parts and returns `period_timetable`, `day_timetable`, `minimum_periods`, and `minimum_days`, together with the original two-day feasibility check. Printing, export, and the standalone entry point follow at the end of the file. Brief comments explain the main loops and the choices made during backtracking.

For Q2, place the grading file beside the scripts and name it `ahmad_travel_logs.csv`. The included `ahmad_travel_logs_synthetic.csv` is development data and is never substituted automatically. Run it explicitly with:

```sh
Rscript assignment_files/run_assignment.R q2 assignment_files/ahmad_travel_logs_synthetic.csv
```

Q2 matrices, routes, plots, and filtered logs are written to `outputs/q2/`. To run the pipeline checks, use:

```sh
Rscript assignment_files/test_q1_pipeline.R
Rscript assignment_files/test_q2a_cost_matrix.R
Rscript assignment_files/test_nearest_neighbour.R
Rscript assignment_files/test_pipeline.R
```

The `assignment_files/` folder contains the scripts and inputs needed to run the assignment.

For packaging guidance, see the [submission guide](submission/README.md).
