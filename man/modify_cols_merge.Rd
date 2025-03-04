% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/modify_cols_merge.R
\name{modify_cols_merge}
\alias{modify_cols_merge}
\title{Modify Column Merging}
\usage{
modify_cols_merge(x, pattern, rows = NULL)
}
\arguments{
\item{x}{gtsummary object}

\item{pattern}{glue syntax string indicating how to merge columns in
\code{x$table_body}. For example, to construct a confidence interval
use \code{"{conf.low}, {conf.high}"}.}

\item{rows}{predicate expression to select rows in \code{x$table_body}.
Can be used to style footnote, formatting functions, missing symbols,
and text formatting. Default is \code{NULL}. See details below.}
}
\value{
gtsummary table
}
\description{
\lifecycle{experimental}
Merge two or more columns in a gtsummary table.
Use \code{show_header_names()} to print underlying column names.
}
\section{Details}{

\enumerate{
\item Calling this function merely records the instructions to merge columns.
The actual merging occurs when the gtsummary table is printed or converted
with a function like \code{as_gt()}.
\item Because the column merging is delayed, it is recommended to perform
major modifications to the table, such as those with \code{tbl_merge()} and
\code{tbl_stack()}, before assigning merging instructions. Otherwise,
unexpected formatting may occur in the final table.
}
}

\section{Future Updates}{

There are planned updates to the implementation of this function
with respect to the \verb{pattern=} argument.
Currently, this function replaces a numeric column with a
formatted character column following \verb{pattern=}.
Once \code{gt::cols_merge()} gains the \verb{rows=} argument the
implementation will be updated to use it, which will keep
numeric columns numeric. For the \emph{vast majority} of users,
\emph{the planned change will be go unnoticed}.
}

\section{Example Output}{

\if{html}{Example 1}

\if{html}{\figure{modify_cols_merge_ex1.png}{options: width=65\%}}

\if{html}{Example 2}

\if{html}{\figure{modify_cols_merge_ex2.png}{options: width=41\%}}
}

\examples{
# Example 1 ----------------------------------
modify_cols_merge_ex1 <-
  trial \%>\%
  select(age, marker, trt) \%>\%
  tbl_summary(by = trt, missing = "no") \%>\%
  add_p(all_continuous() ~ "t.test",
        pvalue_fun = ~style_pvalue(., prepend_p = TRUE)) \%>\%
  modify_fmt_fun(statistic ~ style_sigfig) \%>\%
  modify_cols_merge(pattern = "t = {statistic}; {p.value}") \%>\%
  modify_header(statistic ~ "**t-test**")

# Example 2 ----------------------------------
modify_cols_merge_ex2 <-
  lm(marker ~ age + grade, trial) \%>\%
  tbl_regression() \%>\%
  modify_cols_merge(
    pattern = "{estimate} ({ci})",
    rows = !is.na(estimate)
  )
}
\seealso{
Other Advanced modifiers: 
\code{\link{modify_column_hide}()},
\code{\link{modify_fmt_fun}()},
\code{\link{modify_table_body}()},
\code{\link{modify_table_styling}()}
}
\concept{Advanced modifiers}
