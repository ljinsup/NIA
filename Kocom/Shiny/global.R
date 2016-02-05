library(CEMS)
CEMS::checkpkg("forecast", "googleVis", "rjson", "rJava", "plyr", "shiny")

HOST <- "163.180.117.96"
PORT <- 30000

mongo_db <- CEMS::connectMongo(Addr = HOST, DB="scconfig", port=PORT)
mongo_sensor <- CEMS::connectMongo(Addr = HOST, DB="sensordata", port=PORT)
mongo_public <- CEMS::connectMongo(Addr = HOST, DB="publicdata", port=PORT)
mongo_usgs <- CEMS::connectMongo(Addr = HOST, DB="usgsdata", port=PORT)

dblist <- rmongodb::mongo.get.database.collections(mongo_db, attr(mongo_db, "db"))
db_info <<- list()
analysis_info <<- list()

strtoJSON <- function(str, jsonlist){
  list <- unlist(strsplit(str, split="-"))
  for(json in jsonlist){
    data <- fromJSON(json)
      if(is.include(list, unlist(data))){
        return(json)
      }
  }
}

inputFix <- function(input, Regexp){
  if(!is.integer0(grep(x=input, pattern=Regexp)))
    return(TRUE)
  else
    return(FALSE)
}


JSONtostr <- function(jsonlist, ...){
  list <- list()
  str <- NULL
  #    if() {
  #      
  #    }
  #    else {
  for(json in jsonlist){
    str <- NULL
    data <- fromJSON(json)
    
    for(l in list(...)){
      if(!is.null(data[[l]])){
        if(is.null(str)){
          str <- as.character(data[[l]])
        }
        else{
          str <- paste(str, as.character(data[[l]]), sep="-")
        }
      }
    }
    list[length(list)+1] <- str
  }
  return(unlist(list))
  #    }
}

strtoJSON <- function(str, jsonlist){
  #   if() {
  #      
  #   }
  #   else {
  list <- unlist(strsplit(str, split="-"))
  for(json in jsonlist){
    data <- fromJSON(json)
    if(is.include(list, unlist(data))){
      return(json)
    }
  }
  #         }
}
