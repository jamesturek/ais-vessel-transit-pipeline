# main.R
# Run this file to execute the full pipeline

source("R/01_extract.R")

# Check output
ais_raw <- readRDS("data/processed/ais_raw.rds")
head(ais_raw)

source("R/02_transform.R")
head(ais_transformed)

source("R/03_load.R")

source("main.R")
