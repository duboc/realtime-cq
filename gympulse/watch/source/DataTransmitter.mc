using Toybox.Communications;
using Toybox.System;

class DataTransmitter {

    // Cloud endpoint URL — replaced at build time
    var cloudUrl = "https://gympulse-a4er43fhfq-rj.a.run.app/api/ingest";

    // Connection status
    var connected = false;

    // Cloud-returned values
    var cloudFatigue = 0;
    var cloudRecovery = 0;
    var cloudFatigueZone = "";
    var cloudRecoveryETA = 0;

    // Send data to cloud via HTTP
    function send(payload) {
        sendToCloud(payload);
    }

    // Direct HTTP POST to GymPulse backend
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
        if (responseCode == 200) {
            connected = true;
            if (data != null) {
                // Parse fatigue and recovery from server response
                if (data.hasKey("fat")) {
                    cloudFatigue = data["fat"];
                }
                if (data.hasKey("rec")) {
                    cloudRecovery = data["rec"];
                }
                if (data.hasKey("fz")) {
                    cloudFatigueZone = data["fz"];
                }
                if (data.hasKey("recoveryETA")) {
                    cloudRecoveryETA = data["recoveryETA"];
                }
            }
        } else {
            connected = false;
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
        System.println("Transmit error");
    }
}
