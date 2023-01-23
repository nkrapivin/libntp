/// @description request NTP time

/// @param {Real} wholeRawReal NTP raw seconds
/// @param {Real} fractionalRawReal NTP raw fractional seconds
/// @param {Real} gamemakerTimeReal Time in gamemaker datetime_* format
/// @desc YOU are responsible for handling the time crap.
function onNtpTime(wholeRawReal, fractionalRawReal, gamemakerTimeReal) {
	show_message_async(
		"NTP Result:"
		/* this one will NOT be a sane decimal representation but who cares anyway */
		+ "\nRaw NTP time = " + string(wholeRawReal) + "." + string(fractionalRawReal)
		/* YOU are responsible for handling the timezones crap!! */
		+ "\nGameMaker time (raw) = " + string(gamemakerTimeReal)
		+ "\nGameMaker time = " + date_datetime_string(gamemakerTimeReal)
		+ "\nend."
	);
}

// use some random server that's closest to the player
// might want to use os_get_region() and pick the closest pool.ntp.org mirror
// for me this one is the closest and works great
if (!ntp_request_time(onNtpTime, "1.ru.pool.ntp.org")) {
	show_message_async("Unable to make an NTP request for some reason, no network?");
}



