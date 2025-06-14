# Comando - Controller Foundation 🎮

Comando provides the base controller functionality and helper methods for handling HTTP requests in Foguete applications.

## Features

- **Base Controller Class** - Common functionality for all controllers
- **Request Handling** - Parameter parsing and validation
- **Response Helpers** - JSON, HTML, and redirect utilities
- **Authentication** - Built-in auth and session management
- **Flash Messages** - Temporary user feedback
- **Error Handling** - Consistent error response patterns
- **RESTful Actions** - Standard CRUD operation support

## Quick Start

```lua
local BaseController = require("foguete.comando")
local User = require("app.models.user")

local UsersController = BaseController:extend()

function UsersController:index()
    local users = User:all()
    return self:render("users/index", { users = users })
end

function UsersController:show()
    local user = User:find(self.params.id)
    return self:render("users/show", { user = user })
end

return UsersController
```

## Base Controller

All controllers inherit from the base controller:

```lua
local BaseController = require("foguete.comando")
local MyController = BaseController:extend()

function MyController:my_action()
    -- Controller logic here
    return self:render("my_view", { data = "hello" })
end

return MyController
```

## Request & Response

### Accessing Request Data
```lua
function UsersController:create()
    -- URL parameters (from routes like /users/:id)
    local user_id = self.params.id
    
    -- Query parameters (?page=1&limit=10)
    local page = self.query.page or 1
    local limit = self.query.limit or 10
    
    -- POST/PUT body data
    local user_data = self.body.user
    
    -- Request headers
    local auth_header = self.headers.authorization
    
    -- Session data
    local current_user_id = self.session.user_id
end
```

### Response Methods
```lua
-- Render HTML template
return self:render("users/show", { user = user })

-- Render JSON
return self:json({ users = users })

-- Redirect
return self:redirect("/users")

-- Custom response
return {
    status = 201,
    headers = { ["Content-Type"] = "application/json" },
    body = '{"created": true}'
}
```

## Authentication & Authorization

### Basic Authentication
```lua
local AuthController = BaseController:extend()

function AuthController:login()
    local email = self.body.email
    local password = self.body.password
    
    local user = User:find_by({ email = email })
    if user and user:verify_password(password) then
        self.session.user_id = user.id
        return self:redirect("/dashboard")
    else
        self:flash("Invalid email or password", "error")
        return self:render("auth/login")
    end
end

function AuthController:logout()
    self.session.user_id = nil
    self:flash("Logged out successfully")
    return self:redirect("/")
end
```

### Authentication Helpers
```lua
-- In your controller
function MyController:create()
    -- Require authentication
    local auth_result = self:authenticate()
    if auth_result then return auth_result end
    
    -- Get current user
    local user = self:current_user()
    
    -- Check authorization
    local auth_result = self:authorize("create", "posts")
    if auth_result then return auth_result end
    
    -- Continue with action...
end
```

### Built-in Auth Methods
```lua
-- Require user to be logged in
function BaseController:authenticate()
    if not self.session.user_id then
        return self:redirect("/login")
    end
end

-- Get current logged-in user
function BaseController:current_user()
    if not self._current_user and self.session.user_id then
        self._current_user = User:find(self.session.user_id)
    end
    return self._current_user
end

-- Check if user can perform action
function BaseController:authorize(action, resource)
    local user = self:current_user()
    if not user:can(action, resource) then
        return self:forbidden()
    end
end
```

## Flash Messages

Temporary messages for user feedback:

```lua
function UsersController:create()
    local user = User:new(self.body.user)
    
    if user:save() then
        self:flash("User created successfully!", "success")
        return self:redirect("/users/" .. user.id)
    else
        self:flash("Failed to create user", "error")
        return self:render("users/new", { user = user })
    end
end
```

Access in templates:
```lua
-- In your template
if flash.success then
    print('<div class="alert alert-success">' .. flash.success .. '</div>')
end
```

## Error Handling

### Standard Error Responses
```lua
-- 404 Not Found
return self:not_found("User not found")

-- 403 Forbidden  
return self:forbidden("Access denied")

-- 500 Internal Server Error
return self:internal_error("Something went wrong")

-- 422 Unprocessable Entity
return self:unprocessable_entity({ email = "is required" })
```

### Custom Error Handling
```lua
function UsersController:show()
    local user = User:find(self.params.id)
    
    if not user then
        return self:not_found()
    end
    
    -- Handle potential errors
    local success, result = pcall(function()
        return self:render("users/show", { user = user })
    end)
    
    if not success then
        return self:internal_error("Failed to render user")
    end
    
    return result
end
```

## RESTful Actions

Standard REST controller pattern:

```lua
local UsersController = BaseController:extend()

-- GET /users
function UsersController:index()
    local users = User:all()
    return self:render("users/index", { users = users })
end

-- GET /users/:id
function UsersController:show()
    local user = User:find(self.params.id)
    return self:render("users/show", { user = user })
end

-- GET /users/new
function UsersController:new()
    local user = User:new()
    return self:render("users/new", { user = user })
end

-- POST /users
function UsersController:create()
    local user = User:new(self.body.user)
    
    if user:save() then
        return self:redirect("/users/" .. user.id)
    else
        return self:render("users/new", { user = user })
    end
end

-- GET /users/:id/edit
function UsersController:edit()
    local user = User:find(self.params.id)
    return self:render("users/edit", { user = user })
end

-- PUT /users/:id
function UsersController:update()
    local user = User:find(self.params.id)
    
    if user:update(self.body.user) then
        return self:redirect("/users/" .. user.id)
    else
        return self:render("users/edit", { user = user })
    end
end

-- DELETE /users/:id
function UsersController:destroy()
    local user = User:find(self.params.id)
    user:destroy()
    return self:redirect("/users")
end

return UsersController
```

## Parameter Validation

```lua
function UsersController:create()
    -- Define validation rules
    local rules = {
        name = { required = true, min_length = 2 },
        email = { required = true, format = "email" },
        age = { type = "number", min = 18 }
    }
    
    -- Validate parameters
    local validation = self:validate(self.body.user, rules)
    if not validation.valid then
        return self:unprocessable_entity(validation.errors)
    end
    
    -- Continue with creation...
end
```

## Contributing

Follow Comando conventions:
- Keep controllers thin and focused
- Use consistent response formats
- Implement proper error handling
- Follow RESTful patterns
- Include comprehensive tests
