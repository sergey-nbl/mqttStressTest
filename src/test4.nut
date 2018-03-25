@include "github:sergey-nbl/AzureTwins/AzureTwins.agent.lib.nut"


class SubscribeTest  extends AzureTwin {

	constructor(authToken) {
		base.constructor(authToken, connectionHandler.bindenv(this), twinUpdateHandler.bindenv(this));

		_debug = false;
	}

	function run() {
		local nextMethod = ::irand(100);

		if (nextMethod < 33) {
			getCurrentStatus(onCurrentStatus.bindenv(this));
		} else if (nextMethod > 66) {
			local status = { "field1" : ::irand(100) };
			updateStatus(http.jsonencode(status), onUpdateStatus.bindenv(this));
		} else {
			restart();
		}
	}

	function restart() {
		print("Resubsribing");
		local topics = ["$iothub/twin/res/#","$iothub/methods/POST/#", "$iothub/twin/PATCH/properties/desired/#"];
		try {
			_mqttclient.unsubscribe(topics);
			_state  = CONNECTED;
			_subscribe();
		} catch (e) {
			print("Can't unsubscribe: " + e);
			print("Continue as SUBSCRIBED");
			run();
		}
	}

	function onCurrentStatus(err, body) {
		print("onCurrentStatus: err=" + err);
		run();
	}

	function onUpdateStatus(err, body) {
		print("onUpdateStatus: err=" + err );
		run();
	}

	function shutdown(onComplete) {
        local gracefully = :: irand(100);

        if (gracefully) _mqttclient.disconnect();

		print ("Test " + this + " closed");

		onComplete();
	}

	function connectionHandler(state) {
		print("Twin connection status " + state);

		if (state == SUBSCRIBED) {
			run();
		}
	}

	function twinUpdateHandler(version, body) {
		print("Twin update: " + version + " : " + body);
	}

	function _typeof() {
		return "SubscribeTest";
	}
}