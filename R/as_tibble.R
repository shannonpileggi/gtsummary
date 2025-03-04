#' Convert gtsummary object to a tibble
#'
#' Function converts a gtsummary object to a tibble.
#'
#' @inheritParams as_kable
#' @param col_labels Logical argument adding column labels to output tibble.
#' Default is `TRUE`.
#' @param fmt_missing Logical argument adding the missing value formats.
#' @param ... Not used
#' @return a [tibble][tibble::tibble-package]
#' @family gtsummary output types
#' @author Daniel D. Sjoberg
#' @export
#' @examples
#' tbl <-
#'   trial %>%
#'   select(trt, age, grade, response) %>%
#'   tbl_summary(by = trt)
#'
#' as_tibble(tbl)
#'
#' # without column labels
#' as_tibble(tbl, col_labels = FALSE)
as_tibble.gtsummary <- function(x, include = everything(), col_labels = TRUE,
                                return_calls = FALSE, exclude = NULL,
                                fmt_missing = FALSE, ...) {
  # DEPRECATION notes ----------------------------------------------------------
  if (!rlang::quo_is_null(rlang::enquo(exclude))) {
    lifecycle::deprecate_stop(
      "1.2.5",
      "gtsummary::as_tibble(exclude = )",
      "as_tibble(include = )",
      details = paste0(
        "The `include` argument accepts quoted and unquoted expressions similar\n",
        "to `dplyr::select()`. To exclude commands, use the minus sign.\n",
        "For example, `include = -cols_hide`"
      )
    )
  }

  # running pre-conversion function, if present --------------------------------
  x <- do.call(get_theme_element("pkgwide-fun:pre_conversion", default = identity), list(x))

  # converting row specifications to row numbers, and removing old cmds --------
  x <- .clean_table_styling(x)

  # creating list of calls to get formatted tibble -----------------------------
  tibble_calls <-
    table_styling_to_tibble_calls(x = x,
                                  col_labels = col_labels,
                                  fmt_missing = fmt_missing)

  # converting to character vector ---------------------------------------------
  include <-
    .select_to_varnames(
      select = {{ include }},
      var_info = names(tibble_calls),
      arg_name = "include"
    )

  # making list of commands to include -----------------------------------------
  # this ensures list is in the same order as names(x$kable_calls)
  include <- names(tibble_calls) %>% intersect(include)
  # user cannot exclude the first 'tibble' command
  include <- "tibble" %>% union(include)

  # return calls, if requested -------------------------------------------------
  if (return_calls == TRUE) {
    return(tibble_calls[include])
  }

  # taking each gt function call, concatenating them with %>% separating them
  tibble_calls[include] %>%
    # removing NULL elements
    unlist() %>%
    compact() %>%
    # concatenating expressions with %>% between each of them
    reduce(function(x, y) expr(!!x %>% !!y)) %>%
    # evaluating expressions
    eval()
}


