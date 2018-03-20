//line 1 "/working/cse/examples-nbl/AzureTwins/examples/agent.nut"
// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#require "AzureIoTHub.agent.lib.nut:2.1.0"
#require "PrettyPrinter.class.nut:1.0.1"
//line 1 "../AzureTwins.agent.lib.nut"
// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
const AZURE_IOTHUB_API_VERSION = "/api-version=2016-11-14";

const AT_DISCONNECTED = "DISCONNECTED";
const AT_CONNECTING   = "CONNECTING";
const AT_CONNECTED    = "CONNECTED";
const AT_SUBSCRIBING  = "SUBSCRIBING";
const AT_SUBSCRIBED   = "SUBSCRIBED";

const ENABLE_DEBUG    = 1;

// Azure Twin API client. Support Twin property patching and listening for method invocation requests
class AzureTwin {

    _deviceConnectionString     = null;
    _mqttclient                 = null;
    _state                      = AT_DISCONNECTED;

    _connectionListener         = null;
    _twinUpdateHandler          = null;
    _methodInvocationHandler    = null;
    _twinStatusRequestCb        = null;
    _twinUpdateRequestCb        = null;

    _reqCounter                 = 33;

    // Constructor
    //
    // Parameters:
    //  deviceConnection        - Azure IoTHub Device Connection String
    //  connectionHandler       - a function to receive notification about connection status
    //  twinUpdateHandler       - a function to receive twin desired properties updates initiated by remote service
    //  methodInvocationHandler - a function to receive direct method invocation request
    constructor(deviceConnection, connectionHandler, twinUpdateHandler, methodInvocationHandler = null) {

        _deviceConnectionString     = deviceConnection;
        _connectionListener         = connectionHandler;
        _deviceConnectionString     = deviceConnection;
        _twinUpdateHandler          = twinUpdateHandler;
        _methodInvocationHandler    = methodInvocationHandler;

        // TODO: may want to move the client string parser to this class
        local cn = AzureIoTHub.ConnectionString.Parse(deviceConnection);
        _mqttclient = mqtt.createclient(
            "ssl://" + cn.HostName,
            cn.DeviceId,
            _onMessage.bindenv(this),
            _onDelivery.bindenv(this),
            _onDisconnected.bindenv(this)
        );

        _connect();
    }

    // Send request to get latest twin status
    // Parameter:
    //  onComplete  - callback to receive either error message or JSON document
    //
    // Note: only one request is allowed per time
    function getCurrentStatus(onComplete) {
        if (_twinStatusRequestCb != null) throw "getStatus is ongoing";

        if (_state == AT_SUBSCRIBED) {
            local topic   = "$iothub/twin/GET/?$rid=" + _reqCounter;
            local message = _mqttclient.createmessage(topic, "");
            local id      = message.sendasync(_onSendStatusRequest.bindenv(this));

            _reqCounter++;
            _twinStatusRequestCb = onComplete;
            _log("Message to " + topic + " was scheduled as " + id);
        } else {
            throw "AzureTwin is not connected";
        }
    }

    // Pushes update to reported section of a twin JSON document.
    // Parameters:
    //  status      - JSON with new properties
    //  onComplete  - callback to be called when request complete or error happens
    function updateStatus(status, onComplete) {
        if (_twinUpdateRequestCb != null) throw "updateStatus is ongoing";

        if (_state == AT_SUBSCRIBED) {
            local topic   = "$iothub/twin/PATCH/properties/reported/?$rid=" + _reqCounter;
            local message = _mqttclient.createmessage(topic, status);
            local id      = message.sendasync(_onSendUpdateRequest.bindenv(this));

            _reqCounter++;
            _twinUpdateRequestCb = onComplete;
            _log("Message to " + topic + " was scheduled as " + id);
        } else {
            throw "AzureTwin is not connected";
        }
    }

    // Initiate new connection procedure device is disconnected.
    function reconnect() {
        _connect();
    }

    // ----------------- private API ---------------

