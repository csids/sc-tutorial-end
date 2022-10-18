# **** action **** ----
#' weather_download_and_import_rawdata (action)
#' @param data Data
#' @param argset Argset
#' @param schema DB Schema
#' @export
weather_download_and_import_rawdata_action <- function(data, argset, schema) {
  # sc::tm_run_task("weather_download_and_import_rawdata", run_as_rstudio_job_loading_from_devtools = TRUE)

  if (plnr::is_run_directly()) {
    # sc::tm_get_plans_argsets_as_dt("weather_download_and_import_rawdata")

    index_plan <- 1
    index_analysis <- 1

    data <- sc::tm_get_data("weather_download_and_import_rawdata", index_plan = index_plan)
    argset <- sc::tm_get_argset("weather_download_and_import_rawdata", index_plan = index_plan, index_analysis = index_analysis)
    schema <- sc::tm_get_schema("weather_download_and_import_rawdata")
  }

  # special case that runs before everything
  if (argset$first_analysis == TRUE) {

  }

  a <- data$data$properties$timeseries
  res <- vector("list", length=length(a) - 1)
  for(i in seq_along(res)){
    # i = 1
    time_from <- a[[i]]$time
    if("next_1_hours" %in% names(a[[i]]$data)){
      time_var <- "next_1_hours"
    } else {
      time_var <- "next_6_hours"
    }
    temp <- a[[i]]$data[["instant"]]$details$air_temperature
    precip <- a[[i]]$data[[time_var]]$details$precipitation_amount

    res[[i]] <- data.frame(
      time_from = as.character(time_from),
      temp = as.numeric(temp),
      precip = as.numeric(precip)
    )
  }

  res <- rbindlist(res)
  res <- res[stringr::str_sub(time_from, 12, 13) %in% c("00", "06", "12", "18")]
  res[, date := as.Date(stringr::str_sub(time_from, 1, 10))]
  res <- res[
    ,
    .(
      temp_max = max(temp),
      temp_min = min(temp),
      precip = sum(precip)
    ),
    keyby = .(date)
  ]

  # we look at the downloaded data
  # res

  # we now need to format it
  res[, granularity_time := "day"]
  res[, sex := "total"]
  res[, age := "total"]
  res[, location_code := argset$location_code]

  # fill in missing structural variables
  sc::fill_in_missing_v8(res, border = 2020)

  # we look at the downloaded data
  # res

  # put data in db table
  schema$anon_example_weather_rawdata$insert_data(res)

  # special case that runs after everything
  if (argset$last_analysis == TRUE) {

  }
}

# **** data_selector **** ----
#' weather_download_and_import_rawdata (data selector)
#' @param argset Argset
#' @param schema DB Schema
#' @export
weather_download_and_import_rawdata_data_selector <- function(argset, schema) {
  if (plnr::is_run_directly()) {
    # sc::tm_get_plans_argsets_as_dt("weather_download_and_import_rawdata")

    index_plan <- 1

    argset <- sc::tm_get_argset("weather_download_and_import_rawdata", index_plan = index_plan)
    schema <- sc::tm_get_schema("weather_download_and_import_rawdata")
  }

  # find the mid lat/long for the specified location_code
  gps <- fhimaps::norway_lau2_map_b2020_default_dt[location_code == argset$location_code,.(
    lat = mean(lat),
    long = mean(long)
  )]

  # download the forecast for the specified location_code
  d <- httr::GET(glue::glue("https://api.met.no/weatherapi/locationforecast/2.0/complete?lat={gps$lat}&lon={gps$long}"))
  d <- httr::content(d)

  # The variable returned must be a named list
  retval <- list(
    "data" = d
  )

  retval
}

# **** functions **** ----
