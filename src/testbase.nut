class TestBase {

	client = null;

	function shutdown(onComplete) {
        local gracefully = :: irand(100);

        if (gracefully) client.disconnect();

        client = null;

		print ("Test " + this + " closed");

		onComplete();
	}

	function _create() {
		print("Creating client");

		client = mqtt.createclient(URL, DEVICE_ID, _onmessage.bindenv(this), _ondelivery.bindenv(this), _disconnected.bindenv(this));
	}

	function _connect() {
		print("Connecting");
		client.connect(_onconnected.bindenv(this), OPTIONS);
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