YEAR <- 2020
DATA_PATH <- 'data'
RSLT_GPKG <- 'results.gpkg'
STATES <- base::unique(tidycensus::fips_codes$state)[1:51]
CRS <- sf::st_crs(3857)

tidycensus::census_api_key(Sys.getenv("CENSUS_KEY"))

ct_data <- function(year = YEAR, states = STATES) {
  #' Downloads data for application at the census tract scale.
  #' 
  #' @param year Either 2010 or 2020.
  #' @param states List of states.
  #' @export
  
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
    pov_rat = B17001_002 / B17001_001 * 100,
    pov_rat_hi = pov_rat > 20,
    geoid_state = stringr::str_sub(geoid, 1, 2),
  ) |>
  dplyr::rename(
    mfi = B19113_001
  ) |>
  dplyr::select(-c(B17001_002, B17001_001))
}



mfi_state <- function(year = YEAR) {
  #' Downloads states with associated Median Family 
  #' Income (MFI) for given year.
  #' 
  #' @param year Either 2010 or 2020.
  
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

mfi_msas <- function(year=YEAR, crs=CRS) {
  #' Downloads metros with associated Median Family 
  #' Income (MFI) for given year.
  #' 
  #' @param year Either 2010 or 2020.
  #' @param crs Either `st_crs()` object or EPSG.
  
  message("Downloading CBSA geometries...")
  tidycensus::get_acs(
      geography = "cbsa",
      year = year,
      variables = "B19113_001",
      geometry = TRUE,
      cb = TRUE
    ) |>
    dplyr::rename_with(tolower) |>
    # See this issue: https://github.com/r-spatial/sf/issues/1472
    dplyr::mutate() |>
    dplyr::rename(
      name_msa  = name,
      mfi_msa = estimate
    ) |>
    dplyr::filter(
      stringr::str_detect(name_msa, "Metro Area")
    ) |>
    sf::st_transform(crs) |>
    dplyr::select(name_msa, mfi_msa)
}

cty_names <- function(year = YEAR) {
  #' Downloads county names and FIPS codes.
  #' 
  #' @param year Census year.
  
  df <- tigris::counties(cb=TRUE, year=year) |>
    sf::st_drop_geometry() |>
    dplyr::rename_with(tolower) |>
    dplyr::rename(
      cty_name = name
    )
  
  if (year == 2010) {
    df <- df |>
      dplyr::mutate(
        geoid = stringr::str_c(state, county)
      )
  }
  
  df |>
    dplyr::select(geoid, cty_name)
}

ct_geometry <- function(year = YEAR, states = STATES, crs = CRS) {
  #' Downloads census tract geometry for given states.
  #' 
  #' @param year Either 2010 or 2020.
  #' @param states List of states to download.
  #' @param crs Either `st_crs()` object or EPSG.
  #' @export
  
  message("Downloading and writing census tract geometries for all states...")
  df <- purrr::map(states, function(s) {
      tigris::tracts(year = year, state = s, cb=TRUE)
    }) |>
    purrr::list_rbind() |>
    sf::st_as_sf() |>
    dplyr::rename_with(tolower)
  if (year == 2010) {
    df <- df |>
      dplyr::mutate(
        geoid = stringr::str_c(statefp, countyfp, tract)
      )
  }
  df |> 
    dplyr::mutate(
      countyfp = stringr::str_c(statefp, countyfp)
    ) |>
    dplyr::select(c(statefp, countyfp, geoid)) |>
    sf::st_set_geometry('geometry') |>
    sf::st_cast('MULTIPOLYGON') |>
    sf::st_transform(crs) |>
    dplyr::mutate(
      year = YEAR
    ) |>
    dplyr::left_join(
      cty_names(year), by = c("countyfp" = "geoid")
    )
}

doe_download <- function(file) {
  #' Downloads and reads coal closure and fossil employment from the DOE.
  #' 
  #' @param file String, either "coal" or "energy".
  #' @export
  
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
    temp,
    show_col_types = FALSE
  )
}

coal_download <- function() {
  message("Fetching coal closure communities...")
  doe_download("coal") |> 
    dplyr::select(
      geoid = geoid_tract_2020, 
      mine = Mine_Closure, 
      gen = Generator_Closure, 
      adj = Adjacent_to_Closure
    )
}

energy_download <- function() {
  message("Fetching energy communities...")
  doe_download("energy") |> 
    dplyr::select(
      countyfp = geoid_cty_2020,
      ffe = FEE_qual_status,
      ec = EC_qual_status
    )
}

cejst_download <- function() {
  message("Fetching environmental burden data from the CEJST...")
  ct_cejst <- readr::read_csv(
      "https://static-data-screeningtool.geoplatform.gov/data-versions/1.0/data/score/downloadable/1.0-communities.csv",
      show_col_types = FALSE
    ) |>
    dplyr::select(
      geoid = `Census tract 2010 ID`,
      nrg_burd = `Energy burden`,
      nrg_burd_p = `Energy burden (percentile)`,
      pm25 = `PM2.5 in the air`,
      pm25_p = `PM2.5 in the air (percentile)`,
      pov = `Adjusted percent of individuals below 200% Federal Poverty Line`,
      pov_p = `Adjusted percent of individuals below 200% Federal Poverty Line (percentile)`
    ) |>
    dplyr::mutate(
      nrg_burd_b = nrg_burd_p >= 90,
      pm25_b = pm25_p >= 90,
      pov_b = pov_p >= 0.65,
      nrg_disadv = (nrg_burd_b | pm25_b) & pov_b
    )
}

