YEAR <- 2020
DATA_PATH <- 'data'

states <- base::unique(tidycensus::fips_codes$state)[1:51]

tracts_data <- purrr::map(states, function(state) {
      tidycensus::get_acs(
      geography = "tract",
      state = state,
      year = YEAR,
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
    high_pov = pov_rate > 20,
    geoid_state = stringr::str_sub(geoid, 1, 2),
  ) |>
  dplyr::rename(
    mfi = B19113_001
  ) |>
  dplyr::select(-c(B17001_002, B17001_001))

states_data <- tidycensus::get_acs(
    geography = "state",
    year = YEAR,
    variables = "B19113_001",
    geometry = FALSE
  )|>
  dplyr::rename_with(tolower) |>
  dplyr::rename(
    mfi_state = estimate
  ) |>
  dplyr::select(geoid, name, mfi_state)

metros_data <- tidycensus::get_acs(
    geography = "cbsa",
    year = YEAR,
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

tracts_geom <- purrr::map(states, function(s) {
    tigris::tracts(year = YEAR, state = s)
  }) |>
  purrr::list_rbind() |>
  sf::st_as_sf() |>
  dplyr::select(c(GEOID)) |>
  dplyr::rename_with(tolower)

tracts_geom_2010 <- purrr::map(states, function(s) {
  tigris::tracts(year = 2010, state = s)
}) |>
  purrr::list_rbind() |>
  sf::st_as_sf() |>
  dplyr::select(c(GEOID10)) |>
  dplyr::rename(
    geoid = GEOID10
  )
  dplyr::rename_with(tolower)

metro_tracts <- tracts_geom |>
  sf::st_join(
    dplyr::select(metros, mfi_metro), 
    join = sf::st_within, 
    left = FALSE
    ) |>
  sf::st_drop_geometry()

results <- tracts_data |>
  dplyr::left_join(
    states_data, by = c("geoid_state" = "geoid")
  ) |>
  dplyr::left_join(
    metro_tracts, by = c("geoid" = "geoid")
  ) |>
  dplyr::mutate(
    inc_ratio = mfi / base::pmax(mfi_state, mfi_metro, na.rm = TRUE),
    inc_low = inc_pct <= 0.8
  )

tigris::counties(year = YEAR) |>
  sf::st_write(base::file.path(DATA_PATH, "counties.shp"), delete_dsn = TRUE)

tracts_geom |>
  # dplyr::left_join(results, by = c("geoid" = "geoid")) |>
  sf::st_write(base::file.path(DATA_PATH, "tracts.shp"), delete_dsn = TRUE)

tracts_geom_2010 |>
  # dplyr::left_join(results, by = c("geoid" = "geoid")) |>
  sf::st_write(base::file.path(DATA_PATH, "tracts_2010.shp"), delete_dsn = TRUE)

tigris::native_areas(year = YEAR) |>
  sf::st_write(base::file.path(DATA_PATH, "native_lands.shp"), delete_dsn = TRUE)