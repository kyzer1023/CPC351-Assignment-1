# Q1(a): clean and standardise the six supplied course registration lists.

q1_expected_courses <- c("CCS592", "CDS501", "CDS506", "CDS512", "CDS521", "CDS523")

find_q1_project_root <- function() {
  file_argument <- grep("^--file=", commandArgs(), value = TRUE)
  starting_points <- getwd()
  if (length(file_argument) > 0L) {
    starting_points <- c(dirname(sub("^--file=", "", file_argument[[1L]])), starting_points)
  }
  # Look for the project from the script's folder and the current working folder.
  for (start in starting_points) {
    candidate <- normalizePath(start, winslash = "/", mustWork = TRUE)
    # Walk up through parent folders until the project files are found.
    repeat {
      if (file.exists(file.path(candidate, "CPC351-Assignment-1.Rproj")) &&
          file.exists(file.path(candidate, "assignment_files", "run_assignment.R"))) {
        return(candidate)
      }
      parent <- dirname(candidate)
      if (identical(parent, candidate)) break
      candidate <- parent
    }
  }
  stop("Cannot locate the assignment folder. Run this script from the project or by its path.",
       call. = FALSE)
}

read_q1_registration_lists <- function(project_root) {
  input_directory <- file.path(project_root, "assignment_files")
  files <- sort(list.files(
    input_directory,
    pattern = "^Q1_[[:alnum:]]+\\.txt$",
    full.names = TRUE
  ))
  course_codes <- sub("^Q1_(.+)\\.txt$", "\\1", basename(files))
  if (!setequal(course_codes, q1_expected_courses) || length(files) != length(q1_expected_courses)) {
    stop(
      "Q1 requires exactly these six files beside the scripts: ",
      paste(paste0("Q1_", q1_expected_courses, ".txt"), collapse = ", "),
      call. = FALSE
    )
  }
  registrations <- lapply(files, readLines, warn = FALSE, encoding = "UTF-8")
  names(registrations) <- course_codes
  registrations[q1_expected_courses]
}

normalize_q1_student_ids <- function(values) {
  raw <- trimws(as.character(values))
  digits <- gsub("[^0-9]", "", raw)
  valid <- nzchar(digits)
  normalized_digits <- sub("^0+", "", digits[valid])
  normalized_digits[!nzchar(normalized_digits)] <- "0"
  padding <- pmax(0L, 3L - nchar(normalized_digits))
  # Write each valid ID as NAME plus at least three digits, preserving larger IDs.
  valid_ids <- paste0("NAME", vapply(seq_along(normalized_digits), function(i) {
    paste0(strrep("0", padding[[i]]), normalized_digits[[i]])
  }, character(1)))
  clean <- rep(NA_character_, length(raw))
  clean[valid] <- valid_ids
  list(raw = raw, clean = clean, valid = valid)
}

clean_q1_registrations <- function(registrations) {
  if (!is.list(registrations) || is.null(names(registrations)) ||
      !setequal(names(registrations), q1_expected_courses)) {
    stop("registrations must be a named list containing the six Q1 courses.", call. = FALSE)
  }
  
  cleaned <- setNames(vector("list", length(q1_expected_courses)), q1_expected_courses)
  audit_rows <- vector("list", length(q1_expected_courses))
  
  # Clean each course separately and record what changed in its audit row.
  for (i in seq_along(q1_expected_courses)) {
    course <- q1_expected_courses[[i]]
    values <- registrations[[course]]
    normalized <- normalize_q1_student_ids(values)
    duplicate <- duplicated(normalized$clean)
    duplicate[!normalized$valid] <- FALSE
    ids <- normalized$clean[normalized$valid & !duplicate]
    cleaned[[course]] <- sort(ids)
    
    audit_rows[[i]] <- data.frame(
      course = course,
      raw_rows = length(values),
      blank_rows = sum(!nzchar(normalized$raw)),
      invalid_id_rows = sum(!normalized$valid & nzchar(normalized$raw)),
      normalized_rows = sum(normalized$valid),
      standardized_rows = sum(normalized$valid &
                                normalized$raw != normalized$clean),
      duplicate_rows_removed = sum(duplicate),
      cleaned_students = length(cleaned[[course]]),
      stringsAsFactors = FALSE
    )
  }
  
  audit <- do.call(rbind, audit_rows)
  rownames(audit) <- NULL
  list(courses = cleaned, audit = audit)
}

