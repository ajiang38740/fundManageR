

# utilities ---------------------------------------------------------------

#' Import RDA file
#'
#' @param file a file path
#'
#' @return
#' @export
#'
#' @examples
import_rda_file <-
  function(file = 'Desktop/fred/fred_series_tags.rda') {
    if (file %>% is_null()) {
      stop("Please enter a file path")
    }

    env <- new.env()
    nm <- load(file, env)[1]
    env[[nm]] %>%
      dplyr::as_data_frame()
  }



# dictionary --------------------------------------------------------------

parse_table_node <-
  function(table_nodes, x = 1) {
    has_series <-
      table_nodes %>%
      html_nodes('.series-meta a') %>%
      html_text() %>% length() > 0

    has_attributes <-
      table_nodes %>%
      html_nodes('.attributes') %>%
      html_text() %>% length() > 0

    has_tags <-
      table_nodes %>%
      html_nodes('.tag') %>%
      html_text() %>% length() > 0

    if (has_attributes) {
      attribute <-
        table_nodes %>%
        html_nodes('.attributes') %>%
        html_text() %>%
        str_to_upper()

      df_att <-
        data_frame(countItemPage = x, nameAttribute = attribute)
    } else {
      df_att <-
        data_frame(countItemPage = x)
    }

    if (has_series) {
      periods <-
        table_nodes %>%
        html_nodes('.series-meta a') %>%
        html_text() %>%
        str_replace_all('\n', '') %>%
        str_trim() %>%
        gsub("\\s+", " ", .)

      series_ids <-
        table_nodes %>%
        html_nodes('.series-meta a') %>%
        strip_series()

      dates <-
        table_nodes %>%
        html_nodes('.series-meta-dates') %>% html_text() %>%
        str_replace_all('\n', '') %>%
        str_trim() %>%
        gsub("\\s+", " ", .)

      df_series <-
        data_frame(
          countItemPage = x,
          nameItem = periods,
          idSeries = series_ids,
          dateUpdated = dates
        ) %>%
        mutate(countItem = 1:n())

      df_series <-
        df_series %>%
        nest(-countItemPage, .key = dataSeries)
    } else {
      df_series <-
        data_frame(countItemPage = x)
    }

    if (has_tags) {
      tags <-
        table_nodes %>%
        html_nodes('.tag') %>%
        html_text() %>%
        str_replace_all('\n', '') %>%
        str_trim() %>%
        gsub("\\s+", " ", .)

      df_tags <-
        data_frame(countItemPage = x, nameTag = tags) %>%
        mutate(countItem = 1:n())

      df_tags <-
        df_tags %>%
        nest(-countItemPage, .key = dataTags)
    } else {
      df_tags <-
        data_frame(countItemPage = x)
    }
    df <-
      df_att %>%
      left_join(df_series) %>%
      left_join(df_tags) %>%
      suppressMessages()
    closeAllConnections()
    return(df)
  }

strip_series <-
  function(x) {
    x %>%
      html_attr('href') %>%
      str_replace_all('/series/', '')
  }

get_fred_page_count <-
  function(base_url = "https://fred.stlouisfed.org/tags/series?t=&et=&pageID=1") {
    page <-
      base_url %>%
      read_html()

    last_page <-
      page %>%
      html_nodes('a:nth-child(8)') %>%
      html_text() %>%
      readr::parse_number()

    fred_pages <-
      seq(1, last_page)

    urls <-
      list("https://fred.stlouisfed.org/tags/series?t=&et=&pageID=",
           fred_pages,
           '&t=') %>%
      purrr::reduce(paste0)

    data_frame(numberPage = fred_pages, urlPage = urls)
  }

