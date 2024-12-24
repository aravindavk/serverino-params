module serverino_router.router;

import std.logger : tracef;
import std.algorithm.searching : canFind;

import serverino : Request, Output, endpoint;

import serverino_router.params;
import serverino_router.utils;

alias HandlerFunc = void function(Request, Output);
alias Routes = HandlerFunc[string];

// Below routes will be filled if Route helpers are used.
Routes postStaticRoutes = null;
Routes postRoutes = null;
Routes putStaticRoutes = null;
Routes putRoutes = null;
Routes getStaticRoutes = null;
Routes getRoutes = null;
Routes deleteStaticRoutes = null;
Routes deleteRoutes = null;

private bool pathMatch(const(Request) req, string pattern)
{
    auto data = matchedPathParams(pattern, req.path);

    if (!data.isNull)
        pathParams = data.get;

    return !data.isNull;
}

private bool isDynamicRoute(string pattern)
{
    return pattern.canFind(":") || pattern.canFind("*");
}

/* Define the post route in worker's scope.
 *
 * ```d
 * @onWorkerStart void handleWorkerStart()
 * {
 *   defineRoutes;
 *   // Other things in Worker
 * }
 *
 * void defineRoutes()
 * {
 *     postRoute!"/api/v1/folders"(&createFolderHandler);
 *     postRoute!"/api/v1/folders/:id:long/notes"(&createNoteHandler);
 * }
 * ```
 */
void postRoute(string pattern)(HandlerFunc handler)
{
    static if(pattern.isDynamicRoute)
        postRoutes[pattern] = handler;
    else
        postStaticRoutes[pattern] = handler;
}

/* Refer postRoute for usage.
 *
 * ```d
 * putRoute!"/api/v1/folders/:id:long"(&editFolderHandler);
 * ```
 */
void putRoute(string pattern)(HandlerFunc handler)
{
    static if(pattern.isDynamicRoute)
        putRoutes[pattern] = handler;
    else
        putStaticRoutes[pattern] = handler;
}

/* Refer postRoute for usage.
 *
 * ```d
 * getRoute!"/api/v1/folders"(&listFoldersHandler);
 * ```
 */
void getRoute(string pattern)(HandlerFunc handler)
{
    static if(pattern.isDynamicRoute)
        getRoutes[pattern] = handler;
    else
        getStaticRoutes[pattern] = handler;
}

/* Refer postRoute for usage.
 *
 * ```d
 * deleteRoute!"/api/v1/folders/:id:long"(&deleteFolderHandler);
 * ```
 */
void deleteRoute(string pattern)(HandlerFunc handler)
{
    static if(pattern.isDynamicRoute)
        deleteRoutes[pattern] = handler;
    else
        deleteStaticRoutes[pattern] = handler;
}

private void findRouteHandler(Request request, Output output, Routes staticRoutes, Routes routes)
{
    auto handler = request.path in staticRoutes;
    if (handler !is null)
    {
        (*handler)(request, output);
        return;
    }

    foreach(route; routes.byKeyValue)
    {
        if (request.pathMatch(route.key))
        {
            (*(route.value))(request, output);
            return;
        }
    }
}

@endpoint
void routesHandler(Request request, Output output)
{
    setStartTime;

    if (request.method == Request.Method.Post)
        findRouteHandler(request, output, postStaticRoutes, postRoutes);
    else if (request.method == Request.Method.Put)
        findRouteHandler(request, output, putStaticRoutes, putRoutes);
    else if (request.method == Request.Method.Get)
        findRouteHandler(request, output, getStaticRoutes, getRoutes);
    else if (request.method == Request.Method.Delete)
        findRouteHandler(request, output, deleteStaticRoutes, deleteRoutes);

    debug
    {
        tracef("Response %s %s - %s (%s)", request.method, request.path, output.status, getDuration.toString);
    }
}

version(unittest)
{
    void testHandler(Request request, Output output)
    {
        output ~= "OK";
    }
}

unittest
{
    assert(postStaticRoutes is null);
    postRoute!"/submit"(&testHandler);
    assert(("/submit" in postStaticRoutes) !is null);
    postRoute!"/submit/:topic"(&testHandler);
    assert(("/submit/:topic" in postRoutes) !is null);
    postRoute!"/submit/*topics"(&testHandler);
    assert(("/submit/*topics" in postRoutes) !is null);

    getRoute!"/submit"(&testHandler);
    assert(("/submit" in getStaticRoutes) !is null);
    getRoute!"/submit/:topic"(&testHandler);
    assert(("/submit/:topic" in getRoutes) !is null);
    getRoute!"/submit/*topics"(&testHandler);
    assert(("/submit/*topics" in getRoutes) !is null);

    putRoute!"/submit"(&testHandler);
    assert(("/submit" in putStaticRoutes) !is null);
    putRoute!"/submit/:topic"(&testHandler);
    assert(("/submit/:topic" in putRoutes) !is null);
    putRoute!"/submit/*topics"(&testHandler);
    assert(("/submit/*topics" in putRoutes) !is null);

    deleteRoute!"/submit"(&testHandler);
    assert(("/submit" in deleteStaticRoutes) !is null);
    deleteRoute!"/submit/:topic"(&testHandler);
    assert(("/submit/:topic" in deleteRoutes) !is null);
    deleteRoute!"/submit/*topics"(&testHandler);
    assert(("/submit/*topics" in deleteRoutes) !is null);
}
