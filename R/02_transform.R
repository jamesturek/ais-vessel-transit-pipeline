# 02_transform.R
# Transform: clean and enrich the extracted AIS data

library(dplyr)

transform_ais <- function(df) {
  
  df_clean <- df |>
    # Round coordinates to 4 decimal places
    mutate(
      lon = round(lon, 4),
      lat = round(lat, 4)
    ) |>
    # Add transit intensity classification
    mutate(
      intensity = case_when(
        transit_count == 1        ~ "very_low",
        transit_count <= 5        ~ "low",
        transit_count <= 20       ~ "medium",
        transit_count <= 100      ~ "high",
        transit_count > 100       ~ "very_high"
      )
    ) |>
    # Remove any remaining NAs
    filter(!is.na(lon), !is.na(lat), !is.na(transit_count))
  
  cat("Rows after transform:", nrow(df_clean), "\n")
  return(df_clean)
}

ais_transformed <- transform_ais(ais_raw)

saveRDS(ais_transformed, "data/processed/ais_transformed.rds")
cat("Saved to data/processed/ais_transformed.rds\n")
