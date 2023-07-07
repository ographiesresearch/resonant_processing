YEAR <- 2020
DATA_PATH <- 'data'
STATES <- base::unique(tidycensus::fips_codes$state)[1:51]

ct_all_states_data <- function(year = YEAR, states = STATES) {
  states |>
    purrr::map(function(s) {
      tidycensus::get_acs(
        geography = "tract",
        state = s,
        year = year,
        variables = c("B17001_001", "B17001_002", "B19113_001"),
        geometry = FALSE
      )
    }) |>
    purrr::list_rbind() |>
    dplyr::rename_with(tolower) |>
    tidyr::pivot_wider(
      id_cols = geoid,
      names_from = variable,
      values_from = estimate
    ) |>
    dplyr::mutate(
      pov_rate = B17001_002 / B17001_001 * 100,
      pov_rate_hi = pov_rate > 20,
      geoid_state = stringr::str_sub(geoid, 1, 2),
    ) |>
    dplyr::rename(
      mfi = B19113_001
    ) |>
    dplyr::select(-c(B17001_002, B17001_001))
}

mfi_state <- function(year = YEAR) {
  df <- tidycensus::get_acs(
      geography = "state",
      year = year,
      variables = "B19113_001",
      geometry = FALSE
    )|>
    dplyr::rename_with(tolower) |>
    dplyr::rename(
      mfi_state = estimate
    ) |>
    dplyr::select(geoid, name, mfi_state)
}

mfi_metros <- function(year = YEAR) {
  tidycensus::get_acs(
      geography = "cbsa",
      year = year,
      variables = "B19113_001",
      geometry = TRUE
    ) |>
    dplyr::rename_with(tolower) |>
    dplyr::rename(
      mfi_metro = estimate
    ) |>
    dplyr::select(geoid, name, mfi_metro) |>
    dplyr::filter(
      stringr::str_detect(name, "Metro Area")
    )
}

ct_all_states_geom <- function(year = YEAR, states = STATES) {
  df <- purrr::map(states, function(s) {
      tigris::tracts(year = year, state = s)
    }) |>
    purrr::list_rbind() |>
    sf::st_as_sf() |>
    dplyr::rename_with(tolower)
  if (year == 2010) {
    df |>
      dplyr::rename(
        geoid = geoid10
      )
  }
  df |> 
    dplyr::select(c(geoid))
}

run <- function(year = YEAR, states = STATES, spatial_format = "gpkg") {
  message("Starting Census Data Download Process")
  message("=====================================")
  message("Downloading and writing census tract geometries for all states...")
  ct_geom <- ct_all_states_geom(year, states) |>
    sf::st_write(
      base::file.path(
        DATA_PATH, 
        stringr::str_c(
          "tracts", 
          spatial_format,
          sep="."
        )
      ), 
      delete_dsn = TRUE
    )
  
  message("Determining which census tracts lie within Metropolitan Statistical Areas...")
  metro_tracts <- ct_geom |>
    sf::st_join(
      mfi_metros(year),
      join = sf::st_within, 
      left = FALSE
    ) |>
    sf::st_drop_geometry()
  
  rm(ct_geom)
  
  message("Calculating variables of interest...")
  ct_all_states_data(year, states) |>
    dplyr::left_join(
      mfi_state(year), by = c("geoid_state" = "geoid")
    ) |>
    dplyr::left_join(
      metro_tracts, by = c("geoid" = "geoid")
    ) |>
    dplyr::mutate(
      inc_ratio = mfi / base::pmax(mfi_state, mfi_metro, na.rm = TRUE),
      inc_ratio_low = inc_pct <= 0.8,
      low_inc = inc_ratio_low | pov_rate_hi
    ) |>
    readr::write_csv(base::file.path(DATA_PATH, "low_income.csv"))
  
  rm(metro_tracts)
  
  message("Downloading and writing counties...")
  tigris::counties(year = YEAR) |>
    sf::st_write(
      base::file.path(
        DATA_PATH, 
        stringr::str_c(
          "counties", 
          spatial_format,
          sep="."
          )
        ), 
      delete_dsn = TRUE
      )
  
  message("Downloading and writing 2010 census tract geometries...")
  ct_all_states_geom(year = 2010, states) |>
    sf::st_write(
      base::file.path(
        DATA_PATH, 
        stringr::str_c(
          "tracts_2010", 
          spatial_format,
          sep="."
        )
      ), 
      delete_dsn = TRUE
    )
  
  message("Downloading and writing native lands...")
  tigris::native_areas(year = YEAR) |>
    sf::st_write(
      base::file.path(
        DATA_PATH, 
        stringr::str_c(
          "native_lands", 
          spatial_format,
          sep="."
        )
      ), 
      delete_dsn = TRUE
    )
  message("Done!")
  return(invisible(NULL))
}

if (!interactive()) {
  run()
}