
shinyServer(function(input, output, session) {
  
  readUSGS <- reactive({
    input$minusgs
    input$maxusgs
    
    usgs <- data.frame()
    
    tryCatch({
      usgs <- getAllData(mongo_usgs, "USGS공공데이터")
      result <- data.frame()
      usgs[,"loc"] <- as.data.frame(paste(usgs$lat, usgs$lng, sep = ":"))
      usgs[,"updated"] <- as.POSIXct(gsub(pattern = "T", replacement = " ", x = usgs$updated))
      usgs[,"data"] <- as.data.frame(paste(usgs$updated, usgs$title, sep = "-"))
      usgs[,"magnitude"] <- as.numeric(as.character(usgs$magnitude))
      for(i in 1:nrow(usgs)){
        if( usgs[i,"updated"] > as.POSIXct(input$minusgs)){
          if(usgs[i, "updated"] < as.POSIXct(input$maxusgs)) {
            result <- rbind(result, usgs[i,])
          }}
      }
      usgs <<- result
      return(result)
    }, error = function(e) {
      result <- NULL
    })
  })
  
  output$USGSUI <- renderGvis({
    usgs <- readUSGS()
    if(is.null(usgs)){h1("USGS 데이터가 없습니다.")}
    else{
    gvisGeoMap(usgs,
               locationvar="loc", 
               numvar="magnitude", 
               hovervar="data", 
               options=list(height=800, 
                            width=1500,
                            #region="KR", 
                            dataMode="markers",
                            showLegend=FALSE
               ))
    }
    })
  
  
  
  readSensors <- reactive({
    invalidateLater(10000,session)
    sensors <- data.frame()
    collections <- mongo.get.database.collections(mongo_sensor, attr(mongo_sensor, "db"))
    
    for(coll in collections){
      colldata <- getAllData(mongo_sensor, unlist(strsplit(coll, split = ".", fixed = T))[2], "updated")
      sensor <- colldata[nrow(colldata),]
      
      
      if(difftime(Sys.time() , as.POSIXct(sensor$updated), units = "mins") > 3){
        sensor$state <- 1
      }
      else if(
        abs(CEMS::Comparing(as.numeric(as.character(colldata[nrow(colldata), "sensors_data.temp"])), as.data.frame(as.numeric(as.character(colldata$sensors_data.temp))))) > 50
      ){
        sensor$state <- 2
      }
      else{
        sensor$state <- 0
      }
      sensor$location <- paste(as.character(sensor$longitude), as.character(sensor$latitude), sep = ":")
      sensor$data <- paste("temp: ", as.character(sensor$sensors_data.temp), ", light: ", as.character(sensor$sensors_data.light), sep = " ")
      sensor$data <- paste(sensor$sensor_id, sensor$data, sep = " - ")
      sensors <- rbind.fill(sensors, sensor)
    }
    
    return(sensors)
  })
 
  output$SensorMapUI <- renderGvis({
    sensordata <<- readSensors()
    sensormap <- gvisGeoMap(sensordata, 
                            locationvar="location", 
                            numvar="state",
                            hovervar="data", 
                            options=list(height=1000,
                                         width=1000,
                                         region="KR", 
                                         dataMode="markers"))
    
  })
  
  #########################################################################
  
  
  
  observeEvent(input$usgssend, function() {
    
      key <- getAllData(mongo_db, "key")
      key <- as.character(key[1, 1])
      
      topic <- paste(key, "usgsCollect", sep = "/")
      
      .jinit("www/MQTTPublisher.jar")
      mqtt <- .jnew("mqtt/MqttSend")
      
      msg <- '{}'
      progress <- Progress$new()
      progress$set(message = paste(topic, msg, sep = " + "))
      
      mqtt$SEND(HOST, "1883", topic, msg)  

  })
  
  
  ########################################################################  ########################################################################
  
  output$PublicUI <- renderUI({
    fluidPage(
      textInput("publicaddr", label = h4("공공데이터 API주소:"), value = "openapi.airkorea.or.kr/openapi/services/rest/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty?numOfRows=1&pageNo=1&stationName=%EC%86%A1%ED%8C%8C%EA%B5%AC&dataTerm=DAILY&", width = '100%'),
    textInput("publicapi", label = h4("공공데이터 API키:"), value = "g2PYYeRkm4XwNs5SkT%2BEm6ZWuLXQCBNLJ4jdEH43rTuU0WjKjo%2B2IBtyAr1EJmS2QqsImnnT3RCr5RNBZ0d25A%3D%3D", width = '100%'),
      textInput("publicname", label = h4("공공데이터 이름:"), value = "대기정보데이터"),
    textInput("publicperiod", label = h4("데이터 업데이트 주기(단위: 시간):"), value = "1"),
      actionButton("publicsend", label = "등록"),
      actionButton("usgssend", label = "USGS test")
    )
  })
  
  output$PublicListUI <- renderUI({
    publictable <- publictabledata()
      if(is.null(publictable)) {
        fluidPage(h1("공공데이터를 넣어주세요."),
                  actionButton("refreshpubliclist", "새로 고침")
        )
      }
      else {
        fluidPage(
          checkboxGroupInput("servicelist", label = h4("공공데이터 목록"),
                             choices = as.list(paste(publictable[,"worker"], publictable[,"collection"], publictable[,"url"], sep = " ")), selected = NULL),
          actionButton("serviceremove", label = "제거")
        )}
  })
  
  publictabledata <- reactive({
    input$refreshpubliclist
    input$publicsend
    input$save
    input$serviceremove
    res.frame <- data.frame() 
    
    cursor <- mongo.find(mongo=mongo_db,
                         ns=paste(attr(mongo_db, "db"), "pdList", sep="."),
                         query=mongo.bson.empty(),
                         fields=mongo.bson.from.JSON('{"_id":0}'))
    
    if(mongo.cursor.next(cursor)){
    res <- mongo.cursor.value(cursor)
    res <- mongo.bson.to.list(res)
    res <- as.data.frame(res)

    res.frame <- rbind(res)

    res.frame <- cbind(res)

    }
    while(mongo.cursor.next(cursor)){
      res <- mongo.cursor.value(cursor)
      res <- mongo.bson.to.list(res)
      res <- as.data.frame(res)

      res.frame <- rbind.fill(res.frame, res)

      res.frame <- cbind(res.frame, res)

    }
    if(nrow(res.frame) == 0)
      return(NULL)
    else
      return(res.frame)
  })
  
  observeEvent(input$publicremove, function() {
    for(data in input$publiclist){
      bson <- mongo.bson.buffer.create()
      mongo.bson.buffer.append(bson, "collection", unlist(strsplit(data, split = " "))[1])
      bson <- mongo.bson.from.buffer(bson)
      
      mongo.remove(mongo_db, paste(attr(mongo_db, "db"), "service", sep = "."), bson)
      
    }
  })
  
  ######################################################################################################
  
  
  
  
  ########################################################################  ########################################################################
  
  
  
  
  output$text <- renderText({
    invalidateLater(1000, session = NULL)
    toJSON(service)
  })
    
  dbnamelist <- reactive({
    input$dbrefresh
    dblist <<- rmongodb::mongo.get.database.collections(mongo_public, attr(mongo_public, "db"))
    list <- list()
    if(length(dblist)!=0)
      for(i in 1:length(dblist)){
        
        assign(
          unlist(strsplit(dblist[i], split=".", fixed=TRUE))[2],
          CEMS::cems.restoreDataType(CEMS::getAllData(mongo_public, unlist(strsplit(dblist[i], split=".", fixed=TRUE))[2])),
          envir=.GlobalEnv
        )
        list[i] <- unlist(strsplit(dblist[i], split=".", fixed=TRUE))[2]
      }
    return(list)
  })
  
  output$CreateUI <- renderUI({fluidPage({
    ######################################
    #        서비스 생성 페이지          #
    ######################################
 
      basicPage(
        tabsetPanel(id="tab", type="pills",
                    
                    tabPanel("1단계: 공공데이터 선택",
                             ############### DB UI ###############
                             if(length(dblist)==0){    
                               h1("공공데이터를 넣어주세요")
                             }
                             else{
                             fixedPage(
                               try({
                                plotOutput("dbplot")
                               }),
                               actionButton("dbadd", label = "추가"),
                               actionButton("dbremove", label = "제거"),
                               actionButton("dbrefresh", label = "새로고침"),
                               
                               selectInput("dbselect", label = h3("공공데이터"),
                                                  choices = dbnamelist()
                               ),
                                      
                               uiOutput("dbui")
                               
                               )}
                             ),
                    
                    tabPanel("2단계: 분석 방법 선택",
                             ############### Analysis UI ###############
                             if(length(dblist)==0){    
                               h1("공공데이터를 넣어주세요")
                             }
                             else{
                             fixedPage(
                               actionButton("refresh1", label = "새로 고침"),
                               
                               uiOutput("publicselectui"),
                               
                               selectInput("analysismethod", label = h4("분석 방법 선택"), 
                                           choices = c("", "예측분석", "비율분석", "비교분석")),
                               
                               uiOutput("methodui")
                               )}
                             )
                    )
        )
        
    })
    })
  
observeEvent(input$serviceremove, function() {
  key <- getAllData(mongo_db, "key")
  key <- as.character(key[1, 1])
  
  workermsg <- list()
  workermsg$type <- "fire"
  topic <- paste(key, "PDRemove", sep = "/")
  
  .jinit("www/MQTTPublisher.jar")
  mqtt <- .jnew("mqtt/MqttSend")
  
  for(serviceid in input$servicelist){
    
    workermsg$worker <- unlist(strsplit(serviceid, split = " "))[1]
    mqtt$SEND(HOST, "1883", topic, toJSON(workermsg))
    workermsg$worker <- NULL
  }

})
  
  
  
  
  
  #                                  DB                                  #
  ##############################     UI     ##############################
  output$dbui <- renderUI({
    if (is.null(input$dbselect))
      return()
    
    set <- get(input$dbselect)
    switch(input$dbselect,
           fluidRow(
             column(3,
                    radioButtons("sort", label = h4("기준(가로축)"),
                                 choices = names(set), selected = names(set)[1])
             ),
             column(5,
                    radioButtons("attr", label = h4("값(세로축)"),
                                 choices = names(set), selected = names(set)[2])
             ),
             column(3,
                    checkboxGroupInput("check", label = h4("데이터선택"),
                                       choices = names(set), selected = NULL)
             )
           )
    )
  })
  
  ##############################   DBPLOT   ##############################
  output$dbplot <- renderPlot({
    
    set <- get(input$dbselect)
    temp <- set[order(set[input$sort]),]
    
    p <- plot(x=temp[[input$sort]],
         y=temp[[input$attr]],
         type="l",
         xlab=input$sort,
         ylab=input$attr
    )
  }, width = 800, height=350)

  ##############################   DBSAVE   ##############################
  observeEvent(input$dbadd, function() {
    data <- DB()
    if(!is.null(data$attr)){
      db_info[[length(db_info) +1]] <<- data
      .GlobalEnv$service[["db_info"]] <- .GlobalEnv$db_info
    }
  })
  
  observeEvent(input$dbremove, function() {
    if(length(analysis_info) == 0){
      if(length(db_info) != 0) {
        db_info[[length(db_info)]] <<- NULL
        .GlobalEnv$service[["db_info"]] <- .GlobalEnv$db_info
      }
    }
  })
 
  ##############################    FUNC    ##############################
  DB <- reactive({    
    if(!is.null(input$dbselect) && !is.null(input$sort) && !is.null(input$check)){
    res <- list(db=attr(mongo_public, "db"),
                collection=input$dbselect,
                sort=input$sort,
                attr=input$check)
    return(res)
    }
    else return(NULL)
  })
  
  #########################################################################
  
  
  
  
  
  
  
  
  #                                ANALYSIS                               #
  ###############################   DATAUI   ##############################
  output$sensorselectui <- renderUI({
    fluidRow({
      radioButtons("analysissensor", label=h3("분석할 센서 선택"),
                   choices = c("GA-가스센서1",
                               "GB-가스센서2",
                               "VB-진동센서",
                               "SH-소리센서") )
    })
    })

  output$publicselectui <- reactiveUI(function() {
    
    if(length(publicdata()) == 0){
      fluidRow({
        h4("공공데이터를 선택하고 새로 고침을 눌러 주세요.")
        
        })
    }else{
      fluidRow({  
        radioButtons("analysispublic", label=h3("공공데이터 선택"),
                   choices = JSONtostr(publicdata(), "collection", "attr" ))
        })
      }
    })

  ###############################  METHODUI  ##############################
  output$methodui <- renderUI({
    input$refresh1
    if( length(.GlobalEnv$db_info)==0 ){
      return()
    }
    
    recentinput <- fromJSON(strtoJSON(input$analysispublic, publicdata()))
    recentpublic <- get(recentinput$collection)
    recentpublic <- recentpublic[order(recentpublic[recentinput$sort]),]
    
    switch(input$analysismethod,
           "예측분석" = 
             fluidPage(
               sliderInput("predrange", "데이터 개수",
                           min = length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean),
                           max = nrow(recentpublic[recentinput$attr])
                                     +length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean),
                           value=nrow(recentpublic[recentinput$attr])
                                     +length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean),
                           step=1
                           ),
               renderPlot({
                 plot(forecast(auto.arima(recentpublic[recentinput$attr])), main="",
                      xlim=c( nrow(recentpublic[recentinput$attr])+length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean)-input$predrange,
                              nrow(recentpublic[recentinput$attr])+length(forecast(auto.arima(recentpublic[recentinput$attr]))$mean) )
                 ) 
                 }, width=800)
           ),
           "비교분석" =
             fluidRow(
               sliderInput("comprange", "구간 선택",
                           min = 1,
                           max = nrow(recentpublic[recentinput$attr]),
                           value=c(1, nrow(recentpublic[recentinput$attr])),
                           step=1
                           ),
               renderPlot({
                 plot(x=recentpublic[seq(unlist(input$comprange)[1], unlist(input$comprange)[2], by=1), recentinput$sort],
                      y=recentpublic[seq(unlist(input$comprange)[1], unlist(input$comprange)[2], by=1), recentinput$attr],
                      type='l',
                      main="",

                      xlab=recentinput$sort,
                      ylab=recentinput$attr
                      
                 )
                 abline(h=mean(unlist(recentpublic[recentinput$attr])), col="blue")
                 abline(h=max(recentpublic[recentinput$attr]), col="red")
                 abline(h=min(recentpublic[recentinput$attr]), col="red")
                 }, width=800)
               ),
           "비율분석" =
             fluidPage(
               column(7, offset=1,
                      renderPlot({
                        pie(count(recentpublic[recentinput$attr])$freq, 
                            labels=paste(count(recentpublic[recentinput$attr])[,recentinput$attr], "(", 
                                         round(count(recentpublic[recentinput$attr])$freq/sum(count(recentpublic[recentinput$attr])$freq)*100, 3), "%)" ,
                                         sep=" ") )
                        
                        }, height=650, width=650)
                      ),
               column(2, offset=2,
                      renderTable({
                        count(recentpublic[recentinput$attr])
                        })
                      )
               )
           )
    })
  
  ############################## METHODSAVE ##############################
  observeEvent(input$methodadd, function() {
    list <- ANALYSIS()
    list$no <- length(analysis_info)+1
    analysis_info[[length(analysis_info) +1]] <<- list
    .GlobalEnv$service[["analysis"]] <- .GlobalEnv$analysis_info
  })
  
  observeEvent(input$methodremove, function() {
    if(length(resultmnmt) == 0) {
      if(length(analysis_info) != 0) {
        analysis_info[[length(analysis_info)]] <<- NULL
        .GlobalEnv$service[["analysis"]] <- .GlobalEnv$analysis_info
      }
    }
  })

  ##############################    FUNC    ##############################
  publicdata <- reactive({
    input$refresh1
    
    if(length(.GlobalEnv$db_info) > 0){
      list <- .GlobalEnv$db_info
      df <- data.frame()
      for(data in list){
        df <- rbind(df, as.data.frame(data))
      }
      list <- list()
      for(i in 1:nrow(df)){
        list[[length(list)+1]] <- toJSON(df[i,])
      }
      
      return(unlist(list))
    }
  })

  ANALYSIS <- reactive({
    list <- list()
    list$sensor <- list(unlist(strsplit(input$analysissensor, split="-"))[1])
    list$public <- list(fromJSON(strtoJSON(input$analysispublic, publicdata()))$attr)
    
    if(input$analysismethod == "비교분석")
      list$method <- "Comparing"
    if(input$analysismethod == "예측분석")
      list$method <- "Predicting"
    if(input$analysismethod == "비율분석")
      list$method <- "Counting"
    
    
    return(list)
  })
  
  #########################################################################
  
  
  
  
  
  
  
  
  #                                 RESULT                                #
  ###############################  RESULTUI  ##############################
  output$resultui <- renderUI(function() {
    if( length( analysisdata() != 0 ) ){
      fluidRow({
        radioButtons("analysislist", label = h3("처리 방법 선택"),
                     choices = JSONtostr(analysisdata(), "no", "sensor", "public", "method"),
                     selected = JSONtostr(analysisdata(), "no", "sensor", "public", "method")[1])
        })
    }
    else{
      fluidRow()
    }
    })
  
  output$rangeui <- reactiveUI(function() {
    if( length( analysisdata() != 0 ) ){
    switch(fromJSON(strtoJSON(input$analysislist, analysisdata()))$method,
           "Predicting" = 
             fluidRow(
               h4("센서값에 따른 예측 구간"), 
               img(src = "case.PNG", width = 580, height = 207),
               selectInput("area", 'Options', c(1, 2, 3, 4, 5, 6), multiple=TRUE, selectize=FALSE)
               ),
           "Comparing" =
             fluidRow(
               sliderInput("range", "결과 범위",
                           min = -100,
                           max = 100,
                           value=c(-100, 100),
                           step=1
               )
               ),
           "Counting" =
             fluidRow(
               sliderInput("range", "결과 범위",
                           min = 0,
                           max = 100,
                           value=c(0, 100),
                           step=1
                           )
               )
           )
    }
    else{
      fluidRow()
    }
    })
  
  output$resulttypeui <- renderUI({
    if (is.null(input$resulttype))
      return()
    
    switch(input$resulttype,
           "추가분석" = fluidPage(
             if(length(analysisdata()) != 0){
             radioButtons("resume", label = h4("분석 방법"),
                          choices = JSONtostr(analysisdata(), "no", "sensor", "public", "method"),
                          selected = NULL)
             }
             ),
           "Actuator제어" = fluidPage(
             selectInput("actuator", label = h4("Actuator종류"), 
                         choices = c("",
                                     "Act01-환기장치",
                                     "Act02-가스차단기", 
                                     "Act03-커튼제어기",
                                     "Act04-실내온도변환기"
                                     
                                     )),
             radioButtons("action", label = h4("동작"),
                                  choices = c("on", "off"), selected = NULL)
             ),
           "Push메시지" = fluidPage(
             textInput("id", label = h4("제목")),
             textInput("message", label = h4("메세지"))
           )
    )
  })
  
  ############################## RESULTSAVE ##############################
  observeEvent(input$resultadd, function() {
    list <- RESULT()
    resultmnmt[[length(resultmnmt) +1]] <<- list
    .GlobalEnv$service[["resultmnmt"]] <- .GlobalEnv$resultmnmt
  })
  
  observeEvent(input$resultremove, function() {
    if(length(epl) == 0){
      if(length(resultmnmt) != 0) {
        resultmnmt[[length(resultmnmt)]] <<- NULL
        .GlobalEnv$service[["resultmnmt"]] <- .GlobalEnv$resultmnmt
      }
    }
  })
  
  ##############################    FUNC    ##############################
  analysisdata <- reactive({
    input$refresh2
    list <- list()
    if(length(.GlobalEnv$analysis_info) > 0){
      for(data in .GlobalEnv$analysis_info){
        list[length(list)+1] <- toJSON(data)
      }
    }
    return(unlist(list))
  })
  
  RESULT <- reactive({
    list <- list()
    
    str <- unlist(strsplit(input$analysislist, split="-"))
    
    list$relation <- str[1]
    
    if(str[1] == "Predicting"){
      list$result <- input$area
    }
    else{ 
      list$rate <- input$range
    }
    
    if(input$resulttype == "추가분석"){
      list$type <- "next"
      list$result <- input$area
    }
    else if(input$resulttype == "Actuator제어"){
      list$type <- "act"
      list$actuator_id <- unlist(strsplit(input$actuator, split="-"))[1]
      list$action <- input$action
    }
    else if(input$resulttype == "Push메시지"){
      list$type <- "push"
      list$mqtt_id <- input$id
      list$message <- input$message
    }
    else {return}
    
    return(list)
  })
  

  #########################################################################
  
  observeEvent(input$save, function() {
    progress <- Progress$new()
    progress$set(message = "서비스 저장중.")
    
    if(length(.GlobalEnv$service) != 0
       && !(is.null(.GlobalEnv$service$service_id)
       && is.null(.GlobalEnv$service$description)
       && is.null(.GlobalEnv$service$db_info)
       && is.null(.GlobalEnv$service$analysis)
       && is.null(.GlobalEnv$service$resultmnmt))){
      
      .GlobalEnv$service[["service_id"]] <- input$serviceid
      list <- list()
      sensor <- list()
      actuator <- list()
      desc <- list()
    
      
        
      for(data in .GlobalEnv$service[["analysis"]]){
        sensor <- append(data$sensor, sensor)
        sensor <- unique(unlist(sensor))
      }
    
      for(data in .GlobalEnv$service[["resultmnmt"]]){
        if(!is.null(data$actuator_id)){
          actuator <- append(data$actuator_id, actuator)
          actuator <- unique(unlist(actuator))
        }
      }
    
      list$sensor <- sensor
      list$actuator <- actuator
    
      .GlobalEnv$service[["servicetype"]] <- .GlobalEnv$service$service_id
      .GlobalEnv$service[["requirement"]] <- list
      .GlobalEnv$service[["description"]] <- input$description
      progress$set(message = toJSON(service))
      
      if(mongo.insert(mongo_service,
                        paste(attr(mongo_service, "db"), "service", sep="."),
                        mongo.bson.from.JSON(toJSON(.GlobalEnv$service)))    ){
        progress$set(message = "저장 되었습니다.")
        service <<- list()
        service_id <<- list()
        db_info <<- list()
        analysis_info <<- list()
        resultmnmt <<- list()
        requirement <<- list()
        epl <<- list()
        sensorlist <<- list()  
        Sys.sleep(2.0)
        progress$close()
          
          
        }
    }
    else{
      progress$set(message = "입력할 데이터가 남았습니다.")
      Sys.sleep(2.0)
      progress$close()
    }
  })

  observeEvent(input$init, function() {
    messaging <- Progress$new()
    messaging$set(message = "초기화 되었습니다.")
    service <<- list()
    service_id <<- list()
    db_info <<- list()
    analysis_info <<- list()
    resultmnmt <<- list()
    requirement <<- list()
    epl <<- list()
    Sys.sleep(2.0)
    messaging$close()
  })
  #########################################################################
  observeEvent(input$epladd, function() {  
    messaging <- Progress$new()
    if(inputFix(input$eplvalue, "^[0-9]+$") && input$eplsensor != "" && input$eploperator != "") {
      sensorlist[[length(sensorlist) +1]] <<- unlist(strsplit(input$eplsensor, split = "-"))[1]
      sensorlist <<- unique((sensorlist))
      epl[[length(epl) +1]] <<- paste(unlist(strsplit(input$eplsensor, split = "-"))[1], input$eploperator, input$eplvalue, sep=" ")
      
      if(length(sensorlist) == length(epl)){
        .GlobalEnv$service[["sensorlist"]] <- unique(.GlobalEnv$sensorlist)
        .GlobalEnv$service[["epl"]] <- .GlobalEnv$epl
      }
      else{
        
        epl[[length(epl)]] <<- NULL
        .GlobalEnv$service[["sensorlist"]] <- unique(.GlobalEnv$sensorlist)
        .GlobalEnv$service[["epl"]] <- .GlobalEnv$epl
        
      }
    }  
    else {
      messaging$set(message = "잘못된 입력값이 있습니다. (EPL)")
      Sys.sleep(2.0)
      messaging$close()
    }
  })

  observeEvent(input$eplremove, function() {
    if(length(epl) != 0) {
      epl[[length(epl)]] <<- NULL
      sensorlist[[length(sensorlist)]] <<- NULL
      .GlobalEnv$service[["epl"]] <- .GlobalEnv$epl
      .GlobalEnv$service[["sensorlist"]] <- .GlobalEnv$sensorlist
    }
  })
  #########################################################################
  
  
  
  
  
  observeEvent(input$publicsend, function() {
    
    if(!is.null(input$publicaddr)
       || !is.null(input$publickey)
       || !is.null(input$publicname)
       || inputFix(input$publicperiod, "^[1-9]+$")){
    
      list <- list()
    
      key <- getAllData(mongo_db, "key")
      key <- as.character(key[1,1])
      
      topic <- paste(key, "PDImport", sep = "/")
      
      .jinit("www/MQTTPublisher.jar")
      mqtt <- .jnew("mqtt/MqttSend")
      
      list$url <- input$publicaddr
      list$apikey <- input$publicapi
      list$collection <- input$publicname
      list$period <- input$publicperiod
    
      msg <- toJSON(list)
      
      mqtt$SEND(HOST, "1883", topic, msg)  
      print(paste(HOST, "1883", topic, msg, sep = "   ") )
      }
    else {
      messaging <- Progress$new()
      messaging$set(message = "입력값을 확인해주세요.")
      Sys.sleep(2.0)
      messaging$close()
      }
  })
  
  
  
  
  
  
#########################################################################
})