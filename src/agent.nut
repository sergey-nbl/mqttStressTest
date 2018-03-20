// MIT License
//
// Copyright 2018 Electric Imp
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

pp <- PrettyPrinter(null, false);
print <- pp.print.bindenv(pp);


const SMALL_MESSAGE = "{\"tagata\" : \"bubuka\"}";

const MEDIUM_MESSAGE =  "{    _id: '{{objectId()}}',    index: '{{index()}}',    guid: '{{guid()}}',    isActive: '{{bool()}}',    balance: '{{floating(1000, 4000, 2, '0,0.00')}}',    picture: 'http://placehold.it/32x32',    age: '{{integer(20, 40)}}',    eyeColor: '{{random(\"blue\", \"brown\", \"green\")}}',    name: '{{firstName()}} {{surname()}}',    gender: '{{gender()}}',    company: '{{company().toUpperCase()}}',    email: '{{email()}}',    phone: '+1 {{phone()}}',    address: '{{integer(100, 999)}} {{street()}}, {{city()}}, {{state()}}, {{integer(100, 10000)}}',    about: '{{lorem(1, \"paragraphs\")}}',    registered: '{{date(new Date(2014, 0, 1), new Date(), \"YYYY-MM-ddThh:mm:ss Z\")}}',    latitude: '{{floating(-90.000001, 90)}}',    longitude: '{{floating(-180.000001, 180)}}',);))";

const authToken = "@{IOT_HUB_CONNECTION}";

server.log("Using connection string: " + authToken);

local cn = AzureIoTHub.ConnectionString.Parse(authToken);
local devPath = "/" + cn.DeviceId;
local resourcePath = "/devices" + devPath;
local resourceUri = AzureIoTHub.Authorization.encodeUri(cn.HostName + resourcePath);
local sas = AzureIoTHub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow()).toString();
local username = cn.HostName + devPath + AZURE_HTTP_API_VERSION;

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