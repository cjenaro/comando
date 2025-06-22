-- Base Controller Specification
-- Comprehensive tests for base controller functionality

local BaseController = require("comando")

describe("BaseController", function()
    local controller, request, response
    
    before_each(function()
        request = {
            params = { id = "123", name = "test", user = { name = "John", email = "john@test.com" } },
            session = { user_id = 1 },
            flash = {},
            headers = { Accept = "text/html" }
        }
        response = { headers = {} }
        controller = BaseController:new(request, response)
    end)
    
    describe("initialization", function()
        it("should create a new instance", function()
            assert.is_not_nil(controller)
            assert.is_table(controller.params)
            assert.is_table(controller.session)
            assert.is_table(controller.request)
            assert.is_table(controller.response)
        end)
        
        it("should initialize callback arrays", function()
            assert.is_table(controller._before_actions)
            assert.is_table(controller._after_actions)
            assert.is_table(controller._around_actions)
        end)
        
        it("should initialize flash messages", function()
            assert.is_table(controller.flash_messages)
        end)
    end)
    
    describe("parameter handling", function()
        it("should get parameters", function()
            assert.are.equal("123", controller:param("id"))
            assert.are.equal("test", controller:param("name"))
        end)
        
        it("should return default for missing parameters", function()
            assert.are.equal("default", controller:param("missing", "default"))
        end)
        
        it("should convert parameters to numbers", function()
            assert.are.equal(123, controller:param_number("id"))
        end)
        
        it("should convert parameters to booleans", function()
            controller.params.active = "true"
            assert.is_true(controller:param_boolean("active"))
            
            controller.params.inactive = "false"
            assert.is_false(controller:param_boolean("inactive"))
        end)
        
        it("should handle number conversion with defaults", function()
            assert.are.equal(10, controller:param_number("missing", 10))
        end)
        
        it("should handle boolean conversion with defaults", function()
            assert.is_true(controller:param_boolean("missing", true))
        end)
    end)
    
    describe("strong parameters", function()
        it("should require parameters", function()
            local params = controller:params_require("user")
            assert.is_table(params)
            assert.are.equal("John", params.name)
            assert.are.equal("john@test.com", params.email)
        end)
        
        it("should raise error for missing required params", function()
            assert.has_error(function()
                controller:params_require("missing")
            end)
        end)
        
        it("should permit specific parameters", function()
            local user_params = controller:params_require("user")
            local permitted = user_params:permit("name")
            
            assert.are.equal("John", permitted.name)
            assert.is_nil(permitted.email) -- not permitted
        end)
        
        it("should permit multiple parameters", function()
            local user_params = controller:params_require("user")
            local permitted = user_params:permit("name", "email")
            
            assert.are.equal("John", permitted.name)
            assert.are.equal("john@test.com", permitted.email)
        end)
        
        it("should chain require and permit", function()
            local permitted = controller:params_require("user"):permit("name", "email")
            
            assert.are.equal("John", permitted.name)
            assert.are.equal("john@test.com", permitted.email)
        end)
    end)
    
    describe("response methods", function()
        it("should render JSON responses", function()
            local response = controller:json({ message = "Hello" })
            assert.are.equal(200, response.status)
            assert.are.equal("application/json; charset=utf-8", 
                           response.headers["Content-Type"])
            assert.is_string(response.body)
        end)
        
        it("should render JSON with custom status", function()
            local response = controller:json({ error = "Bad request" }, 400)
            assert.are.equal(400, response.status)
        end)
        
        it("should create redirect responses", function()
            local response = controller:redirect("/users")
            assert.are.equal(302, response.status)
            assert.are.equal("/users", response.headers.Location)
        end)
        
        it("should create redirect with custom status", function()
            local response = controller:redirect("/users", 301)
            assert.are.equal(301, response.status)
        end)
        
        it("should create not found responses", function()
            local response = controller:not_found("Not found")
            assert.are.equal(404, response.status)
        end)
        
        it("should create bad request responses", function()
            local response = controller:bad_request("Invalid input")
            assert.are.equal(400, response.status)
        end)
        
        it("should create unauthorized responses", function()
            local response = controller:unauthorized("Login required")
            assert.are.equal(401, response.status)
        end)
        
        it("should create forbidden responses", function()
            local response = controller:forbidden("Access denied")
            assert.are.equal(403, response.status)
        end)
        
        it("should create internal server error responses", function()
            local response = controller:internal_server_error("Server error")
            assert.are.equal(500, response.status)
        end)
        
        it("should render templates", function()
            local response = controller:render("users/index", { users = {} })
            assert.are.equal(200, response.status)
            assert.are.equal("text/html; charset=utf-8", response.headers["Content-Type"])
        end)
        
        it("should render with custom status", function()
            local response = controller:render("errors/404", {}, 404)
            assert.are.equal(404, response.status)
        end)
    end)
    
    describe("respond_to", function()
        it("should respond to HTML format", function()
            controller.request.headers.Accept = "text/html"
            
            local response = controller:respond_to({
                html = function() return controller:render("test") end,
                json = function() return controller:json({}) end
            })
            
            assert.are.equal("text/html; charset=utf-8", response.headers["Content-Type"])
        end)
        
        it("should respond to JSON format", function()
            controller.request.headers.Accept = "application/json"
            
            local response = controller:respond_to({
                html = function() return controller:render("test") end,
                json = function() return controller:json({ data = "test" }) end
            })
            
            assert.are.equal("application/json; charset=utf-8", response.headers["Content-Type"])
        end)
        
        it("should default to HTML when format not specified", function()
            controller.request.headers.Accept = nil
            
            local response = controller:respond_to({
                html = function() return controller:render("test") end,
                json = function() return controller:json({}) end
            })
            
            assert.are.equal("text/html; charset=utf-8", response.headers["Content-Type"])
        end)
        
        it("should return 406 for unsupported format", function()
            controller.request.headers.Accept = "application/xml"
            
            local response = controller:respond_to({
                html = function() return controller:render("test") end,
                json = function() return controller:json({}) end
            })
            
            assert.are.equal(406, response.status)
        end)
    end)
    
    describe("action callbacks", function()
        local TestController
        
        before_each(function()
            TestController = {}
            setmetatable(TestController, { __index = BaseController })
            
            function TestController:new(req, res)
                local instance = BaseController:new(req, res)
                setmetatable(instance, { __index = self })
                return instance
            end
            
            function TestController:test_action()
                return self:json({ message = "test" })
            end
        end)
        
        it("should register before_action callbacks", function()
            local test_controller = TestController:new(request, response)
            local callback_called = false
            
            test_controller:before_action(function()
                callback_called = true
            end)
            
            assert.are.equal(1, #test_controller._before_actions)
            
            -- Execute callback
            test_controller._before_actions[1].callback(test_controller)
            assert.is_true(callback_called)
        end)
        
        it("should register after_action callbacks", function()
            local test_controller = TestController:new(request, response)
            local callback_called = false
            
            test_controller:after_action(function()
                callback_called = true
            end)
            
            assert.are.equal(1, #test_controller._after_actions)
            
            -- Execute callback
            test_controller._after_actions[1].callback(test_controller)
            assert.is_true(callback_called)
        end)
        
        it("should filter callbacks with 'only' option", function()
            local test_controller = TestController:new(request, response)
            
            test_controller:before_action(function() end, { only = {"show", "edit"} })
            
            local callback = test_controller._before_actions[1]
            assert.is_table(callback.only)
            assert.are.equal(2, #callback.only)
        end)
        
        it("should filter callbacks with 'except' option", function()
            local test_controller = TestController:new(request, response)
            
            test_controller:before_action(function() end, { except = {"index"} })
            
            local callback = test_controller._before_actions[1]
            assert.is_table(callback.except)
            assert.are.equal(1, #callback.except)
        end)
        
        it("should execute action with callback chain", function()
            local test_controller = TestController:new(request, response)
            local before_called = false
            local after_called = false
            
            test_controller:before_action(function()
                before_called = true
            end)
            
            test_controller:after_action(function()
                after_called = true
            end)
            
            local response = test_controller:execute_action("test_action")
            
            assert.is_true(before_called)
            assert.is_true(after_called)
            assert.are.equal(200, response.status)
        end)
        
        it("should halt execution if before_action returns response", function()
            local test_controller = TestController:new(request, response)
            local action_called = false
            
            test_controller:before_action(function(ctrl)
                return ctrl:unauthorized("Access denied")
            end)
            
            -- Override test_action to track if it's called
            function test_controller:test_action()
                action_called = true
                return self:json({ message = "test" })
            end
            
            local response = test_controller:execute_action("test_action")
            
            assert.is_false(action_called)
            assert.are.equal(401, response.status)
        end)
    end)
    
    describe("authentication", function()
        it("should detect authenticated users", function()
            assert.is_true(controller:authenticated())
        end)
        
        it("should detect unauthenticated users", function()
            controller.session.user_id = nil
            assert.is_false(controller:authenticated())
        end)
        
        it("should get current user", function()
            local user = controller:current_user()
            assert.is_not_nil(user)
            assert.are.equal(1, user.id)
        end)
        
        it("should return nil for unauthenticated user", function()
            controller.session.user_id = nil
            local user = controller:current_user()
            assert.is_nil(user)
        end)
        
        it("should require authentication", function()
            controller.session.user_id = nil
            local response = controller:authenticate()
            assert.are.equal(302, response.status)
            assert.are.equal("/login", response.headers.Location)
        end)
        
        it("should pass authentication when logged in", function()
            local response = controller:authenticate()
            assert.is_nil(response) -- No redirect needed
        end)
    end)
    
    describe("authorization", function()
        it("should authorize with permission", function()
            -- Mock user with admin role
            controller.session.user_id = 1
            local response = controller:authorize("admin", "panel")
            assert.is_nil(response) -- No forbidden response
        end)
        
        it("should deny authorization without permission", function()
            -- Mock user without admin role
            controller.session.user_id = 2
            local response = controller:authorize("admin", "panel")
            assert.are.equal(403, response.status)
        end)
        
        it("should deny authorization for unauthenticated user", function()
            controller.session.user_id = nil
            local response = controller:authorize("admin", "panel")
            assert.are.equal(403, response.status)
        end)
    end)
    
    describe("flash messages", function()
        it("should set flash messages", function()
            controller:flash("Success!", "success")
            assert.are.equal("Success!", controller.flash_messages.success)
        end)
        
        it("should set flash with default type", function()
            controller:flash("Info message")
            assert.are.equal("Info message", controller.flash_messages.notice)
        end)
        
        it("should handle multiple flash types", function()
            controller:flash("Success!", "success")
            controller:flash("Warning!", "warning")
            controller:flash("Error!", "error")
            
            assert.are.equal("Success!", controller.flash_messages.success)
            assert.are.equal("Warning!", controller.flash_messages.warning)
            assert.are.equal("Error!", controller.flash_messages.error)
        end)
    end)
    
    describe("error handling", function()
        it("should prevent double render", function()
            controller.rendered = true
            
            assert.has_error(function()
                controller:json({ message = "test" })
            end, "Response already rendered")
        end)
        
        it("should handle rescue_from", function()
            local TestController = {}
            setmetatable(TestController, { __index = BaseController })
            
            function TestController:new(req, res)
                local instance = BaseController:new(req, res)
                setmetatable(instance, { __index = self })
                
                instance:rescue_from("CustomError", function(ctrl, err)
                    return ctrl:json({ error = "Handled: " .. err }, 422)
                end)
                
                return instance
            end
            
            local test_controller = TestController:new(request, response)
            local response = test_controller:handle_exception("CustomError", "Something went wrong")
            
            assert.are.equal(422, response.status)
            assert.is_string(response.body)
        end)
        
        it("should return 500 for unhandled exceptions", function()
            local response = controller:handle_exception("UnknownError", "Unhandled error")
            assert.are.equal(500, response.status)
        end)
    end)
    
    describe("RESTful actions support", function()
        it("should support standard REST action names", function()
            local actions = {"index", "show", "new", "create", "edit", "update", "destroy"}
            
            for _, action in ipairs(actions) do
                -- Should not error when checking if action exists
                local exists = type(controller[action]) == "function" or controller[action] == nil
                assert.is_true(exists, "Action " .. action .. " should be supported")
            end
        end)
    end)
end) 