# Q1 pipeline: clean registrations, construct the conflict matrix, and schedule.

if (!exists("q1_find_project_root", mode = "function")) {
  source(file.path("assignment_files", "q1_clean.R"), local = TRUE)
  source(file.path("assignment_files", "q1_conflict.R"), local = TRUE)
  source(file.path("assignment_files", "q1_schedule.R"), local = TRUE)
}

if (!exists("generate_q1_shared_timetables", mode = "function")) {
  source(file.path(q1_find_project_root(), "assignment_files", "q1_shared_schedule.R"),
         local = TRUE)
}

run_q1_pipeline <- function(project_root = q1_find_project_root(), verbose = TRUE) {
  registrations <- read_q1_registration_lists(project_root)
  cleaning <- clean_q1_registrations(registrations)
  write_q1_cleaning_outputs(cleaning, project_root)

  conflict_matrix <- build_q1_conflict_matrix(cleaning$courses)
  pair_summary <- write_q1_conflict_outputs(conflict_matrix, project_root)

  schedule <- generate_q1_timetable(cleaning$courses, conflict_matrix)
  validation <- write_q1_timetable_outputs(schedule, project_root)
  shared_schedule <- generate_q1_shared_timetables(cleaning$courses, conflict_matrix)
  write_q1_shared_outputs(shared_schedule, project_root)

  if (isTRUE(verbose)) {
    cat("Q1 cleaning audit:\n")
    print(cleaning$audit, row.names = FALSE)
    cat("\nQ1 conflict matrix (shared students):\n")
    print(conflict_matrix)
    print_q1_timetables(schedule)
    cat("\nOptional shared-room model (splitting allowed when needed):\n")
    cat("Q1(c):", shared_schedule$initial_minimum_sessions, "periods; Q1(d):",
        shared_schedule$minimum_days, "days.\n")
    cat("Occupied room bookings for (c):", length(unique(schedule$initial_timetable$slot)),
        "before,", length(unique(shared_schedule$initial_timetable$slot)), "after.\n")
    cat("Room tables and individual student allocations: outputs/q1/shared_rooms/.\n")
    message("Q1: outputs written under outputs/q1/.")
  }

  invisible(list(
    cleaning = cleaning,
    conflict_matrix = conflict_matrix,
    conflict_pairs = pair_summary,
    schedule = schedule,
    validation = validation,
    shared_schedule = shared_schedule
  ))
}

if (sys.nframe() == 0L) {
  root <- q1_find_project_root()
  result <- run_q1_pipeline(root)
}
