states <- base::unique(tidycensus::fips_codes$state)[1:51]

tracts_data <- purrr::map(states, function(state) {
      tidycensus::get_acs(
      geography = "tract",
      state = state,
      year = 2020,
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
    year = 2020,
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
    year = 2020,
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
    tigris::tracts(year = 2020, state = s)
  }) |>
  purrr::list_rbind() |>
  sf::st_as_sf() |>
  dplyr::select(c(GEOID)) |>
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

tracts_geom |>
  dplyr::left_join(results, by = c("geoid" = "geoid")) |>
  sf::st_write("tracts.shp", delete_dsn = TRUE)





