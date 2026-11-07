students <- data.frame(
  name = c("Alice", "Bob", "Chin Qian"),
  score = c(75, 82, 90)
)

print(students)

plot(
  students$score,
  type = "b",
  main = "Student Scores",
  xlab = "Student",
  ylab = "Score"
)