    // Sends subscribe request message
    function _subscribe() {
        if (_state == AT_CONNECTED) {
            local topics = ["$iothub/twin/res/#","$iothub/methods/POST/#", "$iothub/twin/PATCH/properties/desired/#"];
            local id = _mqttclient.subscribe(topics, "AT_MOST_ONCE", _onSubscribe.bindenv(this));
            _state = AT_SUBSCRIBING;
            _log("Subscribing (" + id + ")...");
        }
    }

    // Callback in response to subscribe request status
    function _onSubscribe(messages) {
        foreach (i, mess in messages) {
            if (typeof mess != "array") mess = [mess];
            foreach(request in mess) {
                _log("Subscription succeeded. rc = " + request.rc);
                if (request.rc == 0) {
                    if (_state == AT_SUBSCRIBING) _state = AT_SUBSCRIBED;
                } else {
                    _mqttclient.disconnect();
                    _state = AT_DISCONNECTED;
                }
            }
        }
        _notifyState();
    }

    // Notify listener about connection status change
    function _notifyState() {
        if (_connectionListener != null) {
            try {
                _connectionListener(_state);
            } catch (e) {
                _log("Exception while calling user connection listener:" + e);
            }
        }
    }

    // Initiates new MQTT connection (if disconnected)
    function _connect() {
        if (AT_DISCONNECTED == _state) {
            _log("Connecting...");

            local cn            = AzureIoTHub.ConnectionString.Parse(_deviceConnectionString);
            local devPath       = "/" + cn.DeviceId;
            local username      = cn.HostName + devPath + AZURE_IOTHUB_API_VERSION;
            local resourcePath  = "/devices" + devPath + AZURE_IOTHUB_API_VERSION;
            local resourceUri   = AzureIoTHub.Authorization.encodeUri(cn.HostName + resourcePath);
            local passwDeadTime = AzureIoTHub.Authorization.anHourFromNow();
            local sas           = AzureIoTHub.SharedAccessSignature.create(
                resourceUri, null, cn.SharedAccessKey, passwDeadTime
            ).toString();

            local options = {
                username        = username,
                password        = sas
            };

            _mqttclient.connect(_onConnection.bindenv(this), options);

            _state = AT_CONNECTING;
        }
    }

    // Callback in response to message about Twin full JSON document request
    function _onSendStatusRequest(id, rc) {
        if (rc != 0) {
            if (_twinStatusRequestCb != null) {
                try {
                    _twinStatusRequestCb("Status request error: " + rc, null);
                } catch (e) {
                    _log("User exception at _twinStatusRequestCb:" + e);
                }
            }
        } else {
            _log("Status request was sent");
        }
    }

    // Callback in response to message with Twin Reported properties update
    function _onSendUpdateRequest(id, rc) {
        if (rc != 0) {
            if (_twinUpdateRequestCb != null) {
                try {
                    _twinUpdateRequestCb("Update request  error: " + rc, null);
                } catch (e) {
                    _log("User exception at _twinUpdateRequestCb:" + e);
                }
            }
        } else {
            _log("Update request was sent");
        }
    }

    // Sends a message with method invocation status
    function _sendMethodResponse(id, error) {
        local topic   = format("$iothub/methods/res/%s/?$rid=%s", error, id);
        local message = _mqttclient.createmessage(topic, "");
        local id      = message.sendasync();

        _log("Message to " + topic + " was scheduled as " + id);
    }

    // Process message initiated by IoT Hub
    function _processMessage(topic, body) {
        local index = null;

        // response for state request and patch
        if (null != (index = topic.find("$iothub/twin/res/"))) {

            local res = split(topic, "/");
            local cb  = _twinStatusRequestCb;

            if (null != cb ) {
                _twinStatusRequestCb = null;
            } else {
                cb = _twinUpdateRequestCb;
                _twinUpdateRequestCb = null;
            }

            // service send message to the topic $iothub/twin/res/{status}/?$rid={request id}
            local status = res[3];

            if (status == "200")  status = null;

            try {
                cb(status, body);
            } catch(e) {
                _error("User code excpetion at _twinStatusRequestCb:" + e);
            }

        // desired properties update
        } else if (null != (index = topic.find("$iothub/twin/PATCH/properties/desired/?$version="))) {

            local version = split(topic, "=")[1];

            if (_twinUpdateHandler != null) {
                try {
                    _twinUpdateHandler(version, body);
                } catch (e) {
                    _error("User code exception at _twinUpdateHandler:" + e);
                }
            }

        // method invocation
        } else if (null != (index = topic.find("$iothub/methods/POST/"))) {

            local sliced = split(topic, "/=");
            local method = sliced[3];
            local reqID  = sliced[5];

            if (_methodInvocationHandler != null) {
                try {
                    local res = _methodInvocationHandler(method, body);
                    _sendMethodResponse(reqID, res);
                } catch (e) {
                    _error("User code exception at _methodInvocationHandler:" + e);
                    _sendMethodResponse(reqID, "500");
                }
            }
        }
    }

