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

@include "testbase.nut"
@include "test1.nut"
@include "test2.nut"
@include "test3.nut"
@include "test4.nut"

pp <- PrettyPrinter(null, false);
print <- pp.print.bindenv(pp);


const authToken = "@{IOT_HUB_CONNECTION}";


const rebootChance = 30;
const stopChance   = 70;
const chaosTimer   = 100;

MAX_MESSAGE_SIZE <- 524288; //512Kb

MESSAGE_PERIOD <- 10; //sec

MAX_TOPIC_URL_DEPTH <- 10;

nextTest <- null;

print("Test (re)started. Using connection string: " + authToken);

function init() {
	local cn = AzureIoTHub.ConnectionString.Parse(authToken);
	local devPath = "/" + cn.DeviceId;
	local resourcePath = "/devices" + devPath;
	local resourceUri = AzureIoTHub.Authorization.encodeUri(cn.HostName + resourcePath);

	PASSWORD <- AzureIoTHub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow()).toString();
	USERNAME <- cn.HostName + devPath + "/" + AZURE_HTTP_API_VERSION;
	URL 		<- "ssl://" + cn.HostName;
	DEVICE_ID 	<- cn.DeviceId;

	DEVICE2CLOUD_URL <- "devices/" + cn.DeviceId + "/messages/events/";

	CLOUD2DEVICE_URL <- "devices/" + cn.DeviceId + "/messages/devicebound";

	OPTIONS <- {"username" : USERNAME, "password" : PASSWORD};

	print("Options");print(OPTIONS);

	runNext();
}

function chaos() {
	local rand = irand(100);

	if (rand < rebootChance) {
		print("Time to reboot");
		server.restart();
	} else if (rand > stopChance) {
		print("Time to shutdown");
		nextTest.shutdown(runNext);
	} else {
		imp.wakeup(chaosTimer, chaos);
	}
}

function runNext() {
	local rand = irand(tests.len() - 1);

	nextTest = tests[rand]();

	print("Running " + (typeof nextTest));

	imp.wakeup(chaosTimer, chaos);
}

function irand(max) {
    local roll = (1.0 * math.rand() / RAND_MAX) * (max + 1);
    return roll.tointeger();
}

tests <- [CreateClientTest, ConnectDisconnectTest, Device2CloudTest, SubscribeTest];

init();


