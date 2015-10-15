
CEMS::checkpkg("forecast")

service <<- list()
service_id <<- list()
servicetype <<- list()
db_info <<- list()
analysis_info <<- list()
resultmnmt <<- list()
requirement <<- list()
epl <<- list()
sensorlist <<- list()




mongo_db <- CEMS::connectMongo(DB="publicdata", port=30000)
mongo_user <- CEMS::connectMongo(DB="userdata", port=30000)
mongo_service <- CEMS::connectMongo(DB="clouddata", port=30000)
mongo_tg <- CEMS::connectMongo(DB="sensordata", port=30000)
mongo_public <- CEMS::connectMongo(DB="scconfig", port=30000)

dblist <- rmongodb::mongo.get.database.collections(mongo_db, attr(mongo_db, "db"))
tglist <- rmongodb::mongo.get.database.collections(mongo_user, attr(mongo_user, "db"))


if(length(tglist)!=0)
  for(i in 1:length(tglist)){
  if(length(tglist))
    break
  assign(
    unlist(strsplit(tglist[i], split=".", fixed=TRUE))[2],
    mongo.cursor.value(mongo.find(mongo_user, tglist[i])),
    envir=.GlobalEnv
  )
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

inputFix <- function(input, Regexp){
  if(!is.integer0(grep(x=input, pattern=Regexp)))
    return(TRUE)
  else
    return(FALSE)
}