parse_fred_page <-
  function(url = "https://fred.stlouisfed.org/tags/series?t=&et=&pageID=1",
           return_message = TRUE) {
    page <-
      url %>%
      read_html()

    no_page <-
      url %>%
      str_split('&pageID=') %>%
      flatten_chr() %>%
      .[[2]] %>%
      readr::parse_number()

    item_count <-
      page %>%
      html_nodes('.series-title') %>%
      length()

    df_css_nodes <-
      data_frame(idRow = 1:item_count,
                 nodeNumber = c(2, seq(
                   5, by = 3, length.out = item_count - 1
                 )))
    df_items <-
      1:item_count %>%
      map_df(function(x) {
        table_no <-
          df_css_nodes %>%
          filter(idRow == x) %>%
          .$nodeNumber

        table_node_css <-
          list('.series-pager-attr:nth-child(', table_no, ') td') %>%
          purrr::reduce(paste0)

        page_no <-
          x

        table_nodes <-
          page %>%
          html_nodes(css = table_node_css)

        df_table <-
          table_nodes %>%
          parse_table_node(x = page_no)

        link_nodes <-
          page %>%
          html_nodes('.series-title') %>%
          .[[x]]

        series_id <-
          link_nodes %>%
          strip_series()

        series_name <-
          link_nodes %>%
          html_text() %>%
          str_to_upper()

        table_df <-
          data_frame(
            countItemPage = x,
            idSeries = series_id,
            nameSeries = series_name
          ) %>%
          mutate(
            urlFREDAPI = list(
              "https://fred.stlouisfed.org/graph/graph-data.php?id=",
              idSeries
            ) %>% purrr::reduce(paste0)
          ) %>%
          left_join(df_table) %>%
          suppressMessages()
        return(table_df)
      })

    df_items <-
      df_items %>%
      mutate(urlPage = url,
             idPage = no_page) %>%
      select(idPage, everything())

    if (return_message) {
      list("Parsed: ", url) %>%
        purrr::invoke(paste0, .) %>% message()

    }
    closeAllConnections()
    return(df_items)

  }

get_data_all_fred_series_ids <-
  function(return_message = TRUE,
           nest_data = TRUE,
           sleep = NULL) {
    parse_fred_page_safe <-
      purrr::possibly(parse_fred_page, data_frame())

    urls <-
      get_fred_page_count() %>%
      .$urlPage

    df_fred_ids <-
      urls %>%
      map_df(function(x) {
        parse_fred_page_safe(url = x, return_message = return_message)
      })

    df_fred_ids <-
      df_fred_ids %>%
      mutate(idItem = 1:n()) %>%
      select(idItem, everything())

    return(df_fred_ids)
  }

curl_url <-
  function(url = "https://github.com/abresler/FRED_Dictionaries/blob/master/data/fred_series_data.rda?raw=true") {
    con <-
      url %>%
      curl::curl()

    data <-
      con %>%
      import_rda_file()
    close(con)
    return(data)
  }

#' FRED Series IDs
#'
#' This function imports dictionaries for all possible FRED
#' series.  You can us this data to find series to search in the
#' \code{\link{get_data_fred_symbols}} function.
#'
#' This dictionary was indexed on January 22, 2017, please be aware
#' that there may be new series added to FRED since then.
#'
#' @param fred_file the type of dictionary you wish to import \itemize{
#' \item \code{NULL, All}:  returns all dictionary data in a nested data frame (default)
#' \item \code{series}: returns a data frame of the series name, id, and attributes
#' \item \code{tags}: returns a data frame of the series id and their corresponding search tag
#' \item \code{subindicies}: returns a data frame with the parent series and any sub-indicies if they have them
#' }
#' @param return_message \code{TRUE} return a message after data import
#'
#' @return a \code{data_frame}
#' @export
#' @family FRED
#' @family dictionary
#'
#' @examples
#'
#' get_dictionary_all_fred_series_ids(fred_file = NULL, return_message  = TRUE)
get_dictionary_all_fred_series_ids <-
  function(fred_file = NULL,
           return_message = TRUE) {
    fred_files <-
      c('all',  'series', 'tags', 'subindicies')

    if (!fred_file %>% purrr::is_null()) {
      fred_file <-
        fred_file %>%
        str_to_lower()

      if (!fred_file %in% fred_files) {
        stop(list(
          "FRED file names can only be\n",
          paste0(fred_files, collapse = '\n')
        ) %>% purrr::reduce(paste0))
      }
    }
    if (fred_file %>% purrr::is_null()) {
      data <-
        "https://github.com/abresler/FRED_Dictionaries/blob/master/data/fred_series_data.rda?raw=true" %>%
        curl_url()

      if (return_message) {
        message("Imported all FRED series data")
      }

      return(data)
    }

    if (fred_file == 'all') {
      data <-
        "https://github.com/abresler/FRED_Dictionaries/blob/master/data/fred_series_data.rda?raw=true" %>%
        curl_url()

      if (return_message) {
        message("Imported all FRED series data")
      }

      return(data)
    }

    if (fred_file == 'series') {
      data <-
        "https://github.com/abresler/FRED_Dictionaries/blob/master/data/fred_series_dictionary.rda?raw=true" %>%
        curl_url()
      if (return_message) {
        message("Imported all FRED series IDs")
      }
      return(data)
    }

    if (fred_file == 'tags') {
      data <-
        "https://github.com/abresler/FRED_Dictionaries/blob/master/data/fred_series_tags.rda?raw=true" %>%
        curl_url()
      if (return_message) {
        message("Imported all FRED series tags")
      }
      return(data)
    }

    if (fred_file == 'subindicies') {
      data <-
        "https://github.com/abresler/FRED_Dictionaries/blob/master/data/fred_series_subindicies.rda?raw=true" %>%
        curl_url()
      if (return_message) {
        message("Imported all FRED series subindicies")
      }
      return(data)
    }
  }

