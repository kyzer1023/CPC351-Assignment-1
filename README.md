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

The runner processes both questions. Q1 writes cleaned lists, the conflict matrix, an initial timetable, and an updated no-back-to-back timetable to `outputs/q1/`. The original eight slots share four time periods over two days. The supplied data needs five time periods over three days for Q1(c), and five days for Q1(d). The console explains both schedules; exams on consecutive days are allowed.

Q1 also runs an optional model that lets compatible courses share a room and lets a course split across both rooms in the same period. Its room tables and individual student allocations go to `outputs/q1/shared_rooms/`. On the supplied data it saves one room booking, while keeping the same five-period/five-day limits. The original timetable remains available for comparison.

See the [graphs, timetables and algorithm flowcharts](evidence/q1_rooms/README.md) for the results and synthetic examples. Reproduce them from the repository root with:

```sh
Rscript evidence/q1_rooms/q1_compare_rooms.R
```

For Q2, place the grading file beside the scripts and name it `ahmad_travel_logs.csv`. The included `ahmad_travel_logs_synthetic.csv` is development data and is never substituted automatically. Run it explicitly with:

```sh
Rscript assignment_files/run_assignment.R q2 assignment_files/ahmad_travel_logs_synthetic.csv
```

Q2 matrices, routes, plots, and filtered logs are written to `outputs/q2/`. To run the pipeline checks, use:

```sh
Rscript assignment_files/test_q1_pipeline.R
Rscript evidence/q1_rooms/test_q1_shared_schedule.R
Rscript assignment_files/test_q2a_cost_matrix.R
Rscript assignment_files/test_nearest_neighbour.R
Rscript assignment_files/test_pipeline.R
```

The `assignment_files/` folder contains the scripts and inputs needed to run the assignment.
The `evidence/` folder contains the PR comparison scripts, synthetic examples, and figures. It is not needed to run the assignment.

For packaging guidance, see the [submission guide](submission/README.md).
