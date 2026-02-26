# 03_load.R
# Load: write transformed AIS data to SQLite database

library(DBI)
library(RSQLite)
library(dplyr)

# Connect to (or create) the database
con <- dbConnect(RSQLite::SQLite(), "ais_pipeline.db")

# Write main table
dbWriteTable(con, "vessel_transits", ais_transformed, overwrite = TRUE)

# Create an index on region and intensity for faster queries
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_region ON vessel_transits(region)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_intensity ON vessel_transits(intensity)")

# Verify
cat("Rows loaded into database:", dbGetQuery(con, "SELECT COUNT(*) FROM vessel_transits")[[1]], "\n")
cat("Table preview:\n")
print(dbGetQuery(con, "SELECT * FROM vessel_transits LIMIT 5"))

dbDisconnect(con)
cat("Database connection closed.\n")
