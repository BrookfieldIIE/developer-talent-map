#Stack Overflow Developer Talent Map for Canadian Cities and Provinces
##R Shiny Map Widget
#setwd("~/GitHub/developer-talent-map")

##To do
library(leaflet)
library(formattable)
library(tidyverse)
library(sf)
library(shiny)
library(bsplus)

#Preprocessing - move some to load script ===================
#Import data from load scripts
provinces <- read_sf("provinces.shp")
cities <- read_sf("cities.shp")

#Change names on fields and preserve SF object type
names(provinces)[names(provinces)=="dev_rol"] <- "dev_role"
names(provinces)[names(provinces)=="visitrs"] <- "visitors"
names(provinces)[names(provinces)=="prvnc__"] <- "share"
names(provinces)[names(provinces)=="lctn_qt"] <- "loc_quo"

names(cities)[names(cities)=="dev_rol"] <- "dev_role"
names(cities)[names(cities)=="visitrs"] <- "visitors"

cities$visitors <- comma(cities$visitors, 0)
cities$share <- percent(cities$share, 1)
cities$loc_quo <- comma(cities$loc_quo ,2)

provinces$visitors <- comma(provinces$visitors, 0)
provinces$share <- percent(provinces$share)
provinces$loc_quo <- comma(provinces$loc_quo, 2)

#Dropdown choices
rolegroups <- c("All Developers", "Mobile Developers", "Web Developers", "Other Kinds of Developers")
role <- unique(cities$dev_role)
role <- role[(!role %in% rolegroups)]

metric <- c(
  "Stack Overflow visitors" = "visitors",
  "Share of local Stack Overflow visitors in role" = "share",
  "Location quotient" = "loc_quo"
)

#Create help modal
help_modal <-
  bs_modal(
    id = "help_modal",
    title = "Help - StackOverflow Developer Talent Map",
    body = includeMarkdown("help.md"),
    size = "medium"
  )

#DefineUI ===================
ui <- function(request) {
  fillPage(title= "Developer Talent Map - StackOverflow + BII+E", theme = "styles.css",
    div(style = "width: 100%; height: 100%;",
        leafletOutput("map", width = "100%", height = "100%"),
        help_modal,
        absolutePanel(id = "controls", class = "panel panel-default", draggable = TRUE, fixed = TRUE,
                      top = "30%", left = 10, right = "auto", bottom = "auto", 
                      width = "200px", height = "auto",
                      h1("Canadian Developer Talent Map"),
                      selectInput("metric", "Metric", metric, selectize = FALSE), #Draggable and selectize seem incompatible for scrolling
                      selectInput("role", "Developer Role", list("Role Groups" = rolegroups, "Roles" = role), selectize=FALSE),
                      radioButtons("juris", "Jurisdiction", choices = c("Cities", "Provinces"), selected = "Cities", inline = TRUE),
                      bookmarkButton(label = "Share your selections", title = "Save your selections to a URL you can share"),
                      h1(shiny_iconlink(name = "question-circle"), " Help") %>% bs_attach_modal(id_modal = "help_modal")
                      ),
        tags$div(id="icons",
                 tags$a(href="http://brookfieldinstitute.ca/research-analysis/stacking-up-canadas-developer-talent", img(src='brookfield_institute_esig_small.png', hspace = "5px", align = "left")),
                 #tags$br(),
                 tags$a(href="https://insights.stackoverflow.com/survey", img(src='so-logo-small.png', hspace = "5px", align = "left")),
                 #tags$br(),
                 tags$a(href="https://github.com/BrookfieldIIE/developer-talent-map", icon("github-square", "fa-2x")),
                 tags$a(href="https://twitter.com/BrookfieldIIE", icon("twitter-square", "fa-2x")),
                 tags$a(href="https://www.facebook.com/BrookfieldIIE/", icon("facebook-square", "fa-2x")),
                 tags$a(href="https://www.youtube.com/channel/UC7yVYTU2QPmY8OYh85ym-2w", icon("youtube-square", "fa-2x")),
                 tags$a(href="https://www.linkedin.com/company/the-brookfield-institute-for-innovation-entrepreneurship", icon("linkedin-square", "fa-2x"))
                 )
    ),
    use_bs_popover(),
    use_bs_tooltip()
  )
}
                
