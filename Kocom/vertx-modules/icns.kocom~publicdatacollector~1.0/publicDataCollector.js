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

eventbus.registerHandler("pdCollector", function (message, replier) {
    var clientURL = message.url.substring(0, message.url.indexOf("/"));
    var serviceURL = message.url.substring(message.url.indexOf("/"));
    var usetime = message.usetime;
    // parsing the url data
    var dbConfig = message.dbconfig;
    var period = message.period * 1000 * 60 * 60 // transfer hour to millisecond
    var time = new Date();

    var timerID = timer.setPeriodic(period, function () {
        var client = vertx.createHttpClient().host(clientURL); // make connect(to api server)
        if (usetime) {
            var fullurl = serviceURL + '&base_time=' + time.getHours() + '00&ServiceKey=' + message.apikey;
        }
        else {
            var fullurl = serviceURL + '&ServiceKey=' + message.apikey;
        }

        client.getNow(fullurl, function (resp) {
            var body = "";
            resp.dataHandler(function (chunk) {
                body += chunk;
            });
            // receive XML DATA

            resp.endHandler(function () { // end the receive data
                var jsonObjTemp = xml2json.parser(body); // xml to json converting
                var jsonObj = JSON.parse(JSON.stringify(jsonObjTemp.response.body.items.item)); // extracting valuable data
                console.log(JSON.stringify(jsonObj));
                container.deployModule("icns.kocom~mongo-persistor~1.0", dbConfig, 1, function (err, deployID) { // deploy mongodb module
                    if (err != null) {
                        err.printStackTrace();
                    }
                    else {
                        var i;
                        if (Array.isArray(jsonObj)) {
                            for (i = 0; i < jsonObj.length; i++) {
                                eb.send(pa, {
                                    action: 'save',
                                    db_name: 'publicdata',
                                    collection: message.collection,
                                    document: jsonObj[i]
                                }, function (reply) {
                                    var status = reply.status;
                                    console.log(status);
                                }); // save data to db and print result
                            }
                        }
                        else {
                            eb.send(pa, {
                                action: 'save',
                                collection: message.collection,
                                db_name: 'publicdata',
                                document: jsonObj
                            }, function (reply) {
                                var status = reply.status;
                                console.log(status);
                            });
                        }
                    }
                });
            });
        });
    });

    eb.send(pa, {
        action: 'save',
        db_name: 'scconfig',
        collection: "pdList",
        document: {
            url: message.url,
            apikey: message.apikey,
            collection: message.collection,
            period: message.period,
            worker: timerID
        }
    }, function (reply) {
        var status = reply.status;
        console.log(status);
    });

});
