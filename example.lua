#!/usr/bin/env lua

-- Comando Complete Example
-- This demonstrates all features: standalone usage, Motor+Rota integration, and Rails conventions

-- Setup paths for integration components
package.path = "./src/?.lua;" .. package.path
package.path = "../motor/src/?.lua;" .. package.path  
package.path = "../rota/src/?.lua;" .. package.path

local BaseController = require("comando")

-- Try to load integration components (optional)
local motor_available, motor = pcall(require, "motor")
local rota_available, rota = pcall(require, "init")

print("🚀 Comando Complete Example")
print("=" .. string.rep("=", 60))
print("Components available:")
print("  ✓ Comando - Rails-like controllers")
if motor_available then print("  ✓ Motor - HTTP server") end
if rota_available then print("  ✓ Rota - Routing engine") end
print()

-- =============================================================================
-- PART 1: MOCK DATA AND MODELS
-- =============================================================================

-- Example User model (would normally be in separate file)
local User = {}
User.__index = User

function User:new(data)
    local user = data or {}
    setmetatable(user, self)
    return user
end

function User:all()
    -- Mock data - would normally fetch from database
    return {
        { id = 1, name = "Alice", email = "alice@example.com", role = "admin" },
        { id = 2, name = "Bob", email = "bob@example.com", role = "user" },
        { id = 3, name = "Charlie", email = "charlie@example.com", role = "editor" }
    }
end

function User:find(id)
    local users = self:all()
    for _, user in ipairs(users) do
        if user.id == tonumber(id) then
            return user
        end
    end
    return nil
end

function User:create(params)
    -- Validate and create user
    local errors = {}
    
    if not params.name or string.len(params.name) == 0 then
        table.insert(errors, "Name is required")
    end
    
    if not params.email or not string.match(params.email, "^[%w%.%-_]+@[%w%.%-_]+%.%w+$") then
        table.insert(errors, "Valid email is required")
    end
    
    if #errors > 0 then
        return nil, errors
    end
    
    local user = User:new({
        id = math.random(1000, 9999),
        name = params.name,
        email = params.email,
        role = params.role or "user"
    })
    
    return user, nil
end

function User:update(params)
    -- Update user attributes
    self.name = params.name or self.name
    self.email = params.email or self.email
    self.role = params.role or self.role
    return true
end

function User:destroy()
    -- Mock delete - would normally delete from database
    return true
end

-- =============================================================================
-- PART 2: RAILS-LIKE CONTROLLERS
-- =============================================================================

-- Rails-like Users Controller
UsersController = {}
setmetatable(UsersController, { __index = BaseController })

function UsersController:new(request, response)
    local instance = BaseController:new(request, response)
    -- Fix inheritance: set the metatable to point to UsersController
    setmetatable(instance, { __index = UsersController })
    
    -- Rails-like before_action callbacks
    instance:before_action(function(ctrl) return ctrl:find_user() end, 
                          { only = {"show", "edit", "update", "destroy"} })
    instance:before_action(function(ctrl) return ctrl:authenticate() end, 
                          { except = {"index", "show"} })
    
    -- Rails-like after_action callbacks
    instance:after_action(function(ctrl) ctrl:log_action() end)
    
    return instance
end

-- RESTful actions (Rails conventions)

-- GET /users
function UsersController:index()
    local users = User:all()
    
    return self:respond_to({
        html = function()
            return {
                status = 200,
                headers = { ["Content-Type"] = "text/html; charset=utf-8" },
                body = self:render_users_index(users)
            }
        end,
        json = function()
            return self:json({ 
                status = "success",
                data = users,
                count = #users 
            })
        end
    })
end

-- GET /users/:id
function UsersController:show()
    return self:respond_to({
        html = function()
            return {
                status = 200,
                headers = { ["Content-Type"] = "text/html; charset=utf-8" },
                body = self:render_user_show(self.user)
            }
        end,
        json = function()
            return self:json({ 
                status = "success",
                data = self.user 
            })
        end
    })
end

-- GET /users/new
function UsersController:new()
    local user = User:new()
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/html; charset=utf-8" },
        body = self:render_user_form(user, "New User")
    }
end