    // ------------------ MQTT handlers ---------------------

    // Connection Lost handler
    function _onDisconnected() {
        _state = AT_DISCONNECTED;
        _log("Disconnected");

        if (null != _connectionListener) _connectionListener("disconnected");
    }

    // Notification about message is received by IoT Hub
    function _onDelivery(messages) {
        foreach(message in messages) {
            _log("Message "  + message + " was delivered");
        }
    }

    // Notification about new message from IoT Hub
    function _onMessage(messages) {
        foreach (i, message in messages) {
            local topic = message["topic"];
            local body  = message["message"];
            _log("Message received with " + topic + " " + body);

            _processMessage(topic, body);
        }
    }

    // Status update abut new connection request
    function _onConnection(rc, blah) {
        _log("Connected: " + rc + " " + blah);

        if (rc == 0) {
            _state = AT_CONNECTED;
        } else {
            _state = AT_DISCONNECTED;
        }

        _notifyState();
        _subscribe();
    }

    // ------------------ service functions ---------------------

    // Metafunction to return class name when typeof <instance> is run
    function _typeof() {
        return "AzureTwin";
    }

    // Information level logger
    function _log(txt) {
        if (ENABLE_DEBUG) {
            server.log("[" + (typeof this) + "] " + txt);
        }
    }

    // Error level logger
    function _error(txt) {
        server.error("[" + (typeof this) + "] " + txt);
    }
}

///=====================================================

pp <- PrettyPrinter(null, false);
print <- pp.print.bindenv(pp);


const SMALL_MESSAGE = "{\"tagata\" : \"bubuka\"}";

const MEDIUM_MESSAGE =  "{    _id: '{{objectId()}}',    index: '{{index()}}',    guid: '{{guid()}}',    isActive: '{{bool()}}',    balance: '{{floating(1000, 4000, 2, '0,0.00')}}',    picture: 'http://placehold.it/32x32',    age: '{{integer(20, 40)}}',    eyeColor: '{{random(\"blue\", \"brown\", \"green\")}}',    name: '{{firstName()}} {{surname()}}',    gender: '{{gender()}}',    company: '{{company().toUpperCase()}}',    email: '{{email()}}',    phone: '+1 {{phone()}}',    address: '{{integer(100, 999)}} {{street()}}, {{city()}}, {{state()}}, {{integer(100, 10000)}}',    about: '{{lorem(1, \"paragraphs\")}}',    registered: '{{date(new Date(2014, 0, 1), new Date(), \"YYYY-MM-ddThh:mm:ss Z\")}}',    latitude: '{{floating(-90.000001, 90)}}',    longitude: '{{floating(-180.000001, 180)}}',);))";

const authToken = "";

server.log("Using connection string: " + authToken);

local cn = AzureIoTHub.ConnectionString.Parse(authToken);
local devPath = "/" + cn.DeviceId;
local resourcePath = "/devices" + devPath;
local resourceUri = AzureIoTHub.Authorization.encodeUri(cn.HostName + resourcePath);
local sas = AzureIoTHub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow()).toString();
local username = cn.HostName + devPath + "/api-version=2016-11-14";

subscribeBalance <- 0;
unsubscribeBalance <- 0;

deliveryBalance <- 0;
disconnectCount <- 0;
connectDisconnectCounter <- 0;
testOngoing <- false;
messageTestCallback <- null; 

