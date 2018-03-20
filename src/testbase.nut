class TestBase {

	function _onmessage(message) {
		print("_onmessage");
	}

	function _ondelivery(message) {
		print("_ondelivery");
	}

	function _disconnected() {
		print("_disconnected");
	}


	function _typeof() {
		return "TestBase";
	}


}