YEAR <- 2020
DATA_PATH <- 'data'
STATES <- base::unique(tidycensus::fips_codes$state)[1:51]

ct_all_states_data <- function(year = YEAR, states = STATES) {
    tidycensus::get_acs(
      geography = "tract",
      state = states,
      year = year,
      variables = c("B17001_001", "B17001_002", "B19113_001"),
      geometry = FALSE
    ) |>
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
      name_state = name,
      mfi_state = estimate
    ) |>
    dplyr::select(geoid, name_state, mfi_state)
}

mfi_msas <- function(year = YEAR) {
  tidycensus::get_acs(
      geography = "cbsa",
      year = year,
      variables = "B19113_001",
      geometry = TRUE
    ) |>
    dplyr::rename_with(tolower) |>
    # See this issue: https://github.com/r-spatial/sf/issues/1472
    dplyr::mutate() |>
    dplyr::rename(
      name_msa  = name,
      mfi_msa = estimate
    ) |>
    dplyr::select(geoid, name_msa, mfi_msa) |>
    dplyr::filter(
      stringr::str_detect(name_msa, "Metro Area")
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
    df <- df |>
      dplyr::select(-c(statefp, countyfp)) |>
      dplyr::rename(
        geoid = geoid10,
        statefp = statefp10,
        countyfp = countyfp10
      )
  }
  df |> 
    dplyr::mutate(
      countyfp = stringr::str_c(statefp, countyfp)
    ) |>
    dplyr::select(c(statefp, countyfp, geoid)) |>
    sf::st_set_geometry('geometry') |>
    sf::st_cast('MULTIPOLYGON')
}

doe_download <- function(file) {
  temp <- base::tempfile(fileext = ".zip")
  
  if (file == "coal") {
    string <- "28a8eb09-619e-49e5-8ae3-6ddd3969e845"
    file <- "IRA_Coal_Closure_Energy_Comm_2023v2/Coal_Closure_Energy_Communities_2023v2.csv"
  } else if (file == "energy") {
    string <- "b736a14f-12a7-4b9f-8f6d-236aa3a84867"
    file <- "MSA_NMSA_FEE_EC_Status_2023v2/MSA_NMSA_FFE_EC_2023v2.csv"
  }
  
  httr::GET(
    paste0("https://edx.netl.doe.gov/resource/", string, "/download?authorized=True"), 
    httr::write_disk(temp, overwrite = TRUE)
  )
  
  readr::read_csv(
    base::unzip(
      temp,
      file
    ),
    show_col_types = FALSE
  )
}

