
class SubscribeTest extends TestBase {

    urls = null;

	constructor() {
        urls =[];

		_create();

		imp.wakeup(1, _connect.bindenv(this));

		imp.wakeup(1, _unsubscribe.bindenv(this));
	}

	function _subscribe() {
		// test closed
		if (client == null) return;

		while (true) {
			try {
				// number of topics
				local not =	 ::irand(9) + 1;
				local topics = [];
				while(not--) {
					local url = _getUrl();
					print("Subscribing " + url)
					topics.append(url);
				}

				local id = client.subscribe(topics, "AT_MOST_ONCE", _onsubscribed.bindenv(this));

				if (id < 0) {
					print("Can't subscribe next group. Err=" + id )

					imp.wakeup(20, _subscribe.bindenv(this));
				}

				print("Subscribe request " + id + " was sent");

				local next = ::irand(100);
				if (next > 50) break;

				print("Subscribe next at once");
			} catch (e) {
				print("Critical error at " + this + " Exception:" + e);
				break;
			}
		}
	}

	function _unsubscribe() {
		// test closed
		if (client == null) return;

		if (urls.len() > 0) {

			local not = ::irand(urls.len() - 1) + 1;

			local topics = [];

			while(not--) {
				local url = urls.remove(0);
				print("Unsubscribing " + url);
				topics.append(url);
			}

			client.unsubscribe(topics);

			print("Unsubscribe request was sent");
		}

		imp.wakeup(1, _unsubscribe.bindenv(this));
	}

	function _onsubscribed(result) {
		print("_onsubscribed");
		print(result);

		_subscribe();
	}

	function _onconnected(rc, info) {
		print("OnConnected " + rc + ":" + info);

		if (rc == 0) {
			_subscribe();
		} else {
			print("Critical error. Test aborted");
		}
	}

    function _getUrl() {
        local url = CLOUD2DEVICE_URL;
        local level = 0;

        while (true) {
            local rand = ::irand(100);
            if (rand > 50 && level < MAX_TOPIC_URL_DEPTH) {
                url = url + "/bubuka";
            } else {
                url = url + "/#";
                break;
			}

			level++;
        }
		urls.append(url);

		return url;
    }

	function _typeof() {
		return "SubscribeTest";
	}
}