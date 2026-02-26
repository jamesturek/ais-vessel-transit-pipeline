# AIS Vessel Transit Counts Pipeline

An end-to-end ETL pipeline in R that ingests US coastal vessel traffic raster data, transforms it into a structured format, and loads it into a SQLite database for analysis.

---

## Overview

This project processes **AIS (Automatic Identification System) Vessel Transit Count** GeoTIFFs published by [NOAA Marine Cadastre](https://marinecadastre.gov/ais/) for 2023. The pipeline extracts vessel traffic data across five US regions, reprojects coordinates to WGS84, classifies traffic intensity, and loads the results into a queryable SQLite database.

---

## Pipeline Architecture

```
Raw GeoTIFFs (.tif)
      ↓
01_extract.R   — Load rasters, sample, reproject to WGS84 (EPSG:4326)
      ↓
02_transform.R — Clean, round coordinates, classify traffic intensity
      ↓
03_load.R      — Write to SQLite, create indexes
      ↓
ais_pipeline.db
```

Run the full pipeline with a single command:

```r
source("main.R")
```

---

## Data Source

- **Publisher:** NOAA Office for Coastal Management / Marine Cadastre
- **Dataset:** AIS Vessel Transit Counts 2023
- **Coverage:** Atlantic, Great Lakes, Gulf of Mexico, Pacific, West Coast
- **Resolution:** 100m x 100m grid cells
- **Values:** Total vessel transits per cell across all vessel types (Cargo, Tanker, Passenger, Fishing, Tug/Tow, Pleasure Craft, and Other)

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| R | Pipeline scripting |
| `terra` | Raster ingestion, reprojection, sampling |
| `dplyr` | Data transformation |
| `DBI` / `RSQLite` | Database connection and loading |
| SQLite | Lightweight portable database |

---

## Database Schema

**Table: `vessel_transits`**

| Column | Type | Description |
|--------|------|-------------|
| `lon` | REAL | Longitude (WGS84) |
| `lat` | REAL | Latitude (WGS84) |
| `transit_count` | INTEGER | Total vessel transits at this cell |
| `region` | TEXT | US region (Atlantic, GreatLakes, etc.) |
| `intensity` | TEXT | Traffic classification (very_low → very_high) |

**Intensity Classification:**

| Class | Transit Count |
|-------|--------------|
| very_low | 1 |
| low | 2–5 |
| medium | 6–20 |
| high | 21–100 |
| very_high | > 100 |

---

## Example Queries

**Traffic intensity breakdown:**
```sql
SELECT intensity, COUNT(*) as cell_count, ROUND(AVG(transit_count), 1) as avg_transits
FROM vessel_transits
GROUP BY intensity
ORDER BY avg_transits DESC;
```

**Busiest cells by region:**
```sql
SELECT region, COUNT(*) as cells, MAX(transit_count) as max_transits
FROM vessel_transits
GROUP BY region
ORDER BY max_transits DESC;
```

**Top 10 highest traffic locations:**
```sql
SELECT lon, lat, transit_count, region
FROM vessel_transits
ORDER BY transit_count DESC
LIMIT 10;
```

---

## Key Findings

- The **Gulf of Mexico** contains the highest single-cell transit count (24,963), corresponding to the Houston Ship Channel — one of the busiest waterways in the US
- **Boston Harbor** and the **Delaware River approach to Philadelphia** rank among the highest traffic cells on the Atlantic coast
- Across all regions, the majority of cells fall in the low–medium intensity range, with very high traffic concentrated in a small number of port approaches and shipping lanes

---

## Project Structure

```
AISVesselTransitCounts2023/
├── R/
│   ├── 01_extract.R
│   ├── 02_transform.R
│   └── 03_load.R
├── data/
│   ├── raw/
│   └── processed/
├── main.R
├── ais_pipeline.db
└── README.md
```

---

## Setup

1. Download AIS Vessel Transit Count GeoTIFFs from [marinecadastre.gov](https://marinecadastre.gov/ais/) and place in the project root
2. Install dependencies:
```r
install.packages(c("terra", "dplyr", "DBI", "RSQLite", "tibble"))
```
3. Run the pipeline:
```r
source("main.R")
```
