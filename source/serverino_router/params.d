module serverino_router.params;

import std.typecons : Nullable, nullable;
import std.conv : to;
import std.traits;
import std.meta : AliasSeq;
//import std.logger;
import std.algorithm.searching : canFind;
//import std.datetime : Clock, UTC, SysTime;
import std.string : strip, split, join, empty;
import std.json;

import serverino;
import json_serialization;

// These will be filled once the routes are defined
string[string] pathParams;

/// UDA.
struct paramName
{
    string name;
}

public enum ignoreParam;  /// UDA. struct members with @ignoreParam will be ignored while parsing params 

bool validParamType(string param, string type)
{
    // TODO: Add more types
    alias types = AliasSeq!(ulong, int, string);

    try
    {
        static foreach(t; types)
        {
            mixin(`
                if (type == "` ~ t.stringof ~ `")
                {
                    param.to!` ~ t.stringof ~ `;
                    return true;
                }
            `);
        }

        return false;
    }
    catch (Exception)
        return false;
}

Nullable!(string[string]) matchedPathParams(string pattern, string path)
{
    string[string] params;

    // Split the pattern and path into parts
    auto patternParts = pattern.strip("/").split("/");
    auto pathParts = path.strip("/").split("/");
    auto starPattern = pattern.canFind("*");

    // Pattern group should match the given path parts
    if (patternParts.length != pathParts.length && !starPattern)
        return Nullable!(string[string]).init;

    // For each pattern parts, if it starts with `:`
    // then collect it as path param else path part should
    // match the respective part of the pattern.
    foreach(idx, p; patternParts)
    {
        if (p[0] == ':')
        {
            // Check if the type is provided, try to convert to
            // that type. Return false if it is not a valid type.
            // Advantage: We can have two routes for each type
            // `/api/v1/shares/:id:ulong` and `/api/v1/shares/:folder_name`
            auto patternAndType = p[1..$].split(":");
            if (patternAndType.length > 1 && !validParamType(patternAndType[0], patternAndType[1]))
                return Nullable!(string[string]).init;

            if (pathParts.length <= idx)
                return Nullable!(string[string]).init;

            params[patternAndType[0]] = pathParts[idx];
        }
        else if (p[0] == '*')
        {
            if (p.length > 1)
            {
                // If name is provided with *, then collect
                // the rest of the path parts as current param
                auto param = pathParts[idx..$].join("/");
                if (param.empty)
                    return Nullable!(string[string]).init;

                params[p[1..$]] = param;
            }
            // No need to compare the rest of the path parts
            break;
        }
        else if(pathParts.length <= idx || p != pathParts[idx])
            return Nullable!(string[string]).init;
    }

    return params.nullable;
}

string getParamName(T, string member)()
{
    static if (getUDAs!(__traits(getMember, T, member), paramName).length > 0)
        return getUDAs!(__traits(getMember, T, member), paramName)[0].name;

    return member;
}

bool isParamIgnored(T, string member)()
{
    return hasUDA!(__traits(getMember, T, member), ignoreParam);
}

class ParamsParseException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

string nullableType(T)()
{
    import std.string;
    string type = T.stringof;
    auto parts = type.split("!");
    if (parts.length > 1)
        return parts[1];

    return parts[0];
}

Nullable!T getParam(T)(Request req, string key, JSONValue bodyParams = JSONValue(), string[string] pathParams = string[string].init)
{
    Nullable!T value;
    auto pathParamValue = key in pathParams;
    auto bodyParam = key in bodyParams;

    if (pathParamValue !is null)
        value = (*pathParamValue).to!(T);
    else if (req.get.has(key))
        value = req.get.read(key).to!(T);
    else if (bodyParam !is null)
        value = (*bodyParam).get!(T);
    else if (req.post.has(key))
        value = req.post.read(key).to!(T);
    else if (req.form.has(key))
    {
        auto fd = req.form.read(key);
        if (!fd.isFile)
            value = fd.data.to!(T).nullable;
    }

    return value;
}

/* Parse all params including URL params. Provides uniform way to
 * provide access to Params similar to Ruby on Rails. JSON params
 * are also supported.
 *
 * ```d
 * struct LoginRequest
 * {
 *     string username;
 *     string password;
 *     string authenticityToken;
 * }
 *
 * void loginHandler(Request request, Output output)
 * {
 *     auto params = parseParams!LoginRequest(request);
 *     // Use params.username, params.password and
 *     // params.authenticityToken as needed.
 * }
 * ```
 *
 * This function checks the params in the following order. If the Content
 * type is set to application/json then parses the body JSON.
 *
 * 1) Path params - Path params are only available if the routing helper
 *    from this library.
 * 2) Query Params - Get params from Query.
 * 3) JSON Params - Try to get params from JSON body.
 * 4) Post params
 * 5) Multipart formdata
 *
 * No support for files params. Use `request.form` to read the files data.
 */
T parseParams(T)(Request req)
{
    static if (is(T == struct))
        T params;
    else
        T params = new T;

    JSONValue bodyJson;
    if (req.body.contentType == "application/json")
    {
        try
            bodyJson = parseJSON(req.body.data.to!string);
        catch (Exception)
            throw new ParamsParseException("Invalid JSON");
    }

    alias fieldTypes = FieldTypeTuple!(T);
    alias fieldNames = FieldNameTuple!(T);

    static foreach(idx, fieldName; fieldNames)
    {
        static if (!isParamIgnored!(T, fieldName))
        {{
            // Param name same as memberName unless @paramName
            // attribute added to the member.
            enum name = getParamName!(T, fieldName);

            static if(__traits(hasMember, __traits(getMember, params, fieldName), "isNull"))
                enum type = nullableType!(fieldTypes[idx]);
            else
                enum type = fieldTypes[idx].stringof;

            // Example conversion:
            // try
            // {
            //     auto param = getParam!(int)(req, "page", bodyJson, pathParams);
            //     if (!param.isNull)
            //         params.page = param.get;
            // }
            // catch (Exception)
            // {
            //     throw new ParamsParseException("Failed to parse \"page\". Invalid content");
            // }
            mixin(`
                try
                {
                    auto param = getParam!(` ~ type ~ `)(req, "` ~ name ~ `", bodyJson, pathParams);
                    if (!param.isNull)
                         params.` ~ fieldName ~ ` = param.get;
                }
                catch (Exception)
                {
                    throw new ParamsParseException("Failed to parse \"` ~ name ~ `\". Invalid content");
                }
            `);
        }}
    }

    return params;
}