parse_fred_search <-
  function(urls, return_message = TRUE) {
    df <-
      data_frame()
    success <- function(res) {
      works <- res$status_code == 200
      if (works) {
        json_data <-
          res$url %>%
          jsonlite::fromJSON(simplifyDataFrame = TRUE)

        search_term <-
          res$url %>%
          str_split(pattern = '\\q=') %>%
          flatten() %>%
          .[[2]] %>%
          URLdecode()

        data <-
          json_data %>%
          as_data_frame() %>%
          purrr::set_names(
            c(
              "periodDataStart",
              "periodDataEnd",
              "periodUpdated",
              "descriptionData",
              "nameSeries",
              "frequencyDataReporting",
              "dataUnitMeasure",
              "descriptionSeasonality",
              "idSeries",
              "rankPopularity"
            )
          ) %>%
          mutate(termSearch = search_term) %>%
          select(termSearch,
                 idSeries,
                 nameSeries,
                 dataUnitMeasure,
                 everything())

        if (return_message) {
          list("Found ", nrow(data), ' FRED series for ', search_term) %>%
            purrr::reduce(paste0) %>%
            message()
        }
        rm(res)
        closeAllConnections()

        df <<-
          df %>%
          bind_rows(data)
      }
    }
    failure <- function(msg) {
      cat(sprintf("Fail: %s (%s)\n", res$url, msg))
    }
    urls %>%
      map(function(x) {
        curl_fetch_multi(url = x, success, failure)
      })
    multi_run()
    closeAllConnections()
    df
  }

#' FRED Terms Series IDs
#'
#' This function returns
#' matching FRED series ID for a given
#' search term.  The maximum number of results is
#' 100 for broader search use #' \code{\link{get_dictionary_all_fred_series_ids}} function.
#'
#' @param search_terms
#' @param return_message
#' @param nest_data
#'
#' @return
#' @export
#' @import dplyr lubridate tidyr purrr jsonlite curl
#' @examples
get_data_fred_terms_ids <-
  function(search_terms = c("China", "Property"),
           nest_data = FALSE,
           return_message = TRUE) {
    terms <-
      search_terms %>% map_chr(URLencode)

    json_urls <-
      list(
        'https://fred.stlouisfed.org/graph/ajax-requests.php?action=find_series&q=',
        terms
      ) %>%
      purrr::reduce(paste0)

    all_data <-
      json_urls %>%
      parse_fred_search(return_message = return_message)

    if (nest_data) {
      all_data <-
        all_data %>%
        nest(-termSearch, .key = dataResults)
    }

    return(all_data)
  }

