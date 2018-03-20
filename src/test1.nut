
class CreateClientTest  extends TestBase {

	clients = null;

	timer 	= null;

	constructor() {
		clients = [];

		timer = imp.wakeup(1, _run.bindenv(this));
	}

	function shutdown(onComplete) {
		imp.cancelwakeup(timer);
		clients = null;

		onComplete();
	}


	function _run() {

		local chance = irand(100);

		if (chance < 50) {
			_create();
		} else {
			_delete();
		}

		timer = imp.wakeup(1, _run.bindenv(this));
	}

	function _delete() {
		local len = clients.len();

		if (len > 0) {
			local index = irand(len - 1);

			print("Remove client " + index);
			clients.remove(index);
		}

	}

	function _create() {
		print("Creating client");
		local client = mqtt.createclient(URL, DEVICE_ID, _onmessage, _ondelivery, _disconnected);

		clients.append(client);
	}


}