-- POST /users
function UsersController:create()
    -- Rails-like strong parameters
    local user_params = self:params_require("user"):permit("name", "email", "role")
    
    local user, errors = User:create(user_params)
    
    if user then
        self:flash("User created successfully!", "success")
        return self:respond_to({
            html = function()
                return self:redirect("/users/" .. user.id)
            end,
            json = function()
                return self:json({ 
                    status = "success",
                    message = "User created successfully",
                    data = user 
                }, 201)
            end
        })
    else
        return self:respond_to({
            html = function()
                return {
                    status = 422,
                    headers = { ["Content-Type"] = "text/html; charset=utf-8" },
                    body = self:render_user_form(user_params, "New User", errors)
                }
            end,
            json = function()
                return self:json({ 
                    status = "error",
                    message = "Failed to create user",
                    errors = errors 
                }, 422)
            end
        })
    end
end

-- GET /users/:id/edit
function UsersController:edit()
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/html; charset=utf-8" },
        body = self:render_user_form(self.user, "Edit User")
    }
end

-- PATCH/PUT /users/:id
function UsersController:update()
    local user_params = self:params_require("user"):permit("name", "email", "role")
    
    local success = self.user:update(user_params)
    
    if success then
        self:flash("User updated successfully!", "success")
        return self:respond_to({
            html = function()
                return self:redirect("/users/" .. self.user.id)
            end,
            json = function()
                return self:json({ 
                    status = "success",
                    message = "User updated successfully",
                    data = self.user 
                })
            end
        })
    else
        return self:respond_to({
            html = function()
                return {
                    status = 422,
                    headers = { ["Content-Type"] = "text/html; charset=utf-8" },
                    body = self:render_user_form(self.user, "Edit User", {"Failed to update user"})
                }
            end,
            json = function()
                return self:json({ 
                    status = "error",
                    message = "Failed to update user" 
                }, 422)
            end
        })
    end
end

-- DELETE /users/:id
function UsersController:destroy()
    local success = self.user:destroy()
    
    if success then
        self:flash("User deleted successfully!", "success")
    else
        self:flash("Failed to delete user", "error")
    end
    
    return self:respond_to({
        html = function()
            return self:redirect("/users")
        end,
        json = function()
            return self:json({ 
                status = "success",
                message = "User deleted successfully" 
            })
        end
    })
end

