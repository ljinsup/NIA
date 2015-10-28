var vertx = require('vertx');
var container = require('vertx/container');
var eb = vertx.eventBus;

// Deploy a MongoDB persistor module

var dbconfig = {
    "host": "localhost",
    "port": 30000,
    "db_name": "scconfig"
};
var key = "kocom";

var mqttconf = {
    host: 'localhost',
    port: 1883,
    key: key,
    clientID: "collector",
    dbConfig: dbconfig
};

container.deployModule('icns.kocom~mongo-persistor~1.0', dbconfig, function () {

    // And when it's deployed run a script to load it with some reference
    // data for the demo
    eb.send('mongo-persistor', {action: 'delete', db_name: 'scconfig', collection: 'key', matcher: {}}, function () {

        // And insert a user

        eb.send('mongo-persistor', {
            action: 'save',
            db_name: 'scconfig',
            collection: 'key',
            document: {
                key: "kocom"
            }
        });
    });

});

container.deployModule('icns.kocom~publicdatacollector~1.0', function (err) { // deploy public data collector module
    if (err != null) {
        err.printStackTrace(); // error print;
    }
});

container.deployModule('icns.kocom~publicdataremover~1.0', function (err) { // deploy public data collector module
    if (err != null) {
        err.printStackTrace(); // error print;
    }
});

container.deployModule('icns.kocom~tgregister~1.0', function (err) { // deploy public data collector module
    if (err != null) {
        err.printStackTrace(); // error print;
    }
});

container.deployModule('icns.kocom~mqtt-client~0.1', mqttconf, 1, function (err) { // deploy public data collector module
    if (err != null) {
        err.printStackTrace(); // error print;
    }
    else
    {
        eb.send("mqttclient", {
            "action": "subscribe",
            "topic": "TGdata"
        });
        eb.send("mqttclient", {
            "action": "subscribe",
            "topic": "PDImport"
        });
        eb.send("mqttclient", {
            "action": "subscribe",
            "topic": "usgsCollect"
        });

    }
});

container.deployModule('icns.kocom~usgs~1.0',  function (err) { // deploy public data collector module
    if (err != null) {
        err.printStackTrace(); // error print;
    }
    
});
