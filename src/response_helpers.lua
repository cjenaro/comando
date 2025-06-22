-- Response Helper Methods
-- Common HTTP response utilities for controllers

local json = require("dkjson")

local ResponseHelpers = {}

-- 200 OK response
function ResponseHelpers:ok(body, content_type)
    return {
        status = 200,
        headers = { ["Content-Type"] = content_type or "text/html; charset=utf-8" },
        body = body or "OK"
    }
end

-- 201 Created response
function ResponseHelpers:created(body, location)
    local headers = { ["Content-Type"] = "application/json; charset=utf-8" }
    if location then
        headers["Location"] = location
    end
    
    return {
        status = 201,
        headers = headers,
        body = body and json.encode(body) or json.encode({ status = "created" })
    }
end

-- 204 No Content response
function ResponseHelpers:no_content()
    return {
        status = 204,
        headers = {},
        body = ""
    }
end

-- 400 Bad Request response
function ResponseHelpers:bad_request(message, errors)
    local body = {
        status = "error",
        message = message or "Bad Request",
        errors = errors
    }
    
    return {
        status = 400,
        headers = { ["Content-Type"] = "application/json; charset=utf-8" },
        body = json.encode(body)
    }
end

-- 401 Unauthorized response
function ResponseHelpers:unauthorized(message)
    local body = {
        status = "error",
        message = message or "Unauthorized"
    }
    
    return {
        status = 401,
        headers = { 
            ["Content-Type"] = "application/json; charset=utf-8",
            ["WWW-Authenticate"] = "Bearer"
        },
        body = json.encode(body)
    }
end

-- 403 Forbidden response
function ResponseHelpers:forbidden(message)
    local body = {
        status = "error",
        message = message or "Forbidden"
    }
    
    return {
        status = 403,
        headers = { ["Content-Type"] = "application/json; charset=utf-8" },
        body = json.encode(body)
    }
end

-- 404 Not Found response
function ResponseHelpers:not_found(message)
    local body = {
        status = "error",
        message = message or "Not Found"
    }
    
    return {
        status = 404,
        headers = { ["Content-Type"] = "application/json; charset=utf-8" },
        body = json.encode(body)
    }
end

-- 422 Unprocessable Entity response
function ResponseHelpers:unprocessable_entity(message, errors)
    local body = {
        status = "error",
        message = message or "Unprocessable Entity",
        errors = errors
    }
    
    return {
        status = 422,
        headers = { ["Content-Type"] = "application/json; charset=utf-8" },
        body = json.encode(body)
    }
end

-- 500 Internal Server Error response
function ResponseHelpers:internal_error(message, details)
    local body = {
        status = "error",
        message = message or "Internal Server Error"
    }
    
    -- Only include details in development mode
    if details and os.getenv("FOGUETE_ENV") == "development" then
        body.details = details
    end
    
    return {
        status = 500,
        headers = { ["Content-Type"] = "application/json; charset=utf-8" },
        body = json.encode(body)
    }
end

-- 503 Service Unavailable response
function ResponseHelpers:service_unavailable(message)
    local body = {
        status = "error",
        message = message or "Service Unavailable"
    }
    
    return {
        status = 503,
        headers = { 
            ["Content-Type"] = "application/json; charset=utf-8",
            ["Retry-After"] = "3600" -- 1 hour
        },
        body = json.encode(body)
    }
end

return ResponseHelpers 