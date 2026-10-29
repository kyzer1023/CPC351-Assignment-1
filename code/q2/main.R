# Q2 baseline: check the schema of an available travel log.
# No dataset is provided with the assignment materials.

required_travel_columns <- c(
  "Origin_X", "Origin_Y", "Dest_X", "Dest_Y",
  "Weather", "Time_of_Day", "Travel_Time_Minutes"
)

inspect_q2_inputs <- function(project_root, input_path) {
  if (!file.exists(input_path)) {
    message("Q2: no travel CSV found at ", input_path)
    message("Q2: skipped. Supply the CSV path when a dataset is available.")
    return(invisible(list(status = "missing_input", path = input_path)))
  }

  header <- utils::read.csv(input_path, nrows = 0L, check.names = FALSE,
                            stringsAsFactors = FALSE)
  missing_columns <- setdiff(required_travel_columns, names(header))

  if (length(missing_columns) > 0L) {
    stop("Q2 CSV is missing required columns: ",
         paste(missing_columns, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(names(header)) > 0L) {
    stop("Q2 CSV contains duplicate column names.", call. = FALSE)
  }

  message("Q2: required CSV column names are present.")
  message("Q2: value checks, cleaning, cost matrix, and routing are pending.")
  invisible(list(status = "schema_checked", path = input_path,
                 columns = names(header)))
}
