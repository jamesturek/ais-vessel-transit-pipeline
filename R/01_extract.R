library(terra)
library(dplyr)

extract_region <- function(region_name, n_samples = 10000) {
  
  cat("Processing:", region_name, "\n")
  
  tif_path <- paste0("AISVTC2023", region_name, ".tif")
  r <- rast(tif_path)
  
  # Sample first (fast, no reprojection yet)
  sampled <- spatSample(r, size = n_samples, method = "random", 
                        na.rm = TRUE, xy = TRUE)
  
  # Reproject just the sample points (much faster than reprojecting raster)
  pts <- vect(sampled, geom = c("x", "y"), crs = "EPSG:3857")
  pts_wgs84 <- project(pts, "EPSG:4326")
  
  df <- as.data.frame(pts_wgs84, geom = "XY") |>
    setNames(c("transit_count", "lon", "lat")) |>
    select(lon, lat, transit_count) |>
    filter(transit_count > 0) |>
    mutate(region = region_name)
  
  cat("  Rows extracted:", nrow(df), "\n")
  return(df)
}

# --- Run all regions ---
regions <- c("Atlantic", "GreatLakes", "GulfOfMexico", "Pacific", "WestCoast")
ais_raw <- bind_rows(lapply(regions, extract_region))

saveRDS(ais_raw, "data/processed/ais_raw.rds")
cat("\nDone. Total rows:", nrow(ais_raw), "\n")
