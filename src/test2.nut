
class ConnectDisconnectTest extends TestBase {

	constructor(authToken) {
		_create(authToken);

		imp.wakeup(1, _run.bindenv(this));
	}

	function _run() {
		print("Connecting....");
		client.connect(_onconnected.bindenv(this), options);
	}

	function _disconnected() {
		print("Disconnected");
	}

	function _onconnected(rc, info) {
		print("OnConnected " + rc + ":" + info);

		if (rc == 0) {
			_disconnect();
		} else {
			print("Critical error. Test aborted");
		}
	}

	function _disconnect() {
		print("Disconnecting...");
		client.disconnect(_disconnected.bindenv(this));

		// try to avoid IP address ban
		imp.wakeup(::irand(10), _run.bindenv(this));
	}

	function _typeof() {
		return "ConnectDisconnectTest";
	}
}