write_q1_cleaning_outputs <- function(cleaning_result, project_root) {
  output_dir <- file.path(project_root, "outputs", "q1")
  list_dir <- file.path(output_dir, "cleaned_lists")
  dir.create(list_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(cleaning_result$audit,
                   file.path(output_dir, "q1_cleaning_audit.csv"),
                   row.names = FALSE)
  saveRDS(cleaning_result$courses, file.path(output_dir, "courses_clean.rds"))
  # Save one cleaned registration list per course for inspection and later reuse.
  for (course in names(cleaning_result$courses)) {
    writeLines(
      cleaning_result$courses[[course]],
      file.path(list_dir, paste0("Q1_", course, "_cleaned.txt")),
      useBytes = TRUE
    )
  }
  invisible(output_dir)
}

run_q1_cleaning <- function(project_root = find_q1_project_root()) {
  result <- clean_q1_registrations(read_q1_registration_lists(project_root))
  write_q1_cleaning_outputs(result, project_root)
  result
}

# Diagnostics for the report (not used by the pipeline) ====
# These functions inspect the raw lists and draw the report figures.
# They run only when this file is run on its own, never from run_assignment.R.

build_q1_inspection_table <- function(registrations) {
  split_id <- function(x, course) {
    x <- trimws(x)
    data.frame(
      course    = course,
      raw       = x,
      prefix    = sub("\\d.*$", "", x),        # everything before the first digit
      digits    = gsub("\\D", "", x),          # digits only
      digit_len = nchar(gsub("\\D", "", x)),
      stringsAsFactors = FALSE
    )
  }
  parts <- do.call(rbind, Map(split_id, registrations, names(registrations)))
  rownames(parts) <- NULL
  parts$id_num    <- suppressWarnings(as.integer(parts$digits))
  parts$clean     <- normalize_q1_student_ids(parts$raw)$clean      # same rule as the pipeline
  parts$changed   <- !is.na(parts$clean) & parts$raw != parts$clean # TRUE = text rewritten
  parts$duplicate <- !is.na(parts$clean) & duplicated(parts[, c("course", "clean")])  # repeated ID in a course
  parts
}

# Draw a plot on screen and also save it as a PNG for the report
save_q1_plot <- function(filename, draw, output_dir) {
  draw()
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  grDevices::png(file.path(output_dir, filename), width = 900, height = 650)
  draw()
  invisible(grDevices::dev.off())
}

plot_q1_id_range <- function(inspection, output_dir) {
  save_q1_plot("q1_id_range_boxplot.png", function() {
    graphics::boxplot(id_num ~ course, data = inspection,
                      main = "Student ID number by course (range check)",
                      xlab = "Course", ylab = "ID number")
  }, output_dir)
  save_q1_plot("q1_id_range_stripchart.png", function() {
    graphics::stripchart(id_num ~ course, data = inspection, method = "jitter",
                         vertical = TRUE, pch = 16, col = grDevices::rgb(0, 0, 0, 0.4),
                         main = "Every student ID by course", ylab = "ID number")
  }, output_dir)
  invisible(NULL)
}

plot_q1_course_sizes <- function(courses, output_dir) {
  sizes <- lengths(courses)
  save_q1_plot("q1_course_sizes.png", function() {
    bp <- graphics::barplot(sizes,
                            ylim = c(0, 80),                          # room for the 70 line
                            main = "Students per course (after cleaning)",
                            xlab = "Course", ylab = "Number of students",
                            col  = ifelse(sizes <= 40, "blue", "orange"))  # blue = fits Venue 1
    graphics::abline(h = c(40, 70), lty = 2)                          # venue capacities
    graphics::text(x = max(bp) + 0.6, y = c(40, 70) + 2,
                   labels = c("Venue 1 capacity (40)", "Venue 2 capacity (70)"),
                   adj = 1, cex = 0.8)
    graphics::text(bp, sizes + 5, labels = sizes)                     # count on each bar
    graphics::legend("topleft", fill = c("blue", "orange"),
                     legend = c("Fits Venue 1 or 2 (<= 40)", "Fits Venue 2 only (41-70)"),
                     cex = 0.8, bty = "n")
  }, output_dir)
  invisible(NULL)
}

if (sys.nframe() == 0L) {
  root <- find_q1_project_root()
  result <- run_q1_cleaning(root)
  
  # Inspection and figures for the report
  inspection <- build_q1_inspection_table(read_q1_registration_lists(root))
  figure_dir <- file.path(root, "outputs", "q1", "figures")
  
  cat("\nPrefix types found in each course (before cleaning):\n")
  print(table(inspection$prefix, inspection$course))    # prefix by course
  cat("\nNumber of lines by digits in the ID:\n")
  print(as.data.frame(table(digits_in_id = inspection$digit_len), responseName = "lines"))  # 2 digits = missing leading zero
  cat("\nLines already in NAME### form (FALSE) and lines rewritten (TRUE):\n")
  print(table(inspection$changed))                      # TRUE = text rewritten
  duplicate_rows <- !is.na(inspection$clean) &
    (inspection$duplicate | duplicated(inspection[, c("course", "clean")], fromLast = TRUE))
  cat("\nDuplicate registrations within a course (both copies shown):\n")
  print(inspection[duplicate_rows, c("course", "raw", "clean")])   # both copies shown
  cat("\nLowest and highest student number found:\n")
  print(range(inspection$id_num, na.rm = TRUE))         # ID range
  ids_all <- sort(unique(inspection$id_num))
  cat("\nNumbers from 1 to the highest ID that appear in no course (integer(0) = none):\n")
  print(setdiff(seq_len(max(ids_all)), ids_all))        # numbers in no course (a gap is not an error)
  
  if (sum(inspection$changed) != sum(result$audit$standardized_rows)) {
    stop("Inspection table disagrees with the cleaning audit.", call. = FALSE)
  }
  plot_q1_id_range(inspection, figure_dir)
  plot_q1_course_sizes(result$courses, figure_dir)
  message("Q1(a): figures written to outputs/q1/figures/.")
  
  cat("\nCleaning audit by course:\n")
  print(result$audit, row.names = FALSE)
  message("Q1(a): cleaned registration lists written to outputs/q1/cleaned_lists/.")
}
