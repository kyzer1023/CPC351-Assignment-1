# Q1(b): construct and export the exact shared-student conflict matrix.

if (!exists("find_q1_project_root", mode = "function")) {
  source(file.path("assignment_files", "q1_clean.R"), local = TRUE)
}

build_q1_conflict_matrix <- function(courses) {
  if (!is.list(courses) || is.null(names(courses)) || length(courses) != 6L) {
    stop("courses must be a named list of six cleaned registration vectors.", call. = FALSE)
  }
  course_names <- names(courses)
  # Off-diagonal entries count shared students: a positive value means a clash.
  # Comparing a course with itself gives its enrolment on the diagonal.
  overlap <- function(course_a, course_b) {
    length(intersect(courses[[course_a]], courses[[course_b]]))
  }
  # Apply the overlap count to every row/column pair of courses.
  conflict <- outer(course_names, course_names, Vectorize(overlap))
  dimnames(conflict) <- list(course_names, course_names)
  storage.mode(conflict) <- "integer"
  
  sizes <- lengths(courses)
  if (!isSymmetric(conflict) || !identical(as.integer(diag(conflict)), as.integer(sizes))) {
    stop("Conflict matrix validation failed.", call. = FALSE)
  }
  conflict
}

write_q1_conflict_outputs <- function(conflict_matrix, project_root) {
  output_dir <- file.path(project_root, "outputs", "q1")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(Course = rownames(conflict_matrix), conflict_matrix,
               check.names = FALSE),
    file.path(output_dir, "conflict_matrix.csv"),
    row.names = FALSE
  )
  
  # Use only entries above the diagonal: each distinct course pair appears once.
  upper <- upper.tri(conflict_matrix)
  locations <- which(upper, arr.ind = TRUE)
  summary <- data.frame(
    course_a = rownames(conflict_matrix)[locations[, 1L]],
    course_b = colnames(conflict_matrix)[locations[, 2L]],
    shared_students = conflict_matrix[upper],
    stringsAsFactors = FALSE
  )
  summary <- summary[order(-summary$shared_students, summary$course_a, summary$course_b), ]
  rownames(summary) <- NULL
  utils::write.csv(summary, file.path(output_dir, "conflict_pairs.csv"), row.names = FALSE)
  invisible(summary)
}

# Diagnostics for the report (not used by the pipeline) ====

check_q1_conflict_matrix <- function(courses, conflict_matrix) {
  # M = student x course table of 0/1 (1 = student is registered in that course)
  students <- sort(unique(unlist(courses)))
  M <- sapply(courses, function(ids) as.integer(students %in% ids))
  rownames(M) <- students
  
  # Second method: t(M) %*% M gives every pairwise overlap at once
  if (!all(conflict_matrix == t(M) %*% M)) {
    stop("Incidence-matrix check does not match the conflict matrix.", call. = FALSE)
  }
  sizes <- lengths(courses)[rownames(conflict_matrix)]
  upper <- upper.tri(conflict_matrix)       # TRUE above the diagonal (each pair once)
  if (any(conflict_matrix[upper] > outer(sizes, sizes, pmin)[upper])) {
    stop("An overlap is larger than the smaller course.", call. = FALSE)
  }
  list(incidence = M,
       distinct_students = nrow(M),
       courses_per_student = table(courses_taken = rowSums(M)))
}

if (sys.nframe() == 0L) {
  root <- find_q1_project_root()
  clean_path <- file.path(root, "outputs", "q1", "courses_clean.rds")
  if (!file.exists(clean_path)) {
    stop("Run assignment_files/q1_clean.R first to create the cleaned registration lists.",
         call. = FALSE)
  }
  courses <- readRDS(clean_path)
  conflict_matrix <- build_q1_conflict_matrix(courses)
  pair_summary <- write_q1_conflict_outputs(conflict_matrix, root)
  cat("\nConflict matrix (students shared by each pair of courses; diagonal = course size):\n")
  print(conflict_matrix)
  cat("\nAll 15 course pairs, most shared students first:\n")
  print(pair_summary, row.names = FALSE)
  message("Q1(b): conflict matrix written to outputs/q1/conflict_matrix.csv.")
  
  check <- check_q1_conflict_matrix(courses, conflict_matrix)
  cat("\nDistinct students across all courses:\n")
  print(check$distinct_students)        # distinct students across all courses
  cat("\nTotal registrations (a student in two courses counts twice):\n")
  print(sum(lengths(courses)))          # total registrations
  cat("\nNumber of students taking 1, 2, 3, ... courses:\n")
  print(as.data.frame(check$courses_per_student, responseName = "students"))      # students taking 1, 2, 3, ... courses
  cat("\nCourse pairs with no shared students (can share a time period):\n")
  print(pair_summary[pair_summary$shared_students == 0, ], row.names = FALSE)  # pairs with no clash
  message("Q1(b): second-method check passed.")
}
