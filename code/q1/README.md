# Question 1: exam scheduling

`main.R` currently reads the six supplied lists and produces a raw input
inventory. It does not standardize names, deduplicate students, or schedule exams.
Use `Rscript code/run.R q1` from the project root.

## Implementation sequence

1. Clean and standardize student identifiers, justify the treatment of `NEMA`
   spellings and number formatting, and remove repeated registrations within a
   course. Preserve the raw inputs and record cleaning decisions.
2. Build the 6 x 6 matrix of overlapping students. Document the diagonal
   convention, since the scheduling logic uses pairwise course conflicts.
3. Assign courses to rooms and periods using course sizes, conflicts, and the
   room capacities of 40 and 70. Assess whether the supplied timetable is
   sufficient; generate an expanded schedule if necessary.
4. Add the rule that students cannot sit morning and afternoon examinations on
   the same day. Explain the conflict checks in plain English.
5. Validate the resulting schedules independently of the assignment algorithm.

The eight slot labels correspond to four periods in two rooms. Slots 1 and 2
are concurrent, as are 3 and 4, 5 and 6, and 7 and 8. Different slot numbers do
not automatically mean different exam times.

Write cleaned registrations to `data/processed/q1/`. Write the conflict matrix,
timetables, validation summaries, and figures to `outputs/q1/`. Insert selected
results into the Question 1 section of the
[shared Google Docs report](https://docs.google.com/document/d/1GAB7_rqw0hhjneBch7KhtM-GNt_AlFTzSP1gphYUyOE/edit?usp=drive_link)
and explain the scheduling and conflict checks there.
