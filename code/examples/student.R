students <- data.frame(
  name = c("Alice", "Bob", "Chin Qian"),
  score = c(75, 82, 90)
)

View(students)

plot(
  students$score,
  type = "b",
  main = "Student Scores",
  xlab = "Student",
  ylab = "Score"
)