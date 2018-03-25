class TestBase {

	client 				= null;
	options 			= null;
	device2cloud_url 	= null;

	function shutdown(onComplete) {
        local gracefully = :: irand(100);

        if (gracefully) client.disconnect();

        client = null;

		print ("Test " + this + " closed");

		onComplete();
	}

	function _create(authToken) {
		print("Creating client");

		local cn = AzureIoTHub.ConnectionString.Parse(authToken);
		local devPath = "/" + cn.DeviceId;
		local resourcePath = "/devices" + devPath;
		local resourceUri = AzureIoTHub.Authorization.encodeUri(cn.HostName + resourcePath);

		local password 	= AzureIoTHub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow()).toString();
		local username 	= cn.HostName + devPath + "/" + AZURE_HTTP_API_VERSION;
		local url 		= "ssl://" + cn.HostName;

		device2cloud_url = "devices/" + cn.DeviceId + "/messages/events/";
		options = {"username" : username, "password" : password};

		client = mqtt.createclient(url, cn.DeviceId, _onmessage.bindenv(this), _ondelivery.bindenv(this), _disconnected.bindenv(this));
	}

	function _connect() {
		print("Connecting");
		client.connect(_onconnected.bindenv(this), options);
	}

	function _onmessage(message) {
		print("_onmessage: " + this);
	}

	function _ondelivery(message) {
		print("_ondelivery: " + this);
	}

	function _disconnected() {
		print("_disconnected: " + this);
	}


	function _typeof() {
		return "TestBase";
	}


}