# api ---------------------------------------------------------------------
generate_fred_symbol_url <-
  function(symbol = c('DGS10'),
           transformation = NULL) {
    df_transforms <-
      data_frame(
        nameTransformation = c(
          'default',
          'change',
          'change prior year',
          'percent change',
          'percent change prior year',
          'compounded rate of change',
          'continiously compounded rate of change',
          'continiously compounded annual rate of change',
          'natural log',
          'index'
        ),
        idTransformation = c(
          'lin',
          'chg',
          'ch1',
          'pch',
          'pc1',
          'pca',
          'cch',
          'cca',
          'log',
          'nbd'
        )
      )

    if (transformation %>% is_null()) {
      slug_transformation <-
        ''
    }

    if (!transformation %>% is_null()) {
      search_transformation <-
        transformation %>%
        str_to_lower()

      if (search_transformation %in% df_transforms$nameTransformation %>% sum(na.rm = TRUE) == 0) {
        slug_transformation <-
          ''
      }

      slug_transformation <-
        df_transforms %>%
        filter(nameTransformation %in% search_transformation) %>%
        .$idTransformation
    }
    urls_json <-
      list(
        "https://fred.stlouisfed.org/graph/graph-data.php?id=",
        symbol,
        '&transformation=',
        slug_transformation
      ) %>%
      purrr::reduce(paste0)
    return(urls_json)
  }

parse_json_fred <-
  function(url = "https://fred.stlouisfed.org/graph/graph-data.php?id=DGS10&transformation=",
           convert_date_time = TRUE,
           return_message = TRUE) {
    json_data <-
      url %>%
      jsonlite::fromJSON(simplifyDataFrame = TRUE)

    symbol <-
      url %>%
      str_split('id=') %>%
      flatten_chr() %>%
      .[[2]] %>%
      str_split('\\&') %>%
      flatten_chr() %>%
      .[[1]]

    series_name <-
      json_data$seriess$title %>%
      stringr::str_to_upper()

    frequency_data <-
      json_data$frequency %>% stringr::str_to_upper()

    series_type <-
      json_data$seriess$series$a$units %>%
      str_to_upper()

    is_percent <-
      series_type %>% stringr::str_detect('PERCENT')

    source <-
      json_data$chart$labels$subtitle %>%
      str_replace_all("Source: ", "")

    name_value <-
      json_data$chart$labels$left_axis

    df_data <-
      json_data$series$obs[[1]] %>%
      as_data_frame() %>%
      purrr::set_names(c('datetimeData', 'value')) %>%
      mutate(
        idSymbol = symbol,
        nameSeries = series_name,
        nameSource = source,
        nameTransformation = name_value,
        typeValue = series_type,
        frequencyData = frequency_data,
        urlData = url
      ) %>%
      select(idSymbol, nameSeries, nameTransformation, everything()) %>%
      mutate(
        datetimeData = as.POSIXct(datetimeData / 1000, origin = "1970-01-01", tz = "UTC"),
        dateData = datetimeData %>% as.Date()
      ) %>%
      select(dateData, everything())

    date_updated <-
      df_data$dateData %>% max()

    df_data <-
      df_data %>%
      mutate(dateUpdated = date_updated)

    if (convert_date_time) {
      df_data <-
        df_data %>%
        select(-datetimeData)
    } else {
      df_data <-
        df_data %>%
        select(-dateData)
    }

    if (is_percent) {
      df_data <-
        df_data %>%
        mutate(value = value / 100)
    }

    if (return_message) {
      list("Parsed: ", url) %>%
        purrr::invoke(paste0, .) %>%
        message()
    }
    return(df_data)
  }


