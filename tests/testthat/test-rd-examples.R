# Test rd_example_marked() ----

test_that("rd_example_marked(): leaves out an #ifdef condition, keeping its lines", {
  # `windows` names a platform and is not R: kept, it ran into the code around
  # it, and this example did not parse at all.
  pkg <- rd_pkg(c("x <- c(", "#ifdef windows", "  'a',", "#endif", "  'b')"))
  section <- extract_rd_section(
    tools::parse_Rd(file.path(pkg, "man", "f.Rd")),
    "\\examples"
  )
  for (mark in c(TRUE, FALSE)) {
    expect_equal(
      rd_example_marked(section, mark = mark),
      "\nx <- c(\n\n  'a',\n\n  'b')\n",
      label = paste("mark =", mark)
    )
  }
})
