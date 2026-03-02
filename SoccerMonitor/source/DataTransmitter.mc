using Toybox.Communications;
using Toybox.System;

class DataTransmitter {

    // Cloud endpoint URL — replace with your Cloud Run URL
    var cloudUrl = "CLOUD_URL_PLACEHOLDER";

    // Send data to cloud via HTTP
    function send(payload) {
        sendToCloud(payload);
    }

    // Direct HTTP POST to cloud backend
    function sendToCloud(payload) {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            cloudUrl,
            payload,
            options,
            method(:onCloudResponse)
        );
    }

    function onCloudResponse(responseCode as Toybox.Lang.Number, data as Toybox.Lang.Dictionary or Toybox.Lang.String or Null) as Void {
        if (responseCode == 200 && data != null) {
            // Could receive fatigue predictions back from cloud
            if (data.hasKey("fatigue_prediction")) {
                // Update UI with cloud-enhanced prediction
            }
        }
    }

    function stop() {
        // Cleanup if needed
    }
}

class CommListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }
    function onComplete() {
        // Data sent successfully
    }
    function onError() {
        // BLE transmission failed — will retry next cycle
        System.println("Transmit error");
    }
}
