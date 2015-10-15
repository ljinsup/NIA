/*********************************************************************
 
 eventbus data format
 
 url : API url(UTF-8)
 apikey : data.go.kr API KEY(UTF-8)
 collection : name of API DATA NAME
 dbconfig : database configure data
 period : period of data collect(hours)
 usetime : if Service depend on time -> 1 (weather)
 not depend on time -> 0
 
 *********************************************************************/

var vertx = require('vertx');
var console = require('vertx/console');
var eventbus = require('vertx/event_bus');
var container = require('vertx/container');

eb = vertx.eventBus;

eventbus.registerHandler("tgRegister", function (message, replier) {
    eb.send("mqttclient",{
        "action" : "register",
        "tgID" : "TG01",
        "secureNum" : 123456
      });
});
