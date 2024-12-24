import std.stdio;

import std.process;
import std.string;
import std.base64;
import std.conv : text;

import serverino;
import serverino_router;

mixin ServerinoMain!serverino_router;

void handler(Request request, Output output)
{
    output ~= i"OK $(request.method) $(request.path)".text;
}

@onWorkerStart void handleWorkerStart()
{
    getRoute!"/"(&handler);
    postRoute!"/submit"(&handler);
    putRoute!"/submit"(&handler);
    deleteRoute!"/submit"(&handler);
}