run <- function(year = YEAR, states = STATES, spatial_format = "gpkg") {
  message("Starting Census Data Download Process")
  message("=====================================")
  message("Downloading and writing census tract geometries for all states...")
  ct_geom <- ct_all_states_geom(year, states) |>
    dplyr::mutate(
      year = year
    ) |>
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
  msa_ct <- ct_geom |>
    sf::st_join(
      dplyr::select(mfi_msas(year), -c(geoid)),
      join = sf::st_within,
      left = FALSE
    ) |>
    sf::st_drop_geometry()
  
  message("Calculating low-income status...")
  ct_li <- ct_all_states_data(year, states) |>
    dplyr::left_join(
      mfi_state(year), by = c("geoid_state" = "geoid")
    ) |>
    dplyr::left_join(
      msa_ct, by = c("geoid" = "geoid")
    ) |>
    dplyr::mutate(
      inc_ratio = mfi / base::pmax(mfi_state, mfi_msa, na.rm = TRUE),
      inc_ratio_low = inc_ratio <= 0.8,
      low_inc = inc_ratio_low | pov_rate_hi
    ) |>
    dplyr::select(
      geoid,
      mfi, 
      pov_rate, 
      pov_rate_hi, 
      mfi_state, 
      name_msa, 
      mfi_msa,
      inc_ratio,
      inc_ratio_low, 
      low_inc) |>
    readr::write_csv(base::file.path(DATA_PATH, "low_income.csv"))
  
  message("Fetching coal closure communities...")
  ct_coal <- doe_download("coal") |> 
    dplyr::rename(
      geoid = geoid_tract_2020, 
      mine = Mine_Closure, 
      gen = Generator_Closure, 
      adj = Adjacent_to_Closure
      ) |> 
    dplyr::select(geoid, mine, gen, adj)
  
  message("Fetching energy communities...")
  cty_energy <- doe_download("energy") |>
    dplyr::rename(
      countyfp = geoid_cty_2020,
      county_name = county_name_2020,
      ffe = FEE_qual_status,
      ec = EC_qual_status
    ) |>
    dplyr::select(countyfp, ffe, ec)
  
  message("Fetching persistent poverty counties...")
  cty_pp <- readr::read_csv(
      "https://www.ers.usda.gov/webdocs/DataFiles/48652/2015CountyTypologyCodes.csv"
    ) |>
    dplyr::rename(
      countyfp = FIPStxt,
      pp = Persistent_Poverty_2013
    ) |>
    dplyr::mutate(
      countyfp = stringr::str_pad(countyfp, 5, side = "left", pad = "0")
    ) |>
    dplyr::select(countyfp, pp) 
  
  message("Downloading and writing native lands...")
  native_areas <- tigris::native_areas(year = year) |>
    dplyr::rename(
      geoid = GEOID,
      name = NAME,
      name_long = NAMELSAD
    ) |>
    dplyr::filter(
      stringr::str_detect(MTFCC, "^G21[0237]") |
        (
          stringr::str_detect(MTFCC, "^G214") & 
          (name %in% c('Choctaw', 'Cherokee', 'Seminole', 'Chickasaw', 'Creek'))
        )
    ) |>
    dplyr::select(geoid, name_long) |>
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
  
  ct_joined <- ct_geom |> 
    dplyr::left_join(ct_li) |>
    dplyr::left_join(ct_coal) |>
    dplyr::left_join(cty_energy) |> 
    dplyr::mutate(
      dplyr::across(c(ffe, ec, mine, gen, adj), ~ dplyr::case_when(
        . == "Yes" ~ TRUE,
        . == "No" ~ FALSE,
        is.na(.) ~ FALSE
      ))
    ) |> 
    dplyr::rowwise() |>
    dplyr::mutate(
      nrg_comm = ffe | ec | mine | gen, adj
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(nrg_comm | low_inc) |>
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
  
  message("Fetching environmental burden data from the CEJST...")
  ct_cejst <- readr::read_csv(
    "https://static-data-screeningtool.geoplatform.gov/data-versions/1.0/data/score/downloadable/1.0-communities.csv"
    ) |>
    dplyr::rename(
      geoid = `Census tract 2010 ID`,
      nrg_burd = `Energy burden`,
      nrg_burd_p = `Energy burden (percentile)`,
      pm25 = `PM2.5 in the air`,
      pm25_p = `PM2.5 in the air (percentile)`,
      pov = `Adjusted percent of individuals below 200% Federal Poverty Line`,
      pov_p = `Adjusted percent of individuals below 200% Federal Poverty Line (percentile)`
    ) |>
    dplyr::select(geoid, nrg_burd, nrg_burd_p, pm25, pm25_p, pov, pov_p) |>
    dplyr::mutate(
      nrg_burd_b = nrg_burd_p > 90,
      pm25_b = pm25_p > 90,
      pov_b = pov_p > 0.65,
      nrg_disadv = (nrg_burd_b | pm25_b) & pov_b
    )
  
  
  message("Downloading and writing 2010 census tract geometries...")
  ct_joined_2010 <- ct_all_states_geom(year = 2010, states) |>
    dplyr::mutate(
      year = 2010
    ) |>
    dplyr::left_join(cty_pp) |> 
    dplyr::left_join(ct_cejst) |>
    dplyr::mutate(
      pp = dplyr::case_when(
        is.na(pp) ~ FALSE,
        TRUE ~ as.logical(pp)
      )
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      adder_b = pp | nrg_disadv,
      adder_count = base::sum(pp, nrg_disadv, na.rm = TRUE)
    ) |> 
    dplyr::ungroup() |>
    dplyr::filter(adder_b) |>
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
  
  rm(msa_ct)
  
  message("Done!")
  return(invisible(NULL))
}

if (!interactive()) {
  run()
}