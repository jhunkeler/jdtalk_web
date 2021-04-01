module app;

import jdtalk.core;
import vibe.core.core : runApplication;
import vibe.http.server;
import vibe.http.router;
import std.string;
import std.process : environment;
import std.conv : to;

enum MAX_LIMIT = 100_000;
enum MAX_LIMIT_PATTERN = 100;
enum MAX_LIMIT_SALAD = 512;
enum MAX_LIMIT_FORMAT = 256;
__gshared string dataRoot;
__gshared dict_t dicts;

void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    if (req.path == "/") {
        long i = 0;
        auto limit = req.query.get("limit", "1").to!long;
        auto custom_format = req.query.get("format", null);
        auto pattern = req.query.get("pattern", null);
        auto exactMatch = req.query.get("exact", "false").to!bool;
        auto salad = req.query.get("salad", "0").to!int;
        auto rCase = req.query.get("rcase", "false").to!bool;
        auto hCase = req.query.get("hcase", "false").to!bool;
        auto haxor = req.query.get("leet", "false").to!bool;

        if (custom_format !is null && custom_format.length > MAX_LIMIT_FORMAT) {
            res.bodyWriter.write(format("Requested string is too long: %d (MAX: %d)\n",
                        custom_format.length, MAX_LIMIT_FORMAT));
            return;
        }

        if (salad > MAX_LIMIT_SALAD) {
            res.bodyWriter.write(format("Requested too much salad: %d (MAX: %d)\n",
                        salad, MAX_LIMIT_SALAD));
            return;
        }

        if (pattern is null && limit > MAX_LIMIT) {
            res.bodyWriter.write(format("Requested too many: %d (MAX: %d)\n",
                        limit, MAX_LIMIT));
            return;
        }
        else if (pattern !is null && limit > MAX_LIMIT_PATTERN) {
            res.bodyWriter.write(format("Requested too many for pattern: %d (MAX: %d)\n",
                        limit, MAX_LIMIT_PATTERN));
            return;
        }

        if (pattern !is null && !searchDict(dicts, pattern)) {
            res.bodyWriter.write(format("Word not available in dictionary: %s\n", pattern));
            return;
        }

        while(true) {
            string output;

            if (salad) {
                output = talkSalad(dicts, salad);
            }
            else if (custom_format) {
                output = talkf(dicts, custom_format);
            }
            else {
                output = talkf(dicts, "%a %n %d %v");
            }

            if (pattern !is null) {
                if (exactMatch && !hasWord(pattern, output)) {
                    continue;
                }
                else if (!exactMatch && !output.canFind(pattern)) {
                    continue;
                }
            }

            if (rCase) {
                output = randomCase(output);
            }
            else if (hCase) {
                output = hillCase(output);
            }
            else if (haxor) {
                output = leetSpeak(output);
            }

            res.bodyWriter.write(format("%s\n", output));

            if (limit > 0) {
                i++;
                if (i == limit)
                    break;
            }
        }
    }
}


int main(string[] args)
{
    dataRoot = environment["JDTALK_DATA"];
    dicts = getData(dataRoot);

    auto routes = new URLRouter;
    routes.get("/", &handleRequest);

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::1", "127.0.0.1"];
    auto l = listenHTTP(settings, routes);
    scope (exit) l.stopListening();

    runApplication();
    return 0;
}