get_data_fred_symbol <-
  function(symbol = 'DGS2',
           transformation = NULL,
           convert_date_time = TRUE,
           nest_data = FALSE,
           return_wide = FALSE,
           return_message = TRUE) {
    if (symbol %>% is_null()) {
      stop("Please enter a FRED series ID")
    }
    url <-
      generate_fred_symbol_url(symbol = symbol, transformation = transformation)
    parse_json_fred_safe <-
      purrr::possibly(parse_json_fred, data_frame())

    data <-
      parse_json_fred_safe(
        url = url,
        convert_date_time = convert_date_time,
        return_message = return_message
      )

    if (data %>% nrow() == 0) {
      stop(list("No data for ", symbol) %>% purrr::reduce(paste0),
           call. = TRUE)
    }

    if (return_message) {
      list(
        '\nReturned ',
        data %>% nrow() %>% formattable::comma(digits = 0),
        ' values for ',
        data$nameSeries %>% unique(),
        ' from ',
        data$dateData %>% min(na.rm = T),
        ' to ',
        data$dateData %>% max(na.rm = T)
      ) %>% purrr::reduce(paste0) %>% message()
    }

    return(data)
  }

#'  Federal Reserve Economic Data time series data_frame
#'
#'
#' This function returns a data for specified series from
#'  \href{https://fred.stlouisfed.org/}{FRED}.
#'
#' @param convert_date_time converts date from datetime to date form
#' @param symbols fred symbols to search, see \href{https://fred.stlouisfed.org/tags/series}{FRED symbols} for options
#' @param transformation a transformation on the index values \itemize{
#' \item \code{default}
#' \item \code{change}
#' \item \code{change prior year}
#' \item \code{percent change}
#' \item \code{percent change prior year}
#' \item \code{compounded rate of change}
#' \item \code{continiously compounded rate of change}
#' \item \code{continiously compounded annual rate of change}
#' \item \code{natural log}
#' \item \code{index}
#' }
#' @param return_wide \code{TRUE} return data in wide form
#' @param nest_data \code{TRUE} return nested data frame
#' @return a \code{data_frame}
#' @export
#' @import dplyr lubridate tidyr purrr jsonlite
#' @family index values
#' @examples
#' get_data_fred_symbols(symbols = c('DGS30','DGS10','DGS2'),
#' return_wide = TRUE, nest_data = FALSE)
#'
#' get_data_fred_symbols(
#' symbols = c("CPIAUCSL", "A191RL1Q225SBEA", "UNRATE"),
#' return_wide = FALSE,
#' convert_date_time = TRUE,
#' nest_data = TRUE
#' )
#'
get_data_fred_symbols <-
  function(symbols = c('DGS2', "DGS10", "DGS30"),
           transformations = c("default"),
           convert_date_time = TRUE,
           nest_data = TRUE,
           return_wide = FALSE,
           return_message = TRUE) {
    df_options <-
      expand.grid(symbol = symbols,
                  transform = transformations,
                  stringsAsFactors = FALSE) %>%
      as_data_frame()
    get_data_fred_symbol_safe <-
      purrr::possibly(get_data_fred_symbol, data_frame)

    all_data <-
      1:nrow(df_options) %>%
      map_df(function(x) {
        get_data_fred_symbol_safe(
          symbol = df_options$symbol[[x]],
          transformation = df_options$transform[[x]],
          convert_date_time = convert_date_time,
          return_message = return_message
        )
      })



    if (return_wide) {
      all_data <-
        all_data %>%
        select(-c(
          nameSeries,
          nameSource,
          typeValue,
          urlData,
          frequencyData,
          dateUpdated
        )) %>%
        spread(idSymbol, value)
      if (nest_data) {
        all_data <-
          all_data %>%
          nest(-nameTransformation, .key = dataFRED)
      }
    } else {
      if (nest_data) {
        all_data <-
          all_data %>%
          nest(
            -c(
              nameSeries,
              nameTransformation,
              nameSource,
              typeValue,
              frequencyData,
              dateUpdated,
              urlData
            ),
            .key = dataFRED
          )
      }
    }


    return(all_data)

  }


# plot --------------------------------------------------------------------

