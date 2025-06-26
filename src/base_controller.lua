-- Base Controller for Foguete Framework
-- Provides common controller functionality and helper methods

local json = require("dkjson")
local ResponseHelpers = require("comando.response_helpers")
local AuthHelpers = require("comando.auth_helpers")
local ParamHelpers = require("comando.param_helpers")

local BaseController = {}

-- Set up the metatable for proper inheritance
BaseController.__index = BaseController

-- Include helper methods directly on the BaseController table
for method_name, method_func in pairs(ResponseHelpers) do
	BaseController[method_name] = method_func
end

for method_name, method_func in pairs(AuthHelpers) do
	BaseController[method_name] = method_func
end

for method_name, method_func in pairs(ParamHelpers) do
	BaseController[method_name] = method_func
end

-- Initialize a new controller instance
function BaseController:new(request, response)
	local controller = {
		request = request or {},
		response = response or {},
		params = (request and request.params) or {},
		session = (request and request.session) or {},
		flash_messages = (request and request.flash) or {},
		_current_user = nil,
		rendered = false,
		_format = "html",
		-- Instance-level callback storage
		_before_actions = {},
		_after_actions = {},
		_around_actions = {},
		_exception_handlers = {},
	}
	setmetatable(controller, self)
	return controller
end

-- Rails-like action callbacks
function BaseController:before_action(callback, options)
	options = options or {}
	table.insert(self._before_actions, {
		callback = callback,
		only = options.only,
		except = options.except,
	})
	return self
end

function BaseController:after_action(callback, options)
	options = options or {}
	table.insert(self._after_actions, {
		callback = callback,
		only = options.only,
		except = options.except,
	})
	return self
end

function BaseController:around_action(callback, options)
	options = options or {}
	table.insert(self._around_actions, {
		callback = callback,
		only = options.only,
		except = options.except,
	})
	return self
end

-- Skip callbacks
function BaseController:skip_before_action(callback, options)
	-- Implementation to skip specific callbacks
	return self
end

-- Execute action with callbacks
function BaseController:execute_action(action_name)
	-- Run before callbacks
	local result = self:run_callbacks(self._before_actions, action_name)
	if result then
		return result
	end

	-- Run around callbacks (simplified)
	local action_result
	local around_callbacks = self:filter_callbacks(self._around_actions, action_name)

	if #around_callbacks > 0 then
		-- Simplified around callback execution
		for _, callback_info in ipairs(around_callbacks) do
			local callback_result = callback_info.callback(self, function()
				return self[action_name](self)
			end)
			if callback_result then
				action_result = callback_result
				break
			end
		end
	else
		action_result = self[action_name](self)
	end

	-- Run after callbacks
	self:run_callbacks(self._after_actions, action_name)

	return action_result
end

-- Run callbacks with filtering
function BaseController:run_callbacks(callbacks, action_name)
	local filtered = self:filter_callbacks(callbacks, action_name)
	for _, callback_info in ipairs(filtered) do
		local result = callback_info.callback(self)
		if result then
			return result
		end -- Halt if callback returns response
	end
	return nil
end

-- Filter callbacks based on only/except options
function BaseController:filter_callbacks(callbacks, action_name)
	local filtered = {}
	for _, callback_info in ipairs(callbacks) do
		local should_run = true

		if callback_info.only then
			should_run = false
			for _, only_action in ipairs(callback_info.only) do
				if only_action == action_name then
					should_run = true
					break
				end
			end
		end

		if callback_info.except then
			for _, except_action in ipairs(callback_info.except) do
				if except_action == action_name then
					should_run = false
					break
				end
			end
		end

		if should_run then
			table.insert(filtered, callback_info)
		end
	end
	return filtered
end

-- Rails-like respond_to for format handling
function BaseController:respond_to(formats)
	local request_format = self.request.format or self:extract_format()
	self._format = request_format

	if request_format and formats[request_format] then
		return formats[request_format]()
	elseif not request_format and formats.html then
		-- Default to HTML only when no format is specified
		return formats.html()
	elseif request_format then
		-- Explicit format requested but not supported
		return self:json({ error = "Not Acceptable" }, 406)
	else
		-- No format specified and no HTML handler
		return self:json({ error = "Not Acceptable" }, 406)
	end
end

-- Extract format from request
function BaseController:extract_format()
	-- Check Accept header or file extension in path
	if self.request.headers and self.request.headers["Accept"] then
		local accept = self.request.headers["Accept"]
		if string.find(accept, "application/json") then
			return "json"
		elseif string.find(accept, "application/xml") then
			return "xml"
		elseif string.find(accept, "text/html") then
			return "html"
		end
	end

	-- Check path extension
	if self.request.path then
		local ext = string.match(self.request.path, "%.(%w+)$")
		if ext then
			return ext
		end
	end

	return nil -- Return nil instead of defaulting to html
end

-- Strong Parameters helper class
local StrongParameters = {}
StrongParameters.__index = StrongParameters

function StrongParameters:new(data)
	return setmetatable({ data = data }, self)
end

function StrongParameters:permit(...)
	local allowed = { ... }
	local result = {}

	if type(self.data) == "table" then
		for _, key in ipairs(allowed) do
			if type(key) == "table" then
				-- Handle nested permissions
				for nested_key, nested_allowed in pairs(key) do
					if self.data[nested_key] then
						local nested_params = StrongParameters:new(self.data[nested_key])
						result[nested_key] = nested_params:permit(table.unpack(nested_allowed))
					end
				end
			else
				if self.data[key] ~= nil then
					result[key] = self.data[key]
				end
			end
		end
	end

	return result
