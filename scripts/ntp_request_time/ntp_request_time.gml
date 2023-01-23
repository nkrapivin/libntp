//feather ignore GM1044
//feather ignore GM2017

// whether to do NTPTime = NTPTime - (NTPTime - TimeWhenThePacketWasSent)
// set this to false if you are having bizzare time issues you cannot explain
#macro NTP_CONFIG_FIXUP_SEND_TIME true

/* usually you shouldn't touch this */
#macro NTP_DEFAULT_PORT 123
/* sadly this doesn't account for leap seconds, nor do I care really */
#macro NTP_SECONDS_IN_DAYS 86400
/* difference between the NTP epoch and GameMaker epoch */
#macro NTP_GM_DAY_DIFFERENCE 2
/* taken from some C header */
#macro NTP_UINT32_MAX 4294967295


/*
	Lazy-initialize the socket because console platforms
	are very picky when it comes to calling online stuff
	and unneccesary network calls may get you into trouble.
	
	So if you never call ntp_request_time in your game, no network APIs
	will ever be used.
*/
global.__ntpSocket = -1;


global.__ntpTimeSent = -1;
global.__ntpIsBusy = false;
global.__ntpOnResult = undefined;
global.__ntpPort = -1;

/// @param {Function} onResultFunction function to be called when a result is obtained
/// @param {String} urlString url of the NTP server you want to get the time from
/// @param {Real} [portRealOpt] network port of the NTP server, optional
/// @returns {Bool} whether a request has been made successfully
/// @desc Makes a request to the NTP server if not busy and calls the specified function when the time is obtained.
///
///       Returns true if the request has been made successfully,
///
///       Returns false if an NTP request is in progress,
///
///       Throws on fatal OS-level errors (inability to make a socket)
function ntp_request_time(onResultFunction, urlString, portRealOpt = NTP_DEFAULT_PORT) {
	if (global.__ntpIsBusy) {
		/* nope! already busy! */
		return false;
	}
	
	if (global.__ntpSocket < 0) {
		global.__ntpSocket = network_create_socket(network_socket_udp);
		if (global.__ntpSocket < 0) {
			/* uh oh, a fatal condition????? */
			throw "unable to create a UDP socket (are you on a console and forgot to enable NEX?)";
		}
	}
	
	if (is_undefined(onResultFunction) || is_undefined(urlString) || string_length(urlString) <= 0) {
		throw "why";
	}
	
	if (is_undefined(portRealOpt) || portRealOpt <= 0) {
		portRealOpt = NTP_DEFAULT_PORT;
	}
	
	var buff_ = buffer_create(48, buffer_fixed, 1);
	var buffsize_ = buffer_get_size(buff_);
	/* zero-fill the buffer */
	buffer_fill(buff_, 0, buffer_u8, 0, buffsize_);
	buffer_poke(buff_, 0, buffer_u8, 0x1b);
	var sent_ = network_send_udp_raw(
		global.__ntpSocket,
		urlString,
		portRealOpt,
		buff_,
		buffsize_
	);
	/* when the network packet was sent, used for fixupping */
	global.__ntpTimeSent = date_current_datetime();
	buffer_delete(buff_);
	if (sent_ != buffsize_) {
		/* whoops, failed somehow */
		return false;
	}
	
	/* all is good hopefully, wait for an async-networking event */
	global.__ntpPort = portRealOpt; /* so we know from which port to wait for packets */
	global.__ntpOnResult = onResultFunction;
	global.__ntpIsBusy = true;
	return true;
}

function ntp_buffer_bswap32(bufferId, offsetReal) {
	var b1_ = buffer_peek(bufferId, offsetReal + 0, buffer_u8);
	var b2_ = buffer_peek(bufferId, offsetReal + 1, buffer_u8);
	var b3_ = buffer_peek(bufferId, offsetReal + 2, buffer_u8);
	var b4_ = buffer_peek(bufferId, offsetReal + 3, buffer_u8);
	buffer_poke(bufferId, offsetReal + 0, buffer_u8, b4_);
	buffer_poke(bufferId, offsetReal + 1, buffer_u8, b3_);
	buffer_poke(bufferId, offsetReal + 2, buffer_u8, b2_);
	buffer_poke(bufferId, offsetReal + 3, buffer_u8, b1_);
}

/// @desc Please call this function inside the Async - Networking event.
function ntp_in_async_networking_event() {
	if (is_undefined(async_load) || async_load < 0 || event_type != ev_other || event_number != ev_async_web_networking) {
		throw "ntp_in_async_networking_event called in an invalid event";
	}
	
	var e_ = async_load;
	if (e_[? "type"] != network_type_data || e_[? "id"] != global.__ntpSocket || e_[? "port"] != global.__ntpPort) {
		exit;
		/* UDP is a connection-less protocol, we only care about the data */
	}
	
	//show_debug_message("break here!");
	
	var buff_ = e_[? "buffer"];
	// need to swap some bytes..
	
	ntp_buffer_bswap32(buff_, 40);
	ntp_buffer_bswap32(buff_, 44);
	var whole_ = buffer_peek(buff_, 40, buffer_u32);
	var fractional_ = buffer_peek(buff_, 44, buffer_u32);
	/*
		GameMaker's TDateTime format is days since December 30th 1899
		NTP's time format is seconds since January 1st 1900
		So we convert NTP seconds into days, and then add two days (just by adding two)
		
		The fractional part must be divided by UINT32_MAX to get the seconds fraction
		between 0 and .9999...~
		and then by 86400 to get GameMaker days.
		This loses precision very quickly but oh well.
	*/
	var gm_ = ((whole_ / NTP_SECONDS_IN_DAYS) + NTP_GM_DAY_DIFFERENCE)
		+     ((fractional_ / NTP_UINT32_MAX) / NTP_SECONDS_IN_DAYS);
	
	if (NTP_CONFIG_FIXUP_SEND_TIME) {
		/* only if we are SURE that the server time is after our send time */
		if (gm_ > global.__ntpTimeSent) {
			/* This isn't how it's supposed to work I think... so I made it configurable! */
			var networkdiff_ = gm_ - global.__ntpTimeSent;
			//show_debug_message("NTP: network time difference " + string_format(networkdiff_, 1, 17));
			gm_ = gm_ - networkdiff_;
		}
		else {
			/* this is technically never supposed to happen??????????????? */
			show_debug_message("NTP: somehow the server time was in the past compared to packet send time");
		}
	}
	
	global.__ntpIsBusy = false;
	global.__ntpOnResult(whole_, fractional_, gm_);
}

/// @returns {Bool} whether an NTP request is currently in progress
/// @desc Returns whether an NTP request is currently in progress
function ntp_is_busy() {
	return global.__ntpIsBusy;
}