pp_download <- function() {
  message("Fetching persistent poverty counties...")
  readr::read_csv(
    "https://www.ers.usda.gov/webdocs/DataFiles/48652/2015CountyTypologyCodes.csv",
    show_col_types = FALSE
  ) |>
    dplyr::rename(
      countyfp = FIPStxt,
      pp = Persistent_Poverty_2013
    ) |>
    dplyr::mutate(
      countyfp = stringr::str_pad(countyfp, 5, side = "left", pad = "0")
    ) |>
    dplyr::select(countyfp, pp) 
}

native_lands <- function() {
  message("Downloading native lands...")
  tigris::native_areas(YEAR) |>
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
    sf::st_transform(CRS) |>
    dplyr::select(geoid, name_long)
}

ct_low_inc_status <- function(ct_sf, year = YEAR, states = STATES) {
  ct_data(year, states) |>
    dplyr::left_join(
      mfi_state(year), 
      by = c("geoid_state" = "geoid")
    ) |>
    dplyr::left_join(
      mfi_msas(year) |>
        sf::st_join(
          sf::st_point_on_surface(ct_sf),
          join = sf::st_contains,
          left = FALSE
        ) |>
        sf::st_drop_geometry(), 
      by = c("geoid" = "geoid")
    ) |>
    dplyr::mutate(
      mfi_region = base::pmax(mfi_state, mfi_msa, na.rm = TRUE),
      regiontype = dplyr::case_when(
        mfi_region == mfi_state ~ "state",
        mfi_region == mfi_msa ~ "msa"
      ),
      inc_rat = mfi / mfi_region,
      inc_rat_lo = inc_rat <= 0.8,
      low_inc = inc_rat_lo | pov_rat_hi
    ) |>
    dplyr::select(
      geoid,
      mfi, 
      pov_rat, 
      pov_rat_hi, 
      mfi_region, 
      regiontype,
      name_state,
      name_msa,
      inc_rat,
      inc_rat_lo, 
      low_inc
    )
}

run <- function(spatial_format = "gpkg") {
  ct_geom <- ct_geometry(year = 2020)
  
  message("Downloading 2016--2020 ACS data and calculating low-income status...")
  low_inc <- ct_low_inc_status(ct_geom, year = 2020)
  
  ct_geom_10 <- ct_geometry(year = 2010)
  
  message("Downloading 2011--2015 ACS data and calculating low-income status...")
  low_inc_15 <- ct_low_inc_status(ct_geom_10, year = 2015) |>
    dplyr::rename(
      low_inc_15 = low_inc
    )
  
  native <- native_lands()

  native |>
    sf::st_write(
      base::file.path(
        DATA_PATH,
        RSLT_GPKG
      ),
      'native',
      delete_layer = TRUE,
      append = FALSE
    )

  ct_geom <- ct_geom |>
    dplyr::left_join(low_inc) |>
    dplyr::left_join(coal_download()) |>
    dplyr::left_join(energy_download()) |>
    dplyr::mutate(
      int_tribal = geoid %in% dplyr::pull(
        sf::st_filter(ct_geom, native),
        geoid
        )
    ) |>
    dplyr::mutate(
      dplyr::across(c(ffe, ec, mine, gen, adj), ~ dplyr::case_when(
        . == "Yes" ~ TRUE,
        . == "No" ~ FALSE,
        is.na(.) ~ FALSE
      ))
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      nrg_comm = (ffe & ec) | mine | gen | adj
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(nrg_comm | low_inc | int_tribal) |>
    dplyr::select(-int_tribal) |>
    sf::st_write(
      base::file.path(
        DATA_PATH,
        RSLT_GPKG
      ),
      'ct_geom',
      delete_layer = TRUE,
      append = FALSE
    )

  message("Downloading 2010 census tract geometries...")
  ct_geom_10 <- ct_geom_10 |>
    dplyr::left_join(pp_download()) |>
    dplyr::left_join(cejst_download()) |>
    dplyr::mutate(
      pp = dplyr::case_when(
        is.na(pp) ~ FALSE,
        TRUE ~ as.logical(pp)
      )
    ) |>
    dplyr::left_join(low_inc_15) |>
    dplyr::filter(pp | nrg_disadv | low_inc_15) |>
    sf::st_write(
      base::file.path(
        DATA_PATH,
        RSLT_GPKG
      ),
      'ct_geom_2010',
      delete_layer = TRUE,
      append = FALSE
    )

  message("Unioning add'l selection criteria and exporting to GeoJSON for Mapbox upload...")
  ct_geom_10 |>
    dplyr::filter(pp | nrg_disadv) |>
    sf::st_union() |>
    sf::st_cast("POLYGON", do_split = TRUE) |>
    sf::st_as_sf() |>
    sf::st_transform(3857) |>
    sf::st_write(
      base::file.path(
        DATA_PATH,
        'addl_selection.geojson'
      ),
      delete_dsn = TRUE
    )

  message("Done!")
  return(invisible(NULL))
}

if (!interactive()) {
  run()
}