end

-- Rails-like strong parameters
function BaseController:params_require(key)
	if not self.params[key] then
		error("param is missing or the value is empty: " .. key)
	end
	-- Return the actual data with permit method attached
	local data = self.params[key]
	local strong_params = StrongParameters:new(data)
	-- Copy data properties to the strong_params object for direct access
	for k, v in pairs(data) do
		strong_params[k] = v
	end
	return strong_params
end

-- Request data access helpers
-- These methods provide easy access to parsed request data
-- The motor HTTP parser automatically decodes JSON and form data based on Content-Type

function BaseController:request_data()
	-- Return parsed request data (JSON, form data, etc.) or empty table
	-- This is the preferred way to access request body data as it's automatically parsed
	-- For JSON requests: returns the decoded JSON object
	-- For form requests: returns the parsed form data
	-- For other types: returns empty table (use request_body() for raw data)
	return self.request.data or {}
end

function BaseController:request_body()
	-- Return raw request body as string
	-- Use this only when you need the unparsed body data
	return self.request.body or ""
end

function BaseController:is_json_request()
	-- Check if request content-type is JSON
	local content_type = self.request.headers and self.request.headers["content-type"] or ""
	return string.find(string.lower(content_type), "application/json") ~= nil
end

function BaseController:is_form_request()
	-- Check if request content-type is form data
	local content_type = self.request.headers and self.request.headers["content-type"] or ""
	return string.find(string.lower(content_type), "application/x%-www%-form%-urlencoded") ~= nil
end

-- RESTful action helpers
function BaseController:index()
	-- Override in subclasses
	return self:render("index", {})
end

function BaseController:show()
	local id = self:param("id")
	if not id then
		return self:bad_request("ID parameter required")
	end
	return self:render("show", { id = id })
end

function BaseController:new_action()
	return self:render("new", {})
end

function BaseController:create()
	-- Override in subclasses
	return self:redirect("/")
end

function BaseController:edit()
	local id = self:param("id")
	if not id then
		return self:bad_request("ID parameter required")
	end
	return self:render("edit", { id = id })
end

function BaseController:update()
	-- Override in subclasses
	return self:redirect("/")
end

function BaseController:destroy()
	-- Override in subsubclasses
	return self:redirect("/")
end

-- Error handling (Rails-like rescue_from)
function BaseController:rescue_from(exception_class, handler)
	-- Store exception handlers
	self._exception_handlers = self._exception_handlers or {}
	self._exception_handlers[exception_class] = handler
end

function BaseController:handle_exception(exception_class, message)
	if self._exception_handlers and self._exception_handlers[exception_class] then
		return self._exception_handlers[exception_class](self, message)
	end

	-- Default error handling
	return self:internal_server_error("An error occurred: " .. (message or "Unknown error"))
end

-- Render a view with data
function BaseController:render(view, data, status)
	if self.rendered then
		error("Response already rendered")
	end

	data = data or {}
	data.flash = self.flash_messages
	data.session = self.session
	data.params = self.params

	self.rendered = true

	return {
		status = status or 200,
		headers = { ["Content-Type"] = "text/html; charset=utf-8" },
		body = self:render_template(view, data),
	}
end

-- Render JSON response
function BaseController:json(data, status)
	if self.rendered then
		error("Response already rendered")
	end

	self.rendered = true

	return {
		status = status or 200,
		headers = {
			["Content-Type"] = "application/json; charset=utf-8",
			["X-Content-Type-Options"] = "nosniff",
		},
		body = json.encode(data),
	}
end

-- Redirect to a path
function BaseController:redirect(path, status)
	if self.rendered then
		error("Response already rendered")
	end

	self.rendered = true

	return {
		status = status or 302,
		headers = {
			["Location"] = path,
			["Content-Type"] = "text/html; charset=utf-8",
		},
		body = string.format('<html><body>Redirecting to <a href="%s">%s</a></body></html>', path, path),
	}
end

-- Additional response methods
function BaseController:bad_request(message)
	return self:json({ status = "error", message = message or "Bad Request" }, 400)
end

function BaseController:unauthorized(message)
	return self:json({ status = "error", message = message or "Unauthorized" }, 401)
end

function BaseController:forbidden(message)
	return self:json({ status = "error", message = message or "Forbidden" }, 403)
end

function BaseController:not_found(message)
	return self:json({ status = "error", message = message or "Not Found" }, 404)
end

function BaseController:internal_server_error(message)
	return self:json({ status = "error", message = message or "Internal Server Error" }, 500)
end

-- Set flash message
function BaseController:flash(message, type)
	type = type or "notice"
	self.flash_messages[type] = message
	-- In a real implementation, this would be persisted to the session
	if self.session then
		self.session.flash = self.session.flash or {}
		self.session.flash[type] = message
	end
end

-- Template rendering (stub - would integrate with actual template engine)
function BaseController:render_template(view, data)
	-- This is a simple stub - in a real implementation, this would
	-- integrate with a proper template engine like Lustache or similar
	local template = string.format(
		[[
<!DOCTYPE html>
<html>
<head>
    <title>%s</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>%s</h1>
    <div>View: %s</div>
    <div>Data: %s</div>
    %s
</body>
</html>
    ]],
		data.title or "Foguete App",
		data.title or "Page",
		view,
		json.encode(data),
		self:render_flash_messages()
	)
	return template
end

-- Render flash messages
function BaseController:render_flash_messages()
	local html = ""
	for msg_type, message in pairs(self.flash_messages) do
		html = html .. string.format('<div class="flash-%s">%s</div>', msg_type, message)
	end
	return html
end

return BaseController
