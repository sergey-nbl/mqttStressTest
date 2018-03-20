
class Device2CloudTest extends TestBase {

	client = null;

	constructor() {
		_create();

		imp.wakeup(1, _connect.bindenv(this));
	}

	function shutdown(onComplete) {
		client.disconnect();
		client = null;

		onComplete();
	}


	function _create() {
		print("Creating client");

		client = mqtt.createclient(URL, DEVICE_ID, _onmessage, _ondelivery.bindenv(this), _disconnected);
	}


	function _connect() {
		print("Connecting");
		client.connect(_onconnected.bindenv(this), OPTIONS);
	}

	function _sendsync() {
		local retry = 10;

		local rand = ::irand(MAX_MESSAGE_SIZE);

		while (true) {
			try {
				local body = blob(rand).tostring();
				local message = client.createmessage(DEVICE2CLOUD_URL, body);
				local id = message.sendsync();
				print("Message was sent");

				// send next at once?
				local sendNext = ::irand(100) > 50;
				if (!sendNext) 	break;

				print("Sending next immediately");
			} catch (e) {
				if (e.find("cannot create blob") != null && retry > 0) {

					retry--;

					rand = rand / 2;
					continue;
				}

				print("Critical error " + e);
				break;
			}
		}
	}

	function _ondelivery(messages) {
		foreach(id in messages) print("Delivered message " + id);

		if (client != null) imp.wakeup(10, _sendsync.bindenv(this));
	}


	function _onconnected(rc, info) {
		print("OnConnected " + rc + ":" + info);

		if (rc == 0) {
			_sendsync();
		} else {
			print("Critical error. Test aborted");
		}
	}

	function _disconnect() {
		print("Disconnecting");
		client.disconnect(_disconnected.bindenv(this));

		// try to avoid IP address ban
		imp.wakeup(10, _run.bindenv(this));
	}

	function _typeof() {
		return "Device2CloudTest";
	}
}