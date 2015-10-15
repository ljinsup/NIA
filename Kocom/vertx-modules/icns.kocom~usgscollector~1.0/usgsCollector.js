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
var xml2json = require('xml2json');

pa = "mongo-persistor";
eb = vertx.eventBus;

eventbus.registerHandler("usgsCollector", function (message, replier) {
//    var dbConfig = message.dbconfig;
//    var period = message.period * 1000 * 60 * 60; // transfer hour to millisecond
//    var time = new Date();

    var client = vertx.createHttpClient().host("earthquake.usgs.gov"); // make connect(to api server)

    client.getNow("earthquakes/feed/v1.0/summary/all_hour.atom", function (resp) {
        var body = "";
        resp.dataHandler(function (chunk) {
            body += chunk;
        });
        // receive XML DATA

        resp.endHandler(function () { // end the receive data
            var jsonObjTemp = xml2json.parser(body); // xml to json converting
            console.log(JSON.stringify(jsonObjTemp));
        });
    });
});
