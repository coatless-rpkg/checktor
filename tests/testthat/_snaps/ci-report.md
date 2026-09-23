# ci_report(): github annotation is exactly what a forge parses

    Code
      writeLines(ci_report(r, format = "github", file = NULL))
    Output
      ~::error file=R/a.R,line=2,title=checktor%3A tf_usage::T/F usage check: a.R:2
      ~::error file=R/a.R,line=3,title=checktor%3A internal_ns::Internal namespace check: a.R:3 (otherpkg:::helper)
      ~::notice title=checktor%3A skipped::2 checks did not run: spelling, url_liveness

# ci_report(): azure annotation is exactly what a pipeline parses

    Code
      writeLines(ci_report(r, format = "azure", file = NULL))
    Output
      ~##vso[task.logissue type=error;sourcepath=R/a.R;linenumber=2;code=tf_usage]T/F usage check: a.R:2
      ~##vso[task.logissue type=error;sourcepath=R/a.R;linenumber=3;code=internal_ns]Internal namespace check: a.R:3 (otherpkg:::helper)
      ~##vso[task.logissue type=warning;code=skipped]2 checks did not run: spelling, url_liveness

# ci_report(): a finding with no location is still openable

    Code
      writeLines(text_report)
    Output
      DESCRIPTION:1 [opinion] description_length - Description length check: Description too short: 2 words
      skipped: 2 checks did not run: spelling, url_liveness