-- HTML Rendering helpers
function UsersController:render_users_index(users)
    local user_rows = {}
    for _, user in ipairs(users) do
        table.insert(user_rows, string.format([[
            <tr>
                <td>%d</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>
                    <a href="/users/%d">View</a> |
                    <a href="/users/%d/edit">Edit</a> |
                    <a href="/users/%d" onclick="return confirm('Are you sure?')" data-method="delete">Delete</a>
                </td>
            </tr>
        ]], user.id, user.name, user.email, user.role, user.id, user.id, user.id))
    end
    
    return string.format([[
<!DOCTYPE html>
<html>
<head>
    <title>Users - Foguete App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        table { border-collapse: collapse; width: 100%%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .btn { padding: 8px 16px; background: #007cba; color: white; text-decoration: none; border-radius: 4px; }
        .flash { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .flash.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
    </style>
</head>
<body>
    <h1>🚀 Foguete Users</h1>
    %s
    <p><a href="/users/new" class="btn">New User</a></p>
    
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            %s
        </tbody>
    </table>
    
    <hr>
    <p><strong>API Endpoints:</strong></p>
    <ul>
        <li><a href="/api/users">GET /api/users</a> - JSON list</li>
        <li><a href="/api/users/1">GET /api/users/1</a> - JSON user details</li>
    </ul>
</body>
</html>
    ]], self:render_flash(), table.concat(user_rows, "\n"))
end

function UsersController:render_user_show(user)
    return string.format([[
<!DOCTYPE html>
<html>
<head>
    <title>%s - Foguete App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .btn { padding: 8px 16px; background: #007cba; color: white; text-decoration: none; border-radius: 4px; margin-right: 10px; }
        .user-details { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>User: %s</h1>
    
    <div class="user-details">
        <p><strong>ID:</strong> %d</p>
        <p><strong>Name:</strong> %s</p>
        <p><strong>Email:</strong> %s</p>
        <p><strong>Role:</strong> %s</p>
    </div>
    
    <p>
        <a href="/users/%d/edit" class="btn">Edit</a>
        <a href="/users" class="btn">Back to List</a>
    </p>
</body>
</html>
    ]], user.name, user.name, user.id, user.name, user.email, user.role, user.id)
end

function UsersController:render_user_form(user, title, errors)
    local error_html = ""
    if errors and #errors > 0 then
        local error_items = {}
        for _, error in ipairs(errors) do
            table.insert(error_items, "<li>" .. error .. "</li>")
        end
        error_html = string.format([[
            <div class="errors">
                <h3>Please fix the following errors:</h3>
                <ul>%s</ul>
            </div>
        ]], table.concat(error_items, "\n"))
    end
    
    return string.format([[
<!DOCTYPE html>
<html>
<head>
    <title>%s - Foguete App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .form-group { margin: 15px 0; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input, select { padding: 8px; width: 300px; border: 1px solid #ddd; border-radius: 4px; }
        .btn { padding: 10px 20px; background: #007cba; color: white; border: none; border-radius: 4px; cursor: pointer; }
        .errors { background: #f8d7da; color: #721c24; padding: 15px; border-radius: 4px; margin: 15px 0; }
    </style>
</head>
<body>
    <h1>%s</h1>
    
    %s
    
    <form method="POST" action="/users">
        <div class="form-group">
            <label for="user_name">Name:</label>
            <input type="text" id="user_name" name="user[name]" value="%s" required>
        </div>
        
        <div class="form-group">
            <label for="user_email">Email:</label>
            <input type="email" id="user_email" name="user[email]" value="%s" required>
        </div>
        
        <div class="form-group">
            <label for="user_role">Role:</label>
            <select id="user_role" name="user[role]">
                <option value="user"%s>User</option>
                <option value="editor"%s>Editor</option>
                <option value="admin"%s>Admin</option>
            </select>
        </div>
        
        <div class="form-group">
            <button type="submit" class="btn">Save User</button>
            <a href="/users">Cancel</a>
        </div>
    </form>
</body>
</html>
    ]], title, title, error_html, 
        user.name or "", user.email or "",
        (user.role == "user") and " selected" or "",
        (user.role == "editor") and " selected" or "",
        (user.role == "admin") and " selected" or "")
end

function UsersController:render_flash()
    if not self.flash_messages or not next(self.flash_messages) then
        return ""
    end
    
    local flash_html = {}
    for type, message in pairs(self.flash_messages) do
        table.insert(flash_html, string.format(
            '<div class="flash %s">%s</div>', type, message))
    end
    
    return table.concat(flash_html, "\n")
end

-- Callback methods (Rails style)
function UsersController:find_user()
    local id = self:param("id")
    if not id then
        return self:bad_request("User ID required")
    end
    
    self.user = User:find(id)
    if not self.user then
        return self:not_found("User not found")
    end
    
    return nil -- Continue processing
end

function UsersController:log_action()
    local action = self.action_name or "unknown"
    local user_id = self:current_user() and self:current_user().id or "guest"
    print(string.format("[LOG] Action '%s' executed by user %s", action, user_id))
end

-- API-only Controller (inherits Rails conventions)
ApiController = {}
setmetatable(ApiController, { __index = BaseController })

function ApiController:new(request, response)
    local instance = BaseController:new(request, response)
    setmetatable(instance, { __index = ApiController })
    
    -- API-specific callbacks
    instance:before_action(function(ctrl) return ctrl:authenticate_api() end)
    instance:after_action(function(ctrl) ctrl:set_cors_headers() end)
    
    return instance
end

function ApiController:users_index()
    local users = User:all()
    return self:json({
        status = "success",
        data = users,
        meta = { count = #users, version = "v1" }
    })
end

function ApiController:users_show()
    local user = User:find(self:param("id"))
    if not user then
        return self:not_found("User not found")
    end
    
    return self:json({
        status = "success",
        data = user
    })
end

function ApiController:authenticate_api()
    local token = self.request.headers and self.request.headers["Authorization"]
    if not token or token ~= "Bearer valid-token" then
        return self:unauthorized("Invalid API token")
    end
    return nil
end

function ApiController:set_cors_headers()
    -- Would set CORS headers in real implementation
    self.response.headers = self.response.headers or {}
    self.response.headers["Access-Control-Allow-Origin"] = "*"
end

-- Protected Controller with Authorization
AdminController = {}
setmetatable(AdminController, { __index = BaseController })

function AdminController:new(request, response)
    local instance = BaseController:new(request, response)
    setmetatable(instance, { __index = AdminController })
    
    -- Admin-specific callbacks
    instance:before_action(function(ctrl) return ctrl:authenticate() end)
    instance:before_action(function(ctrl) return ctrl:require_admin() end)
    
    return instance
end

function AdminController:dashboard()
    local stats = {
        total_users = #User:all(),
        admin_users = 1,
        active_sessions = 5
    }
    
    return {
        status = 200,
        headers = { ["Content-Type"] = "text/html; charset=utf-8" },
        body = string.format([[
<!DOCTYPE html>
<html>
<head><title>Admin Dashboard</title></head>
<body>
    <h1>Admin Dashboard</h1>
    <p>Total Users: %d</p>
    <p>Admin Users: %d</p>
    <p>Active Sessions: %d</p>
</body>
</html>
        ]], stats.total_users, stats.admin_users, stats.active_sessions)
    }
end

-- =============================================================================
-- PART 3: STANDALONE EXAMPLES (WITHOUT SERVER)
-- =============================================================================

-- Example routing helper for standalone testing (defined after controllers)
route_request = function(path, method, params, session, headers)
    local request = {
        path = path,
        method = method or "GET",
        params = params or {},
        session = session or {},
        flash = {},
        headers = headers or {}
    }
    
    local response = {}
    local controller, action
    
    -- Simple routing (in real app, this would be more sophisticated)
    if path == "/users" then
        controller = UsersController:new(request, response)
        action = method == "GET" and "index" or "create"
    elseif path:match("^/users/new$") then
        controller = UsersController:new(request, response)
        action = "new"
    elseif path:match("^/users/(%d+)$") then
        local id = path:match("^/users/(%d+)$")
        request.params.id = id
        controller = UsersController:new(request, response)
        action = method == "GET" and "show" or method == "DELETE" and "destroy" or "update"
    elseif path:match("^/users/(%d+)/edit$") then
        local id = path:match("^/users/(%d+)/edit$")
        request.params.id = id
        controller = UsersController:new(request, response)
        action = "edit"
    elseif path == "/api/users" then
        controller = ApiController:new(request, response)
        action = "users_index"
    elseif path == "/admin/dashboard" then
        controller = AdminController:new(request, response)
        action = "dashboard"
    end
    
    if controller and action then
        -- Store action name for logging
        controller.action_name = action
        
        -- Execute action with Rails-like callback chain
        if controller[action] then
            return controller:execute_action(action)
        else
            -- Try calling action directly as fallback
            return controller[action] and controller[action](controller) or {
                status = 500,
                headers = { ["Content-Type"] = "text/html; charset=utf-8" },
                body = "Action not found: " .. action
            }
        end
    end
    
    return {
        status = 404,
        headers = { ["Content-Type"] = "text/html; charset=utf-8" },
        body = "Not Found"
    }
end

-- =============================================================================
-- PART 4: INTEGRATION WITH MOTOR + ROTA (IF AVAILABLE)
-- =============================================================================

local function setup_integration()
    if not (motor_available and rota_available) then
        return nil
    end
    
    -- Helper function to convert Motor request to Comando request format
    local function convert_request(motor_req)
        return {
            path = motor_req.path,
            method = motor_req.method,
            params = motor_req.params or {},
            session = { user_id = 1 }, -- Mock session
            flash = {},
            headers = motor_req.headers or {}
        }
    end
    
    -- Helper function to route requests to controllers
    local function route_to_controller(motor_req, controller_class, action)
        local request = convert_request(motor_req)
        local response = {}
        
        local controller = controller_class:new(request, response)
        controller.action_name = action
        
        if controller[action] then
            return controller:execute_action(action)
        else
            return {
                status = 500,
                headers = { ["Content-Type"] = "application/json; charset=utf-8" },
                body = '{"error": "Action not found: ' .. action .. '"}'
            }
        end
    end
    
    -- Create router and define routes
    local router = rota.new()
    
    -- Add logging middleware
    router:use(function(req, next)
        print(string.format("[%s] %s %s", os.date("%Y-%m-%d %H:%M:%S"), req.method, req.path))
        local start_time = os.clock()
        
        local response = next()
        
        local duration = (os.clock() - start_time) * 1000
        print(string.format("  -> %d (%d ms)", response.status, math.floor(duration)))
        
        return response
    end)
    
    -- Home page
    router:get("/", function(req)
        return {
            status = 200,
            headers = { ["Content-Type"] = "text/html; charset=utf-8" },
            body = [[
<!DOCTYPE html>
<html>
<head>
    <title>Foguete - Complete Example</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .feature { margin: 20px 0; padding: 15px; background: #f8f9fa; border-radius: 8px; }
        .btn { padding: 10px 20px; background: #007cba; color: white; text-decoration: none; border-radius: 4px; margin: 5px; display: inline-block; }
    </style>
</head>
<body>
    <h1>🚀 Foguete Framework - Complete Example</h1>
    <p>This demonstrates the full integration of all components:</p>
    
    <div class="feature">
        <h3>🎮 Comando - Rails-like Controllers</h3>
        <p>Provides Rails conventions: callbacks, strong parameters, respond_to, authentication, etc.</p>
    </div>
    
    <div class="feature">
        <h3>🚗 Motor - HTTP Server</h3>
        <p>High-performance HTTP server with middleware support</p>
    </div>
    
    <div class="feature">
        <h3>🗺️ Rota - Routing Engine</h3>
        <p>Flexible routing with parameters, wildcards, and RESTful resources</p>
    </div>
    
    <h2>Try the Demo:</h2>
    <p>
        <a href="/users" class="btn">View Users (HTML)</a>
        <a href="/api/users" class="btn">API Users (JSON)</a>
        <a href="/users/new" class="btn">Create User</a>
    </p>
    
    <h3>Available Endpoints:</h3>
    <ul>
        <li><strong>GET /users</strong> - List users (HTML/JSON)</li>
        <li><strong>GET /users/:id</strong> - Show user (HTML/JSON)</li>
        <li><strong>GET /users/new</strong> - New user form</li>
        <li><strong>POST /users</strong> - Create user</li>
        <li><strong>DELETE /users/:id</strong> - Delete user</li>
        <li><strong>GET /api/users</strong> - API: List users</li>
        <li><strong>GET /api/users/:id</strong> - API: Show user</li>
    </ul>
</body>
</html>
            ]]
        }
    end)
    
    -- RESTful routes for users (HTML)
    router:get("/users", function(req)
        return route_to_controller(req, UsersController, "index")
    end)
    
    router:get("/users/new", function(req)
        return route_to_controller(req, UsersController, "new")
    end)
    
    router:get("/users/:id", function(req)
        return route_to_controller(req, UsersController, "show")
    end)
    
    router:post("/users", function(req)
        return route_to_controller(req, UsersController, "create")
    end)
    
    router:delete("/users/:id", function(req)
        return route_to_controller(req, UsersController, "destroy")
    end)
    
    -- API routes (JSON)
    router:get("/api/users", function(req)
        return route_to_controller(req, ApiController, "users_index")
    end)
    
    router:get("/api/users/:id", function(req)
        return route_to_controller(req, ApiController, "users_show")
    end)
    
    -- 404 handler
    router:any("*", function(req)
        return {
            status = 404,
            headers = { ["Content-Type"] = "text/html; charset=utf-8" },
            body = [[
<!DOCTYPE html>
<html>
<head><title>404 - Not Found</title></head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The requested URL was not found on this server.</p>
    <p><a href="/">← Back to Home</a></p>
</body>
</html>
            ]]
        }
    end)
    
    return router
end

-- =============================================================================
-- PART 5: EXAMPLE EXECUTION
-- =============================================================================

print("📋 Running Examples:")
print("-" .. string.rep("-", 40))

-- Standalone Examples (always available)
print("\n🎮 STANDALONE COMANDO EXAMPLES")
print("-" .. string.rep("-", 30))

-- Example 1: List users (HTML)
print("\n1. GET /users (HTML)")
local response1 = route_request("/users", "GET")
print("   Status:", response1.status)
print("   Content-Type:", response1.headers["Content-Type"])
print("   Body preview:", string.sub(response1.body or "", 1, 50) .. "...")

-- Example 2: List users (JSON)
print("\n2. GET /users (JSON)")
local response2 = route_request("/users", "GET", {}, {}, { Accept = "application/json" })
print("   Status:", response2.status)
print("   Content-Type:", response2.headers["Content-Type"])
print("   Body preview:", string.sub(response2.body or "", 1, 80) .. "...")

-- Example 3: Show specific user
print("\n3. GET /users/1")
local response3 = route_request("/users/1", "GET")
print("   Status:", response3.status)
print("   Content-Type:", response3.headers["Content-Type"])

-- Example 4: Create user with strong parameters
print("\n4. POST /users (with strong parameters)")
local response4 = route_request("/users", "POST", {
    user = { name = "David", email = "david@example.com", role = "editor" }
})
print("   Status:", response4.status)
print("   Location:", response4.headers and response4.headers.Location)

-- Example 5: API endpoint with authentication
print("\n5. GET /api/users (with auth)")
local response5 = route_request("/api/users", "GET", {}, {}, { 
    Authorization = "Bearer valid-token" 
})
print("   Status:", response5.status)
print("   Content-Type:", response5.headers["Content-Type"])

-- Example 6: API endpoint without authentication
print("\n6. GET /api/users (no auth)")
local response6 = route_request("/api/users", "GET")
print("   Status:", response6.status)
print("   Body:", response6.body)

-- Integration Examples (if components available)
if motor_available and rota_available then
    print("\n🔗 INTEGRATION EXAMPLES (Motor + Rota)")
    print("-" .. string.rep("-", 35))
    
    local router = setup_integration()
    local handler = router:handler()
    
    -- Demo 1: HTML Users List
    print("\n1. GET /users (HTML via Router)")
    local int_response1 = handler({
        method = "GET",
        path = "/users",
        headers = {}
    })
    print("   Status:", int_response1.status)
    print("   Content-Type:", int_response1.headers["Content-Type"])
    
    -- Demo 2: JSON Users List  
    print("\n2. GET /api/users (JSON via Router)")
    local int_response2 = handler({
        method = "GET", 
        path = "/api/users",
        headers = {}
    })
    print("   Status:", int_response2.status)
    print("   Content-Type:", int_response2.headers["Content-Type"])
    
    -- Demo 3: Show specific user
    print("\n3. GET /users/1 (via Router)")
    local int_response3 = handler({
        method = "GET",
        path = "/users/1", 
        params = { id = "1" },
        headers = {}
    })
    print("   Status:", int_response3.status)
    print("   Content-Type:", int_response3.headers["Content-Type"])
    
    print("\n🚀 FULL SERVER MODE")
    print("-" .. string.rep("-", 20))
    print("To start the full web server, run:")
    print("  LUA_PATH=\"./src/?.lua;$LUA_PATH\" lua example.lua --server")
    print("  Then visit: http://localhost:3000")
else
    print("\n⚠️  INTEGRATION UNAVAILABLE")
    print("-" .. string.rep("-", 25))
    print("Motor and/or Rota not found. Install them to enable full integration:")
    print("  cd ../motor && luarocks make")
    print("  cd ../rota && luarocks make")
end

print("\n✨ RAILS-LIKE FEATURES DEMONSTRATED:")
print("   ✓ before_action/after_action callbacks")
print("   ✓ RESTful actions (index, show, new, create, edit, update, destroy)")
print("   ✓ Strong parameters with require/permit")
print("   ✓ respond_to for multiple formats (HTML/JSON)")
print("   ✓ Flash messages")
print("   ✓ Authentication and authorization")
print("   ✓ Error handling and validation")
print("   ✓ Action execution with callback chain")
if motor_available and rota_available then
    print("   ✓ HTTP server integration")
    print("   ✓ Routing with parameters")
    print("   ✓ Middleware pipeline")
end

-- Server mode (if requested)
if arg and arg[1] == "--server" and motor_available and rota_available then
    print("\n" .. string.rep("=", 60))
    print("🚀 Starting Foguete Complete Example Server...")
    print("Components: Comando (controllers) + Motor (server) + Rota (routing)")
    print("Available at: http://localhost:3000")
    print("Press Ctrl+C to stop")
    print()
    
    local router = setup_integration()
    motor.serve({
        host = "127.0.0.1",
        port = 3000
    }, router:handler())
end

print("\n" .. string.rep("=", 60)) 