plot_time_series <-
  function(data,
           date_start = NULL,
           date_end = NULL,
           fred_data_transformation = NULL,
           transformations = c('mean', 'median', 'smooth'),
           plot_labels = FALSE,
           use_hrbr_theme = FALSE,
           interactive = FALSE) {

    transformation_options <- c('mean', 'median', 'smooth')

    wrong_transforms <-
      transformations %>%
      purrr::map_dbl(function(x){
        transformation_options %>% grep(x,.) %>% length()
      }) %>%
      sum(na.rm = TRUE) == 0


    if (wrong_transforms) {
      stop("Transformations can only be mean, median, or smooth")
    }

    if (!date_start %>% purrr::is_null()) {
      data <-
        data %>%
        filter(dateData >= date_start)
    }

    if (!date_end %>% purrr::is_null()) {
      data <-
        data %>%
        filter(dateData <= date_end)
    }

    series_name <-
      data$nameSeries %>% unique()

    split_series <-
      series_name %>% nchar() > 50

    if (split_series) {
      if (series_name %>% nchar > 50) {
        title <-
          series_name %>% str_split_fixed(pattern = '\\ ', 5) %>% as.character() %>% {
            paste0(paste0(.[1:4], collapse = ' '), '\n',.[5])
          }
      }
    } else {
      title <- series_name
    }

    sub_title <-
      list(
        'Data from ',
        data$dateData %>% min(na.rm = TRUE),
        ' to ',
        data$dateData %>% max(na.rm = TRUE),
        ' - FRED Series ID: ', data$idSymbol %>% unique()
      ) %>% purrr::reduce(paste0)

    type <-
      data$typeValue %>% unique()

    is_percent <- type %>% stringr::str_detect('PERCENT')

    if (!fred_data_transformation %>% is_null()) {
      sub_title <-
        list(sub_title, '\nFRED Transformation of ', fred_data_transformation) %>%
        purrr::reduce(paste0)
    }

    if ('nameSource' %in% names(data)) {
      caption_text <-
        list("Source data from ",data$nameSource %>% unique, '\n', 'via FRED from fundManageR') %>%
        purrr::reduce(paste0)
    } else {
      caption_text <-
        "Sourced from FRED via fundManageR"
    }

    plot <-
      data %>%
      ggplot(aes(x = dateData, y = value)) +
      theme_minimal() +
      geom_line(color = "#00B0F0", size = .5) +
      geom_area(fill = "#00B0F0",
                alpha = 0.25,
                color = NA) +
      theme(
        panel.background = element_rect(fill = "#fffff8", color = NA),
        plot.background = element_rect(fill = "#fffff8", color = NA)
      ) +
      labs(
        x = NULL,
        y = type,
        title = title,
        subtitle = sub_title,
        caption = caption_text
      ) +
      scale_x_date(expand = c(0, 0))

    if (use_hrbr_theme) {
      check_for_hrb()
      plot <-
        plot +
        hrbrthemes::theme_ipsum_rc(grid = "XY")

      if (is_percent) {
        plot <-
          plot +
          hrbrthemes::scale_y_percent()
      } else {
        plot <-
          plot +
          hrbrthemes::scale_y_comma()
      }

    }

    include_mean <-
      'mean' %in% (transformations %>% str_to_lower())

    include_median <-
      'median' %in% (transformations %>% str_to_lower())

    include_smooth <-
      'smooth' %in% (transformations %>% str_to_lower())

    if (include_mean) {
      mean_value <-
        data$value %>% mean(na.rm = TRUE)
      plot <-
        plot +
        geom_hline(yintercept = mean_value,
                   colour = "#ff0f0f",
                   linetype = "dashed")

      if (plot_labels) {
        mean_label <-
          list("Mean: ", digits(mean_value, 3)) %>% purrr::reduce(paste0)

        plot <-
          plot +
          annotate("text", x = mean(data$dateData, na.rm = TRUE), y = mean_value * 1.75, label = mean_label,
                   colour = "#ff0f0f")

      }
    }

    if (include_median) {
      median_value <- data$value %>% median(na.rm = TRUE)
      plot <-
        plot +
        geom_hline(
          yintercept = median_value,
          colour = "#6600ff",
          linetype = "dashed"
        )
      if (plot_labels) {
        median_label <-
          list("Median: ", digits(median_value, 3)) %>% purrr::reduce(paste0)

      plot <-
        plot +
        annotate("text", x = mean(data$dateData, na.rm = TRUE), y = median_value * 1.5, label = median_label,
                 colour = "#6600ff")

      }
    }

    if (include_smooth) {
      plot <-
        plot +
        geom_smooth(
          colour = "#000000",
          method = 'auto',
          span = .3,
          size = .5,
          alpha = 0.5
        ) %>%
        suppressWarnings() %>%
        suppressMessages()
    }


    if (interactive) {
      plot_title <-
        list(title, '\n', sub_title, '\n', caption_text) %>% purrr::reduce(paste0)
      plot <-
        plot +
        labs(
          x = NULL,
          y = type,
          title = plot_title,
          subtitle = NULL,
          caption = NULL
        ) +
        theme(plot.title = element_text(size = 8))
      plot <-
        plotly::ggplotly(plot)
    }
    return(plot)
  }

  check_for_hrb <- function() {
  df_pkgs <-
    installed.packages() %>%
    dplyr::as_data_frame()

  missing_hrb_themes <-
    df_pkgs %>%
    filter(Package %>% stringr::str_detect('hrbrthemes')) %>% nrow() == 0

  if (missing_hrb_themes) {
    stop(list("Missing hrbrthemes which is needed to plot please install using devtools::install_github('hrbrmstr/hrbrthemes')\nAlso make sure to download Roboto font at https://fonts.google.com/specimen/Roboto") %>%
      purrr::reduce(paste0))
  }
}

