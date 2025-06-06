# ============================================================
# Load Required Libraries and Initialize Settings
# ============================================================

library(shiny)         # Shiny framework for interactive web applications
library(jsonlite)      # For processing JSON data
library(geojsonio)     # For reading and writing GeoJSON data
library(dplyr)         # Data manipulation and transformation
library(sf)            # For handling spatial data
library(ggplot2)       # Data visualization
library(scales)        # Formatting for plots
library(plotly)        # For interactive plotting
library(shinythemes)
source("mapboxtoken_setup.R")  # Loads mapbox_token used for Mapbox access

# ============================================================
# Load Demand Data: Commuting Zone Job Postings
# ============================================================
# Read the Commuting Zone (CZ) job postings data. This RDS file should contain fields:
# - CZ20: Commuting zone identifier
# - YEAR: Year of the data
# - green_job_postings: Number of green job postings in that CZ
# - geometry: Spatial information for mapping
CZ_job_post <- readRDS("CZ_job_post.rds")

ui <- fluidPage(
  theme = shinytheme("cerulean"),
  tags$head(
    tags$style(HTML("
      #desc-box {
        background-color: rgba(255,255,255,0.6) !important;
        margin-top: 20px;
        padding: 10px;
        border-radius: 4px;
      }
      #map { visibility: hidden; width: 100%; }
    "))
  ),
  
  titlePanel("Advanced Infrastructure, Energy, and Agriculture (AIREA) Jobs Postings and Community College Graduates"),
  tags$p("This interactive map shows how community college green program completions align with AIREA-sector job postings by commuting zone. Use the controls above to change year, color metric, or locate a specific institution."),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      
      # Controls shown only on the Map tab
      conditionalPanel(
        "input.tabs == 'mainmap'",
        selectInput("selected_year_map", "Select Year:",
                    choices = sort(unique(CZ_job_post$YEAR), decreasing = TRUE),
                    selected = max(CZ_job_post$YEAR)),
        selectInput("cz_metric", "Color by:", 
                    choices = c(
                      "AIREA Job Postings"      = "airea_job_posting",
                      "% AIREA Postings" = "pct_green",
                      "AIREA Jobs / 1,000 Residents" = "per1000"
                    )),
        selectizeInput("search_term", "Search by Institution:",
                       choices = NULL, options = list(), width="100%"),
        fluidRow(
          column(6, actionButton("search_btn","Search", class="btn-primary", width="100%")),
          column(6, tags$button("Clear", onclick="clearMap()", class="btn btn-default", style="width:100%;"))
        )
      ),
      
      # Controls shown only on the Supply tab
      conditionalPanel(
        "input.tabs == 'treemap'",
        selectInput("selected_year_supply", "Select Year:",
                    choices = sort(unique(CZ_job_post$YEAR), decreasing = TRUE),
                    selected = max(CZ_job_post$YEAR))
      ),
      
      # controls shown only on demand tab
      
      conditionalPanel(
        "input.tabs == 'demand'",
        # checkboxGroupInput(
        #   "selected_SOCs", 
        #   "Select SOC:",
        #   choices = c(
        #     "11-1011" = "Management",
        #     "13-1199" = "Business and Financial Operations",
        #     "15-1212" = "Information Security Analysts",
        #     "17-2199" = "Engineers",
        #     "19-2041" = "Environmental Scientists and Specialists",
        #     "19-4099" = "Life, Physical, and Social Science Technicians",
        #     "27-1024" = "Graphic Designers",
        #     "27-3031" = "Public Relations Specialists"
        #   )
        #   
        # ),
        
        selectInput("selected_year_demand", "Select Year:",
                    choices = sort(unique(CZ_job_post$YEAR), decreasing = TRUE),
                    selected = max(CZ_job_post$YEAR))
      )
    ),  # ← here we close sidebarPanel() and then put a comma
    
    mainPanel(
      width = 9,
      tabsetPanel(
        id = "tabs", type = "tabs",
        
        tabPanel("Map", value = "mainmap",
                 div(id="map", style="height:700px;width:100%;")
        ),
        
        tabPanel("Community Colleges AIREA Degree Completions", value = "treemap",
                 
                 # Top Row: Table Output
                 fluidRow(
                   column(12,
                          tags$h5("Table with the institutions with the greatest number of degree completions"),
                          # You can add a specific title for the table if needed, e.g., tags$h4("Institution Data").
                          DT::dataTableOutput("supply_table") 
                   )
                 ),
                 
                 tags$hr(),
                 
                 # Bottom Row: Treemap (left) and Bar chart (right)
                 fluidRow(
                   column(7, # Adjust width as needed (e.g., 6 for equal split)
                          tags$h5("Tree map showing frequent Degrees (CIPs)"), # Title for the treemap
                          plotlyOutput("treemapPlot", height = "600px") # Your existing treemap plot
                   ),
                   
                   column(5, # Adjust width as needed
                          tags$h5("Degrees (Lines represent individual CIP codes)"), # Title for the bar chart
                          plotOutput("degrees_over_time") # Placeholder for your bar chart output
                   )
                 )
        ),
        
        tabPanel("AIREA-related Job Postings", value = "demand",

                 # Top Row: Table Output
                 tags$h5("Job Postings per SOC code"), # Title for the treemap
                 
                 fluidRow(
                   column(12,
                          # The screenshot shows "Institution" as a key part of this section.
                          # You can add a specific title for the table if needed, e.g., tags$h4("Institution Data").
                          DT::dataTableOutput("demand_table") 
                   )
                 ),
                 
                 tags$hr(),
                 
                 # Bottom Row: Treemap (left) and Bar chart (right)
                 fluidRow(
                   column(12), # Adjust width as needed (e.g., 6 for equal split)
                   tags$h5("SOC codes for most common jobs"), # Title for the treemap
                   plotlyOutput("trendPlot", height = "600px") # Your existing treemap plot
                 ),
        ),
    )
  )
),

# -------------------------------
# Footer
# -------------------------------
fluidRow(
  column(12, align = "center",
         tags$footer(
           style = "margin-top: 20px; padding: 10px; font-size: 12px; background-color: #f8f9fa; border-top: 1px solid #e9ecef;",
           HTML("Created by Wei Wang, Joshua Rosenberg, Cameron Sublet and Bret Staudt Willet with the <a href='https://ccrc.tc.columbia.edu/' target='_blank'>Community College Research Center at Teachers College, Columbia University</a>. Source code at: <a href='https://github.com/data-edu/CCRC_GreenSeek-Mapping' target='_blank'>GitHub</a>. Thanks to JPMorgan Chase for their financial support.")
         )
  )
),


# Mapbox & JS Include Mapbox GL JS and custom scripts
tags$link(rel="stylesheet", 
          href="https://api.mapbox.com/mapbox-gl-js/v2.14.1/mapbox-gl.css"),
tags$script(src="https://api.mapbox.com/mapbox-gl-js/v2.14.1/mapbox-gl.js"),
tags$script(src="mapbox.js"),
tags$script(HTML(paste0("const mapboxToken = '", mapbox_token, "';"))),
tags$script(src="https://cdn.jsdelivr.net/npm/@turf/turf@6/turf.min.js")
)