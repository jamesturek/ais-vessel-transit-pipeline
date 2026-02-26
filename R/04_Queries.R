
# Example SQL queries against the AIS pipeline database

library(DBI)
library(RSQLite)

con <- dbConnect(RSQLite::SQLite(), "ais_pipeline.db")

# 1. Traffic intensity breakdown
cat("--- Intensity Breakdown ---\n")
print(dbGetQuery(con, "
  SELECT intensity, COUNT(*) as cells, ROUND(AVG(transit_count), 1) as avg_transits
  FROM vessel_transits
  GROUP BY intensity
  ORDER BY avg_transits DESC
"))

# 2. Busiest region
cat("\n--- Busiest Region ---\n")
print(dbGetQuery(con, "
  SELECT region, COUNT(*) as cells, 
         MAX(transit_count) as max_transits,
         ROUND(AVG(transit_count), 1) as avg_transits
  FROM vessel_transits
  GROUP BY region
  ORDER BY avg_transits DESC
"))

# 3. Top 10 busiest cells
cat("\n--- Top 10 Busiest Cells ---\n")
print(dbGetQuery(con, "
  SELECT lon, lat, transit_count, region
  FROM vessel_transits
  ORDER BY transit_count DESC
  LIMIT 10
"))

# 4. High intensity cells by region
cat("\n--- Very High Intensity by Region ---\n")
print(dbGetQuery(con, "
  SELECT region, COUNT(*) as very_high_cells
  FROM vessel_transits
  WHERE intensity = 'very_high'
  GROUP BY region
  ORDER BY very_high_cells DESC
"))

dbDisconnect(con)