#' Plot any FRED time series
#'
#' @param series_id any FRED series ID
#' @param use_random if \code{TRUE} a random FRED series ID is chosen
#' @param fred_data_transformations Any FRED transformation \itemize{
#' \item \code{default}
#' \item \code{change}
#' \item \code{change prior year}
#' \item \code{percent change}
#' \item \code{percent change prior year}
#' \item \code{compounded rate of change}
#' \item \code{continiously compounded rate of change}
#' \item \code{continiously compounded annual rate of change}
#' \item \code{natural log}
#' \item \code{index}
#' }
#' @param date_start data start date, if \code{NULL} all chosen
#' @param date_end data end date
#' @param use_hrbr_theme uses Bob Rudis theme
#' @param plot_transformations Any plot transformations you wish to apply \itemize{
#' \code{median}: Median value
#' \code{mean}: Mean value
#' \code{smooth}: GAM smooth line
#' }
#' @param plot_labels if \code{TRUE} text of any plot transformations are plotted
#' @param interactive if \code{TRUE} visualization turned into an interactive plotly widget
#' @import purrr jsonlite dplyr stringr ggplot2 tidyr
#' @importFrom plotly ggplotly
#' @return if \code{interactive} a plotly htmlwidget or else a static ggplot2 visualization
#' @export
#'
#' @examples
#'

visualize_fred_time_series <-
  function(series_id = "DGS2",
           use_random = FALSE,
           fred_data_transformation = NULL,
           date_start = NULL,
           date_end = NULL,
           plot_transformations = c('mean', 'median', 'smooth'),
           use_hrbr_theme = FALSE,
           plot_labels = FALSE,
           interactive = FALSE) {

    if (use_random) {
    if (!'df_fred_symbols' %>% exists()) {
      "Asssigning FRED symbols to your environment as df_fred_symbols" %>% message()
      assign(x = 'df_fred_symbols', value = eval(get_dictionary_all_fred_series_ids()), envir = .GlobalEnv)
    }
      "\nBuckle your seatbelts we are plotting one random time series from the nearly 400,000 available on FRED" %>% message()
      series_id <- df_fred_symbols %>% sample_n(1) %>% .$idSeries
    }

    fred_df <-
      get_data_fred_symbol(symbol = series_id, transformation = fred_data_transformation, nest_data = FALSE, return_wide = FALSE) %>%
      suppressWarnings() %>%
      suppressMessages()

    plot <-
      plot_time_series(
      data = fred_df,
      date_start = date_start,
      date_end = date_end,
      fred_data_transformation = fred_data_transformation,
      transformations = plot_transformations,
      use_hrbr_theme = use_hrbr_theme,
      plot_labels = plot_labels,
      interactive = interactive
    )
    plot
  }
