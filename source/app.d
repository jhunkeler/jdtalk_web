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
__gshared string dataRoot;
__gshared dict_t dicts;

void handleRequest(scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    if (req.path == "/") {
        long i = 0;
        auto limit = req.query.get("limit", "1").to!long;
        auto pattern = req.query.get("pattern", null);
        auto exactMatch = req.query.get("exact", "false").to!bool;

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
            string output = talk(dicts);

            if (pattern !is null) {
                if (exactMatch && !hasWord(pattern, output)) {
                    continue;
                }
                else if (!exactMatch && !output.canFind(pattern)) {
                    continue;
                }
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
