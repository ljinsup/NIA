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
var timer = require('vertx/timer');

pa = "mongo-persistor";
eb = vertx.eventBus;

eventbus.registerHandler("pdRemover", function (message, replier) {
    var timerID = message.worker;
    timer.cancelTimer(timerID);
    
    eb.send(pa, {
        action: 'delete',
        db_name: 'scconfig',
        collection: "pdList",
        document: {
            worker: timerID
        }
    }, function (reply) {
        var status = reply.status;
        console.log(status);
    });

});
