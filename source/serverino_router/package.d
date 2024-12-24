module serverino_router;

public
{
    import http_status;
    import serverino_router.router;
    import serverino_router.params;
    import serverino_router.utils;
}

unittest
{
    string baseUrl = "http://localhost:8080";
    import std.process;
    auto build = pipeProcess(["dub", "build", "--root=test_server"]);
    wait(build.pid);
    auto pipes = pipeProcess("./test_server/test_server");

    import std.net.curl;
    assert(get(baseUrl) == "OK Get /");
    assert(post(baseUrl ~ "/submit", []) == "OK Post /submit");
    assert(put(baseUrl ~ "/submit", []) == "OK Put /submit");
    // assert(del(baseUrl ~ "/submit"));

    // Stop the service
    kill(pipes.pid, 9);
    wait(pipes.pid);
}
