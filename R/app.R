install.packages("shiny")
# AIS Vessel Transit Dashboard

library(shiny)
library(leaflet)
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(viridis)

# --- Load data ---
con <- dbConnect(RSQLite::SQLite(), "ais_pipeline.db")
df <- dbGetQuery(con, "SELECT lon, lat, transit_count, region, intensity FROM vessel_transits")
ports <- dbGetQuery(con, "SELECT * FROM port_clusters")
lanes <- dbGetQuery(con, "SELECT * FROM shipping_lanes")
dbDisconnect(con)

# --- UI ---
ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "darkly"),
  titlePanel("🚢 US Vessel Transit Dashboard — 2023"),
  
  tabsetPanel(
    
    # Tab 1: Overview
    tabPanel("Overview",
      br(),
      fluidRow(
        column(3, selectInput("region_filter", "Filter by Region:",
          choices = c("All", unique(df$region)), selected = "All")),
        column(3, selectInput("intensity_filter", "Minimum Intensity:",
          choices = c("All", "very_low", "low", "medium", "high", "very_high"),
          selected = "All"))
      ),
      leafletOutput("overview_map", height = "600px")
    ),
    
    # Tab 2: Port Clusters
    tabPanel("Port Clusters",
      br(),
      fluidRow(
        column(6, leafletOutput("port_map", height = "500px")),
        column(6, tableOutput("port_table"))
      )
    ),
    
    # Tab 3: Stats
    tabPanel("Statistics",
      br(),
      fluidRow(
        column(6, plotOutput("intensity_bar")),
        column(6, plotOutput("region_bar"))
      )
    )
  )
)

# --- Server ---
server <- function(input, output, session) {
  
  # Filtered data for overview
  filtered_df <- reactive({
    d <- df
    if (input$region_filter != "All") d <- d |> filter(region == input$region_filter)
    if (input$intensity_filter != "All") {
      levels <- c("very_low", "low", "medium", "high", "very_high")
      min_idx <- which(levels == input$intensity_filter)
      d <- d |> filter(intensity %in% levels[min_idx:length(levels)])
    }
    d
  })
  
  # Overview leaflet map
  output$overview_map <- renderLeaflet({
    pal <- colorNumeric("inferno", domain = log1p(filtered_df()$transit_count), reverse = FALSE)
    
    leaflet(filtered_df()) |>
      addProviderTiles(providers$CartoDB.DarkMatter) |>
      addCircleMarkers(
        lng = ~lon, lat = ~lat,
        radius = 3,
        color = ~pal(log1p(transit_count)),
        stroke = FALSE,
        fillOpacity = 0.7,
        popup = ~paste0(
          "<b>Region:</b> ", region, "<br>",
          "<b>Transit Count:</b> ", transit_count, "<br>",
          "<b>Intensity:</b> ", intensity
        )
      ) |>
      addLegend("bottomright", pal = pal, values = ~log1p(transit_count),
                title = "Log Transit Count", opacity = 0.8)
  })
  
  # Port clusters map
  output$port_map <- renderLeaflet({
    leaflet(ports) |>
      addProviderTiles(providers$CartoDB.DarkMatter) |>
      addCircleMarkers(
        lng = ~lon, lat = ~lat,
        radius = ~scales::rescale(max_transits, to = c(5, 25)),
        color = "#ff6b35",
        stroke = FALSE,
        fillOpacity = 0.8,
        popup = ~paste0(
          "<b>", port_name, "</b><br>",
          "<b>Region:</b> ", region, "<br>",
          "<b>Max Transits:</b> ", max_transits, "<br>",
          "<b>Avg Transits:</b> ", avg_transits
        )
      )
  })
  
  # Port table
  output$port_table <- renderTable({
    ports |>
      select(port_name, region, max_transits, avg_transits, cells) |>
      arrange(desc(max_transits)) |>
      head(15)
  })
  
  # Intensity bar chart
  output$intensity_bar <- renderPlot({
    df |>
      count(intensity) |>
      mutate(intensity = factor(intensity,
        levels = c("very_low", "low", "medium", "high", "very_high"))) |>
      ggplot(aes(x = intensity, y = n, fill = intensity)) +
      geom_bar(stat = "identity") +
      scale_fill_viridis_d(option = "inferno") +
      labs(title = "Cells by Intensity", x = NULL, y = "Count") +
      theme_minimal() +
      theme(legend.position = "none",
            plot.background = element_rect(fill = "#222", colour = NA),
            panel.background = element_rect(fill = "#222", colour = NA),
            panel.grid = element_line(colour = "#444"),
            text = element_text(colour = "white"),
            axis.text = element_text(colour = "white"))
  })
  
  # Region bar chart
  output$region_bar <- renderPlot({
    df |>
      group_by(region) |>
      summarise(avg = mean(transit_count)) |>
      ggplot(aes(x = reorder(region, avg), y = avg, fill = avg)) +
      geom_bar(stat = "identity") +
      scale_fill_viridis_c(option = "inferno") +
      coord_flip() +
      labs(title = "Avg Transit Count by Region", x = NULL, y = "Avg Transits") +
      theme_minimal() +
      theme(legend.position = "none",
            plot.background = element_rect(fill = "#222", colour = NA),
            panel.background = element_rect(fill = "#222", colour = NA),
            panel.grid = element_line(colour = "#444"),
            text = element_text(colour = "white"),
            axis.text = element_text(colour = "white"))
  })
}

shinyApp(ui, server)
