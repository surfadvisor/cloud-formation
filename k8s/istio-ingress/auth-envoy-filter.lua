
-- add a version to ensure the config's been swapped out while iterating on code changes
function version()
    return "v0.0.4"
end

function log(handle, value)
    handle:logInfo(rqID(handle) .. "|" .. version() .. ": " .. value)
end

function rqID(request_handle)
    return get_header(request_handle, "x-request-id")
end

-- dump a lua object into a string for logging
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function get_header(handle, header)
    return handle:headers():get(header)
end

function envoy_on_request(request_handle)

    path = get_header(request_handle, ":path")
    local host = get_header(request_handle, ":authority")

    --TODO: whitelist jenkins on the upper level
    if host == 'jenkins.thesurfadvisor.com' then
        log(request_handle, "Jenkins call: " .. path .. ", host: " .. host)
        return
    end
    if host == 'kibana.thesurfadvisor.com' then
        log(request_handle, "Kibana call: " .. path .. ", host: " .. host)
        return
    end

    -- Build a request for our authentication service before passing request upstream
    local auth_host = "firebase-auth-connector.default.svc.cluster.local"
    local auth_path = "/verify-token"

    local cluster = "outbound|8080||" .. auth_host
    local request_headers = {
        [":method"] = "GET",
        [":path"] = auth_path,
        [":authority"] = auth_host,
        ["x-request-id"] = rqID(request_handle),
        ["target-method"] = get_header(request_handle, ":method"),
        ["target-host"] = host,
        ["target-path"] = path
    }

    local request_body = ""
    local timeout = 5000 --ms

    log(request_handle, "Sending auth request, headers: " .. dump(request_headers) .. ", cluster: " .. cluster .. ", request_body: " .. request_body .. ", path: " .. auth_host)

    request_headers["Authorization"] = get_header(request_handle, "Authorization")

    response_headers, response_body = request_handle:httpCall(
            tostring(cluster),
            request_headers,
            request_body,
            timeout
    )

    log(request_handle, "response_headers: " .. dump(response_headers))

    if tonumber(response_headers[":status"]) ~= 204 then
        log(request_handle, "[" .. cluster .. "] Failed")
        request_handle:respond(
                { [":status"] = response_headers[":status"] },
                response_body
        )
    end
    -- The authentication service responds with a series of headers to Set and Unset
    -- Pass all 'Set-*' headers to upstream
    -- Remove all 'Unset-*' headers from request
    for header, value in pairs(response_headers) do
        local set_header = header:lower():match("^set%-(.+)")
        if set_header then
            request_handle:headers():replace(set_header, value)
        else
            local unset_header = header:lower():match("^unset%-(.+)")
            if unset_header then
                request_handle:headers():remove(unset_header)
            end
        end
    end

end

-- Called on the response path.
function envoy_on_response(response_handle)
    local headers = response_handle:headers()
    headers:add("X-Envoy-Ingress", os.getenv("HOSTNAME"))
end
