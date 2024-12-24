module serverino_router.utils;

//import std.typecons;
//import std.conv;
//import std.traits;
//import std.meta;
//import std.logger;
//import std.algorithm.searching : canFind;
import std.datetime : Clock, UTC, SysTime, Duration;
//import std.string;
//import std.json;

import serverino;
import json_serialization;
import http_status;

// To track the request duration during debug mode
SysTime startTime;

/* Utility function to set the content type
 * ```d
 * output.setContentType("application/json");
 * ```
 */
void setContentType(Output output, string type)
{
    output.addHeader("Content-Type", type);
}

/* Utility function to write JSON to output
 * ```d
 * @endpoint @route!"/ping"
 * void pingHandler(Request request, Output output)
 * {
 *     output.writeJsonBody(["ok": true]);
 * }
 * ```
 */
void writeJsonBody(T)(Output output, T data, HttpStatus status = HttpStatus.ok)
{
    output.status = status;
    output.setContentType("application/json");
    output.write(data.serializeToJSONValueString);
}

void setStartTime()
{
    // Set only if no other routes initialized startTime
    if (startTime == SysTime())
        startTime = Clock.currTime(UTC());
}

Duration getDuration()
{
    return (Clock.currTime(UTC()) - startTime);
}
