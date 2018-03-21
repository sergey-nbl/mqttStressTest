
class Device2CloudTest extends TestBase {

	constructor() {
		_create();

		imp.wakeup(1, _connect.bindenv(this));
	}

	function _sendsync() {

		if (client == null) return;

		local retry = 10;

		local rand = ::irand(MAX_MESSAGE_SIZE);

		while (true) {
			try {
				local body = blob(rand).tostring();
				local message = client.createmessage(DEVICE2CLOUD_URL, body);

				rand = ::irand(100);
				if (rand < 50) {
					local id = message.sendsync();
				} else {
					local id = message.sendasync(_onPushed.bindenv(this));
				}
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

				print("Critical error at " + this + ". Exception " + e);
				break;
			}
		}
	}

	function _onPushed(messId, rc) {
		print("_onPushed: " + messId + " rc=" + rc);
	}

	function _ondelivery(messages) {
		// test was closed
		if (client == null) return;

		print("Delivered message(s) at " + this + "[");
		foreach(id in messages)  print(id);
		print("]");

		local rand = ::irand(MESSAGE_PERIOD);
		imp.wakeup(rand, _sendsync.bindenv(this));
	}


	function _onconnected(rc, info) {
		print("OnConnected " + this + " rc=" + rc + " info=" + info);

		if (rc == 0) {
			_sendsync();
		} else {
			print("Critical error. Test aborted");
		}
	}


	function _typeof() {
		return "Device2CloudTest";
	}
}