table_styling_to_tibble_calls <- function(x, col_labels = TRUE, fmt_missing = FALSE) {
  tibble_calls <- list()

  # tibble ---------------------------------------------------------------------
  tibble_calls[["tibble"]] <- expr(x$table_body)

  # ungroup --------------------------------------------------------------------
  if ("groupname_col" %in% x$table_styling$header$column) {
    tibble_calls[["ungroup"]] <-
      list(
        expr(group_by(.data$groupname_col)),
        expr(mutate(groupname_col = ifelse(dplyr::row_number() == 1,
                                           as.character(.data$groupname_col),
                                           NA_character_))),
        expr(ungroup())
      )
  }

  # fmt (part 1) ---------------------------------------------------------------
  # this needs to be called in as_tibble() before the bolding and italic function,
  # but the bolding and italic code needs to executed on pre-formatted data
  # (e.g. `bold_p()`) this holds its place for when it is finally run
  tibble_calls[["fmt"]] <- list()

  # cols_merge -----------------------------------------------------------------
  tibble_calls[["cols_merge"]] <-
    map(
      seq_len(nrow(x$table_styling$cols_merge)),
      ~ expr(
        mutate(
          !!x$table_styling$cols_merge$column[.x] :=
            ifelse(
              dplyr::row_number() %in% !!x$table_styling$cols_merge$rows[[.x]],
              glue::glue(!!x$table_styling$cols_merge$pattern[.x]) %>% as.character(),
              !!rlang::sym(x$table_styling$cols_merge$column[.x])
            )
        )
      )
    )

  # tab_style_bold -------------------------------------------------------------
  df_bold <- x$table_styling$text_format %>% filter(.data$format_type == "bold")

  tibble_calls[["tab_style_bold"]] <-
    map(
      seq_len(nrow(df_bold)),
      ~ expr(mutate_at(
        gt::vars(!!!syms(df_bold$column[[.x]])),
        ~ ifelse(row_number() %in% !!df_bold$row_numbers[[.x]],
          paste0("__", ., "__"), .
        )
      ))
    )

  # tab_style_italic -------------------------------------------------------------
  df_italic <- x$table_styling$text_format %>% filter(.data$format_type == "italic")

  tibble_calls[["tab_style_italic"]] <-
    map(
      seq_len(nrow(df_italic)),
      ~ expr(mutate_at(
        gt::vars(!!!syms(df_italic$column[[.x]])),
        ~ ifelse(row_number() %in% !!df_italic$row_numbers[[.x]],
          paste0("_", ., "_"), .
        )
      ))
    )

  # fmt (part 2) ---------------------------------------------------------------
  tibble_calls[["fmt"]] <-
    map(
      seq_len(nrow(x$table_styling$fmt_fun)),
      ~ expr((!!expr(!!eval(parse_expr("gtsummary:::.apply_fmt_fun"))))(
        columns = !!x$table_styling$fmt_fun$column[[.x]],
        row_numbers = !!x$table_styling$fmt_fun$row_numbers[[.x]],
        fmt_fun = !!x$table_styling$fmt_fun$fmt_fun[[.x]],
        update_from = !!x$table_body
      ))
    )

  # fmt_missing ----------------------------------------------------------------
  if (isTRUE(fmt_missing)) {
    tibble_calls[["fmt_missing"]] <-
      map(
        seq_len(nrow(x$table_styling$fmt_missing)),
        ~expr(
          ifelse(
            dplyr::row_number() %in% !!x$table_styling$fmt_missing$row_numbers[.x] & is.na(!!sym(x$table_styling$fmt_missing$column[.x])),
            !!x$table_styling$fmt_missing$symbol[.x],
            !!sym(x$table_styling$fmt_missing$column[.x])
          )
        )
      ) %>%
      rlang::set_names(x$table_styling$fmt_missing$column) %>%
      {expr(dplyr::mutate(!!!.))} %>%
      list()
  }
  else {
    tibble_calls[["fmt_missing"]] <- list()
  }

  # cols_hide ------------------------------------------------------------------
  # cols_to_keep object created above in fmt section
  tibble_calls[["cols_hide"]] <-
    expr(dplyr::select(any_of("groupname_col"), !!!syms(.cols_to_show(x))))

  # cols_label -----------------------------------------------------------------
  if (col_labels) {
    df_col_labels <-
      dplyr::filter(x$table_styling$header, .data$hide == FALSE)

    tibble_calls[["cols_label"]] <-
      expr(rlang::set_names(!!df_col_labels$label))
  }

  tibble_calls
}

.apply_fmt_fun <- function(data, columns, row_numbers, fmt_fun, update_from) {
  # apply formatting functions
  df_updated <-
    update_from[row_numbers, columns, drop = FALSE] %>%
    purrr::map_dfc(~ fmt_fun(.x))

  # convert underlying column to character if updated col is character
  for (v in columns) {
    if (is.character(df_updated[[v]]) && !is.character(data[[v]])) {
      data[[v]] <- as.character(data[[v]])
    }
  }

  # udpate data and return
  data[row_numbers, columns, drop = FALSE] <- df_updated

  data
}
