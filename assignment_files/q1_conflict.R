# Q1(b): construct and export the exact shared-student conflict matrix.

if (!exists("q1_find_project_root", mode = "function")) {
  source(file.path("assignment_files", "q1_clean.R"), local = TRUE)
}

build_q1_conflict_matrix <- function(courses) {
  if (!is.list(courses) || is.null(names(courses)) || length(courses) != 6L) {
    stop("courses must be a named list of six cleaned registration vectors.", call. = FALSE)
  }
  course_names <- names(courses)
  overlap <- function(course_a, course_b) {
    length(intersect(courses[[course_a]], courses[[course_b]]))
  }
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

if (sys.nframe() == 0L) {
  root <- q1_find_project_root()
  clean_path <- file.path(root, "outputs", "q1", "courses_clean.rds")
  if (!file.exists(clean_path)) {
    stop("Run assignment_files/q1_clean.R first to create the cleaned registration lists.",
         call. = FALSE)
  }
  courses <- readRDS(clean_path)
  conflict_matrix <- build_q1_conflict_matrix(courses)
  pair_summary <- write_q1_conflict_outputs(conflict_matrix, root)
  print(conflict_matrix)
  print(pair_summary, row.names = FALSE)
  message("Q1(b): conflict matrix written to outputs/q1/conflict_matrix.csv.")
}