function getSubscribeString(subStrings, numOfElem) {
    local result = ""; 
    for (local i = 0; i < numOfElem; i++) {
        result += subStrings + "/";
    }
    return result + "#";
}

function onmessage(message) {
    // add message from another imp test
}

function ondelivery(messageId) {
    ::print("ondelivery:");
    ::print(messageId);
}

function disconnected() {
    ::print("disconnected");
    testOngoing = false; 
   // mqttclient.connect(connectDone, options);
}

function subscribeDone(msg) {
    subscribeBalance--;
}

function unsubscribeDone(msg) {
    unsubscribeBalance--;
}

function ondone(msgid, rc) {
    ::print("ondone: " + rc + " " + msgid);
}

function asyncDelivery(msg, rc) {
    deliveryBalance--;

    if (deliveryBalance < 1) {
        messageTestCallback();
    }
    
}

function subscribeTest(code, message) {
    server.log(message);
    local result;
    local subsString = [ "devices", cn.DeviceId, "messages", "devicebound"];
    for (local i = 3; i > 0; i--) {
        result = mqttclient.subscribe(getSubscribeString(subsString, i), "AT_LEAST_ONCE", subscribeDone);
        server.log("Subscribe result: "  + result);
        subscribeBalance++; 
    }
    unsubscribeTest();
}

function unsubscribeTest() {
    local result;
    local subsString = [ "devices", cn.DeviceId, "messages", "devicebound"];
    for (local i = 3; i > 0; i--) {
        result = mqttclient.unsubscribe(getSubscribeString(subsString, i));
        server.log("Unsubscribe result: "  + result);
    }
    smallMessageTest() 
}

function smallMessageTest() {
    messageTestCallback = mediumMessageTest;
    messageSendTest(SMALL_MESSAGE, 10); 
};

function mediumMessageTest() {
    messageTestCallback = bigMessageTest; 
    messageSendTest(MEDIUM_MESSAGE, 8);
};


function bigMessageTest() {
    messageTestCallback = endTest; 
    messageSendTest(MEDIUM_MESSAGE, 5);
};

function endTest() {
    testOngoing = false;
}

function messageSendTest(message, count) {

    for (local i = 0; i < count; i++) {
        local message = mqttclient.createmessage("$iothub/twin/PATCH/properties/reported/?$rid=" + i, message);
        local result = message.sendsync();
        server.log("Twin sync update result = " + result);
    }

    for (local i = 0; i < count; i++) {
        deliveryBalance++;
        local message = mqttclient.createmessage("$iothub/twin/PATCH/properties/reported/?$rid=" + i, message);
        local result = message.sendasync(asyncDelivery);
        server.log("Twin async update result = " + result);
    }
}



function connectToDisconnect(rc, b) {
    mqttclient.disconnect(disconnectToConnect);
    server.log("connect to disconnect")
}

function disconnectToConnect() { 
    server.log("disconnect to connect")
    if (connectDisconnectCounter < 1) { 
        connectDisconnectCounter++;
        mqttclient.connect(connectToDisconnect, options);
    } else {
        // go to next test
        connectDisconnectCounter = 0; 

        mqttclient.connect(subscribeTest, options);
    }
} 

function init() {
    if (testOngoing) {
        return; 
    }
    testOngoing = true;

    if (subscribeBalance != 0) {
        server.log("subscribeBalance: " + subscribeBalance);
    }

    if (unsubscribeBalance != 0) {
        server.log("unsubscribeBalance: " + unsubscribeBalance);
    }
    

    if (deliveryBalance != 0) {
        server.log("deliveryBalance: " + deliveryBalance);
    }


    if (disconnectCount != 0) {
        server.log("disconnectCount: " + disconnectCount);
    }

    mqttclient.connect(connectToDisconnect, options);
}

function recallInit() {
    init();
    imp.wakeup(10, recallInit);
}

mqttclient <- mqtt.createclient("ssl://" + cn.HostName, cn.DeviceId, onmessage, ondelivery, disconnected);
// mqttclient2 <- mqtt.createclient("tcp://" + cn.HostName, cn.DeviceId, onmessage, ondelivery, disconnected);
options <- { username = username, password = sas };

recallInit();