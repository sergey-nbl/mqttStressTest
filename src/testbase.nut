class TestBase {

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