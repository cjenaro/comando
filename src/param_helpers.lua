-- Parameter Helper Methods
-- Provides parameter parsing, validation, and strong parameters

local ParamHelpers = {}

-- Get all parameters
function ParamHelpers:all_params()
    return self.params
end

-- Get specific parameter
function ParamHelpers:param(key, default)
    local value = self.params[key]
    if value == nil then
        return default
    end
    return value
end

-- Check if parameter exists
function ParamHelpers:has_param(key)
    return self.params[key] ~= nil
end

-- Get parameter as string
function ParamHelpers:param_string(key, default)
    local value = self.params[key]
    if value == nil then
        return default
    end
    return tostring(value)
end

-- Get parameter as number
function ParamHelpers:param_number(key, default)
    local value = self.params[key]
    if value == nil then
        return default
    end
    
    local num = tonumber(value)
    if num == nil then
        return default
    end
    
    return num
end

-- Get parameter as integer
function ParamHelpers:param_integer(key, default)
    local num = self:param_number(key, default)
    if num == nil then
        return default
    end
    return math.floor(num)
end

-- Get parameter as boolean
function ParamHelpers:param_boolean(key, default)
    local value = self.params[key]
    if value == nil then
        return default
    end
    
    if type(value) == "boolean" then
        return value
    end
    
    if type(value) == "string" then
        local lower = string.lower(value)
        if lower == "true" or lower == "1" or lower == "yes" or lower == "on" then
            return true
        elseif lower == "false" or lower == "0" or lower == "no" or lower == "off" then
            return false
        end
    end
    
    if type(value) == "number" then
        return value ~= 0
    end
    
    return default
end

-- Get nested parameter
function ParamHelpers:param_nested(...)
    local keys = {...}
    local current = self.params
    
    for _, key in ipairs(keys) do
        if type(current) ~= "table" or current[key] == nil then
            return nil
        end
        current = current[key]
    end
    
    return current
end

-- Strong parameters - only allow specified keys
function ParamHelpers:permit(...)
    local allowed_keys = {...}
    local permitted = {}
    
    for _, key in ipairs(allowed_keys) do
        if self.params[key] ~= nil then
            permitted[key] = self.params[key]
        end
    end
    
    return permitted
end

-- Require specific parameters
function ParamHelpers:require_params(...)
    local required_keys = {...}
    local missing = {}
    
    for _, key in ipairs(required_keys) do
        if self.params[key] == nil then
            table.insert(missing, key)
        end
    end
    
    if #missing > 0 then
        return self:bad_request("Missing required parameters", missing)
    end
    
    return nil
end

-- Validate parameter with custom function
function ParamHelpers:validate_param(key, validator, error_message)
    local value = self.params[key]
    if value ~= nil and not validator(value) then
        return self:bad_request(error_message or ("Invalid parameter: " .. key))
    end
    return nil
end

-- Validate email format
function ParamHelpers:validate_email(key, required)
    local value = self.params[key]
    
    if value == nil then
        if required then
            return self:bad_request("Email is required")
        end
        return nil
    end
    
    -- Simple email validation
    if not string.match(value, "^[%w%.%-_]+@[%w%.%-_]+%.%w+$") then
        return self:bad_request("Invalid email format")
    end
    
    return nil
end

-- Validate string length
function ParamHelpers:validate_length(key, min_length, max_length)
    local value = self.params[key]
    
    if value == nil then
        return nil
    end
    
    local str_value = tostring(value)
    local length = string.len(str_value)
    
    if min_length and length < min_length then
        return self:bad_request(string.format("Parameter '%s' must be at least %d characters", key, min_length))
    end
    
    if max_length and length > max_length then
        return self:bad_request(string.format("Parameter '%s' must be at most %d characters", key, max_length))
    end
    
    return nil
end

-- Validate numeric range
function ParamHelpers:validate_range(key, min_value, max_value)
    local value = self:param_number(key)
    
    if value == nil then
        return nil
    end
    
    if min_value and value < min_value then
        return self:bad_request(string.format("Parameter '%s' must be at least %d", key, min_value))
    end
    
    if max_value and value > max_value then
        return self:bad_request(string.format("Parameter '%s' must be at most %d", key, max_value))
    end
    
    return nil
end

-- Validate parameter is in allowed list
function ParamHelpers:validate_inclusion(key, allowed_values)
    local value = self.params[key]
    
    if value == nil then
        return nil
    end
    
    for _, allowed in ipairs(allowed_values) do
        if value == allowed then
            return nil
        end
    end
    
    return self:bad_request(string.format("Parameter '%s' must be one of: %s", key, table.concat(allowed_values, ", ")))
end

-- Sanitize string parameter
function ParamHelpers:sanitize_string(key)
    local value = self.params[key]
    if value == nil then
        return nil
    end
    
    local sanitized = tostring(value)
    -- Remove leading/trailing whitespace
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    -- Remove potentially dangerous characters (basic XSS prevention)
    sanitized = string.gsub(sanitized, "[<>\"'&]", "")
    
    return sanitized
end

-- Get pagination parameters
function ParamHelpers:pagination_params(default_page, default_per_page)
    local page = self:param_integer("page", default_page or 1)
    local per_page = self:param_integer("per_page", default_per_page or 20)
    
    -- Ensure reasonable limits
    page = math.max(1, page)
    per_page = math.min(100, math.max(1, per_page))
    
    local offset = (page - 1) * per_page
    
    return {
        page = page,
        per_page = per_page,
        offset = offset,
        limit = per_page
    }
end

return ParamHelpers 