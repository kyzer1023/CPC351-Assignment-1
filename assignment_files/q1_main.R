# Q1 pipeline: clean registrations, construct the conflict matrix, and schedule.

if (!exists("find_q1_project_root", mode = "function")) {
  source(file.path("assignment_files", "q1_clean.R"), local = TRUE)
  source(file.path("assignment_files", "q1_conflict.R"), local = TRUE)
  source(file.path("assignment_files", "q1_schedule.R"), local = TRUE)
}

run_q1_pipeline <- function(project_root = find_q1_project_root(), verbose = TRUE) {
  # Q1(a): standardize student IDs and remove repeated registrations.
  registrations <- read_q1_registration_lists(project_root)
  cleaning <- clean_q1_registrations(registrations)
  write_q1_cleaning_outputs(cleaning, project_root)

  # Q1(b): count the students shared by each pair of courses.
  conflict_matrix <- build_q1_conflict_matrix(cleaning$courses)
  pair_summary <- write_q1_conflict_outputs(conflict_matrix, project_root)

  # Q1(c-d): find and validate both timetables before exporting them.
  schedule <- generate_q1_timetables(cleaning$courses, conflict_matrix)
  validation <- write_q1_timetable_outputs(schedule, project_root)

  if (isTRUE(verbose)) {
    cat("Q1 cleaning audit:\n")
    print(cleaning$audit, row.names = FALSE)
    cat("\nQ1 conflict matrix (shared students):\n")
    print(conflict_matrix)
    print_q1_timetables(schedule)
    message("Q1: outputs written under outputs/q1/.")
  }

  invisible(list(
    cleaning = cleaning,
    conflict_matrix = conflict_matrix,
    conflict_pairs = pair_summary,
    schedule = schedule,
    validation = validation
  ))
}

if (sys.nframe() == 0L) {
  root <- find_q1_project_root()
  result <- run_q1_pipeline(root)
}
