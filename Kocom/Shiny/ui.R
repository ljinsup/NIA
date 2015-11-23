library(shiny)

shinyUI(basicPage(
#   uiOutput("CreateUI")

  tabsetPanel(id="tab",

              tabPanel("공공데이터 추가",
                       fluidPage(
                         uiOutput("PublicUI")
                       )
              ),
              tabPanel("
              공공데이터 목록",
                       fluidPage(
                         uiOutput("PublicListUI")
                       )
              ),
              tabPanel("공공데이터 분석",
                       fluidPage(
                         uiOutput("CreateUI")
                       )
              ),
              tabPanel("지진 데이터",
                       ############### DB UI ###############
<<<<<<< HEAD
                       fluidPage(
                         column(2, offset=1,
                                dateInput('minusgs', '데이터 범위:', value = Sys.Date()-365 )
                         ),
                         column(1, offset=1,
                                h1("~")
                         ),
                         column(2, offset=1,
                                dateInput('maxusgs', '  ', value = Sys.Date() )
                         ),
=======
                       fixedPage(
>>>>>>> e6ef85251eb3d63c9b965fad03caf39ef5a01658
                         htmlOutput("USGSUI")
                       )
              ),
              tabPanel("센서 맵",
                       ############### DB UI ###############
                       fluidPage(
                         uiOutput("SensorMapUI")
                       )
              )
              
  )
  ))