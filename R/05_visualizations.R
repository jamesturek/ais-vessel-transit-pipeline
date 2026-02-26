install.packages(c("ggplot2", "leaflet", "viridis", "maps"))

library(ggplot2)
library(viridis)
library(DBI)
library(RSQLite)
library(maps)

# Load data
con <- dbConnect(RSQLite::SQLite(), "ais_pipeline.db")
df <- dbGetQuery(con, "SELECT lon, lat, transit_count, region, intensity FROM vessel_transits")
dbDisconnect(con)

# US coastline base map
us_map <- map_data("world", region = "USA")

# --- Plot 1: Heatmap of vessel traffic density ---
p1 <- ggplot() +
  geom_polygon(data = us_map, aes(x = long, y = lat, group = group),
               fill = "#1a1a2e", colour = "#2d2d5e", linewidth = 0.2) +
  geom_point(data = df, aes(x = lon, y = lat, colour = log1p(transit_count)),
             size = 0.4, alpha = 0.6) +
  scale_colour_viridis_c(option = "inferno", name = "Log Transit Count") +
  coord_fixed(1.3, xlim = c(-130, -60), ylim = c(15, 55)) +
  labs(
    title = "US Vessel Traffic Density 2023",
    subtitle = "AIS Transit Counts: All Regions",
    caption = "Source: NOAA Marine Cadastre"
  ) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "#0d0d1a", colour = NA),
    plot.title = element_text(colour = "white", size = 14, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(colour = "#aaaaaa", size = 9, hjust = 0.5),
    plot.caption = element_text(colour = "#666666", size = 7, hjust = 0.5),
    legend.text = element_text(colour = "white", size = 7),
    legend.title = element_text(colour = "white", size = 8)
  )

print(p1)
ggsave("data/processed/plot1_heatmap.png", p1, width = 12, height = 7, dpi = 200, bg = "#0d0d1a")
cat("Saved plot1_heatmap.png\n")


# --- Plot 2: Top busiest cells ---
top_cells <- dbGetQuery(con <- dbConnect(RSQLite::SQLite(), "ais_pipeline.db"),
  "SELECT lon, lat, transit_count, region 
   FROM vessel_transits 
   ORDER BY transit_count DESC 
   LIMIT 50")
dbDisconnect(con)

p2 <- ggplot() +
  geom_polygon(data = us_map, aes(x = long, y = lat, group = group),
               fill = "#1a1a2e", colour = "#2d2d5e", linewidth = 0.2) +
  geom_point(data = df, aes(x = lon, y = lat),
             colour = "#333366", size = 0.3, alpha = 0.3) +
  geom_point(data = top_cells, aes(x = lon, y = lat, size = transit_count),
             colour = "#ff6b35", alpha = 0.8) +
  scale_size_continuous(name = "Transit Count", range = c(2, 10)) +
  coord_fixed(1.3, xlim = c(-130, -60), ylim = c(15, 55)) +
  labs(
    title = "Top 50 Busiest Vessel Traffic Cells — USA 2023",
    subtitle = "Cell size proportional to transit count",
    caption = "Source: NOAA Marine Cadastre"
  ) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "#0d0d1a", colour = NA),
    plot.title = element_text(colour = "white", size = 14, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(colour = "#aaaaaa", size = 9, hjust = 0.5),
    plot.caption = element_text(colour = "#666666", size = 7, hjust = 0.5),
    legend.text = element_text(colour = "white", size = 7),
    legend.title = element_text(colour = "white", size = 8)
  )

print(p2)
ggsave("data/processed/plot2_top_cells.png", p2, width = 12, height = 7, dpi = 200, bg = "#0d0d1a")
cat("Saved plot2_top_cells.png\n")


# --- Plot 3: Bar chart comparing regions by traffic intensity ---
library(dplyr)

con <- dbConnect(RSQLite::SQLite(), "ais_pipeline.db")
intensity_by_region <- dbGetQuery(con, "
  SELECT region, intensity, COUNT(*) as cells
  FROM vessel_transits
  GROUP BY region, intensity
")
dbDisconnect(con)

# Set factor order for intensity
intensity_by_region$intensity <- factor(intensity_by_region$intensity,
  levels = c("very_low", "low", "medium", "high", "very_high"))

p3 <- ggplot(intensity_by_region, aes(x = region, y = cells, fill = intensity)) +
  geom_bar(stat = "identity", position = "fill") +
  scale_fill_viridis_d(option = "inferno", name = "Intensity",
    labels = c("Very Low", "Low", "Medium", "High", "Very High")) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Vessel Traffic Intensity by Region — USA 2023",
    subtitle = "Proportion of cells per intensity class",
    x = NULL, y = "Proportion of Cells",
    caption = "Source: NOAA Marine Cadastre"
  ) +
  theme_minimal() +
  theme(
    plot.background = element_rect(fill = "#0d0d1a", colour = NA),
    panel.background = element_rect(fill = "#0d0d1a", colour = NA),
    panel.grid = element_line(colour = "#222244"),
    plot.title = element_text(colour = "white", size = 14, face = "bold"),
    plot.subtitle = element_text(colour = "#aaaaaa", size = 9),
    plot.caption = element_text(colour = "#666666", size = 7),
    axis.text = element_text(colour = "white"),
    axis.title = element_text(colour = "white"),
    legend.text = element_text(colour = "white"),
    legend.title = element_text(colour = "white")
  )

print(p3)
ggsave("data/processed/plot3_intensity_by_region.png", p3, width = 10, height = 6, dpi = 200, bg = "#0d0d1a")
cat("Saved plot3_intensity_by_region.png\n")


# --- Plot 4: Interactive Leaflet map ---
library(leaflet)

con <- dbConnect(RSQLite::SQLite(), "ais_pipeline.db")
df_leaf <- dbGetQuery(con, "
  SELECT lon, lat, transit_count, region, intensity
  FROM vessel_transits
  WHERE intensity IN ('high', 'very_high')
")
dbDisconnect(con)

# Colour palette
pal <- colorFactor(
  palette = c("#ff6b35", "#ffcc00"),
  domain = c("high", "very_high")
)

map <- leaflet(df_leaf) |>
  addProviderTiles(providers$CartoDB.DarkMatter) |>
  addCircleMarkers(
    lng = ~lon, lat = ~lat,
    radius = ~ifelse(intensity == "very_high", 6, 3),
    color = ~pal(intensity),
    stroke = FALSE,
    fillOpacity = 0.7,
    popup = ~paste0(
      "<b>Region:</b> ", region, "<br>",
      "<b>Transit Count:</b> ", transit_count, "<br>",
      "<b>Intensity:</b> ", intensity
    )
  ) |>
  addLegend("bottomright", pal = pal, values = ~intensity,
            title = "Traffic Intensity",
            opacity = 0.8)

# Save as HTML
htmlwidgets::saveWidget(map, "data/processed/plot4_interactive_map.html", selfcontained = TRUE)
cat("Saved plot4_interactive_map.html\n")

browseURL("data/processed/plot4_interactive_map.html")
