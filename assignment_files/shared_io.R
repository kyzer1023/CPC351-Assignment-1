# Shared output helper. Raw inputs are never overwritten.

write_output_csv <- function(table, destination) {
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(table, destination, row.names = FALSE, na = "")
  invisible(destination)
}