#Server ===================
server <- function(input, output, session) {
  
  #If metric changes, set metric label name
  labelmetric <- reactive({
    if (input$metric == "visitors") {
      labelmetric <- names(metric[1])
    } else if (input$metric == "share") {
      labelmetric <- names(metric[2])
    } else {
      labelmetric <- names(metric[3])
    }
    })

  #Draw base map
   output$map <- renderLeaflet({
     leaflet() %>%
       fitBounds(lng1 = -124, 
                 lat1 = 42, 
                 lng2 = -63, 
                 lat2 = 54) %>%
       addProviderTiles(providers$Stamen.TonerLite)
     })
   
   #Select and filter city data for role and metric
   cities.r <- reactive({
     cities.r <- cities[cities$dev_role == input$role,]
     if (input$metric == "loc_quo") {cities.r <- cities.r[is.na(cities.r$loc_quo) == FALSE,]}
     if (input$metric == "share") {cities.r <- cities.r[is.na(cities.r$share) == FALSE,]}
     if (input$metric == "visitors") {cities.r <- cities.r[is.na(cities.r$visitors) == FALSE,]}
     return(cities.r)
   })
   
     #Add city markers
     observe({
       if (input$juris == "Cities") {
         labelmetric <- labelmetric()
         
       #Create metrics for shading/sizing markers
       cities.c <- cities.r()
       citymetric <- cities.c[[input$metric]]
       cityrad <- (citymetric/mean(citymetric)*100)^.55 #300^.5
       
       #Create color palette based on metrics
       metricpal.c <- colorBin(
         palette = c("#FFD5F0","#79133E"),
         domain = c(min(citymetric), max(citymetric)),
         bins=4,
         pretty=TRUE)
       
       #Draw city markers
       leafletProxy("map", data = cities.c) %>% clearShapes() %>% clearMarkers() %>%
         
         addCircleMarkers(
           weight = 1,
           radius = ~cityrad,
           color = "#E24585",
           fillColor = ~metricpal.c(citymetric),
           fillOpacity = .8,
           label = ~paste0(cities.c$cities," - ", labelmetric, ": ", citymetric),
           labelOptions = labelOptions(
             style = list(
             "font-family" = "rooneysansmed",
             "box-shadow" = "3px 3px rgba(0,0,0,0.25)",
             "border-width" = "1px",
             "border-color" = "rgba(0,0,0,0.5)")))%>%
         #Add legend
         clearControls() %>%
         addLegend("bottomright", pal = metricpal.c, values = citymetric,
                   title = labelmetric)
       }
       })
     
     #Add province polygons
     observe({
       if (input$juris == "Provinces") {
         
         labelmetric <- labelmetric()
         
         #Select and filter jurisdictional data for role and metric
         provinces.p <- provinces[provinces$dev_role == input$role,]
         provmetric <- provinces.p[[input$metric]]
         
         
         #Create color palette based on metrics
         metricpal.p <- colorBin(
           palette = c("#F48EBD","#79133E"),
           domain = c(min(provmetric), max(provmetric)),
           n=7, pretty=TRUE)
         
         #Add province polygons
         leafletProxy("map", data = provinces.p) %>% clearShapes() %>% clearMarkers() %>%
           addPolygons(color = ~metricpal.p(provmetric), weight = 1, smoothFactor = 0.5,
                         opacity = 1.0, fillOpacity = 0.7,
                         highlightOptions = highlightOptions(color = "white", weight = 1),
                         label = ~paste0(gn_name," - ", labelmetric, ": ", provmetric),
                         labelOptions = labelOptions(style = list(
                           "font-family" = "rooneysansmed",
                           "box-shadow" = "3px 3px rgba(0,0,0,0.25)",
                           "border-width" = "1px",
                           "border-color" = "rgba(0,0,0,0.5)"))) %>%
           
           #Add legend
           clearControls() %>%
           addLegend("bottomright", pal = metricpal.p, values = provmetric,
                     title = labelmetric)
       }
     })
   } #Server close

# Run the application
enableBookmarking()
shinyApp(ui = ui, server = server)

