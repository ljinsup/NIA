library(shiny)

shinyUI(basicPage(

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
                         
                       fluidPage(
                         htmlOutput("USGSUI")
                        )
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