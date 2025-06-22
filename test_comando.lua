#!/usr/bin/env lua

-- Comando Test Suite
-- Tests for the base controller functionality

local BaseController = require("comando")

-- Simple test framework
local Test = {}
Test.passed = 0
Test.failed = 0

function Test:assert(condition, message)
    if condition then
        self.passed = self.passed + 1
        print("✓ " .. (message or "Assertion passed"))
    else
        self.failed = self.failed + 1
        print("✗ " .. (message or "Assertion failed"))
    end
end

function Test:assert_equal(expected, actual, message)
    local condition = expected == actual
    if not condition then
        message = string.format("%s (expected: %s, got: %s)", 
            message or "Values should be equal", 
            tostring(expected), 
            tostring(actual))
    end
    self:assert(condition, message)
end

function Test:assert_not_nil(value, message)
    self:assert(value ~= nil, message or "Value should not be nil")
end

function Test:summary()
    print("\n=== Test Summary ===")
    print(string.format("Passed: %d", self.passed))
    print(string.format("Failed: %d", self.failed))
    print(string.format("Total: %d", self.passed + self.failed))
    
    if self.failed == 0 then
        print("All tests passed! ✓")
        return true
    else
        print("Some tests failed! ✗")
        return false
    end
end

-- Mock request/response for testing
local function create_mock_request(params, session)
    return {
        params = params or {},
        session = session or {},
        flash = {}
    }
end

local function create_mock_response()
    return {}
end

-- Test suite
print("=== Comando Base Controller Tests ===")
print()

-- Test 1: Controller initialization
print("Test 1: Controller Initialization")
local request = create_mock_request({ id = "123" }, { user_id = 1 })
local response = create_mock_response()
local controller = BaseController:new(request, response)

Test:assert_not_nil(controller, "Controller should be created")
Test:assert_not_nil(controller.params, "Controller should have params")
Test:assert_not_nil(controller.session, "Controller should have session")
Test:assert_equal("123", controller.params.id, "Controller should have correct params")
Test:assert_equal(1, controller.session.user_id, "Controller should have correct session")
print()

-- Test 2: Parameter handling
print("Test 2: Parameter Handling")
local params = { name = "John", age = "25", active = "true" }
local controller2 = BaseController:new(create_mock_request(params))

Test:assert_equal("John", controller2:param("name"), "Should get string parameter")
Test:assert_equal(25, controller2:param_number("age"), "Should get number parameter")
Test:assert_equal(true, controller2:param_boolean("active"), "Should get boolean parameter")
Test:assert_equal("default", controller2:param("missing", "default"), "Should return default for missing param")
print()

-- Test 3: Parameter validation
print("Test 3: Parameter Validation")
local controller3 = BaseController:new(create_mock_request({ email = "invalid-email" }))
local validation_result = controller3:validate_email("email", true)
Test:assert_not_nil(validation_result, "Should fail validation for invalid email")
Test:assert_equal(400, validation_result.status, "Should return 400 for validation error")

local controller4 = BaseController:new(create_mock_request({ email = "test@example.com" }))
local validation_result2 = controller4:validate_email("email", true)
Test:assert(validation_result2 == nil, "Should pass validation for valid email")
print()

-- Test 4: Strong parameters
print("Test 4: Strong Parameters")
local all_params = { name = "John", age = 25, secret = "hidden", email = "john@example.com" }
local controller5 = BaseController:new(create_mock_request(all_params))
local permitted = controller5:permit("name", "email")

Test:assert_equal("John", permitted.name, "Should include permitted parameter")
Test:assert_equal("john@example.com", permitted.email, "Should include permitted parameter")
Test:assert(permitted.secret == nil, "Should exclude non-permitted parameter")
Test:assert(permitted.age == nil, "Should exclude non-permitted parameter")
print()

-- Test 5: Response helpers
print("Test 5: Response Helpers")
local controller6 = BaseController:new()

local json_response = controller6:json({ message = "Hello" })
Test:assert_equal(200, json_response.status, "JSON response should have 200 status")
Test:assert_equal("application/json; charset=utf-8", json_response.headers["Content-Type"], "Should have JSON content type")

local not_found_response = controller6:not_found("Item not found")
Test:assert_equal(404, not_found_response.status, "Not found response should have 404 status")

local redirect_response = controller6:redirect("/users")
Test:assert_equal(302, redirect_response.status, "Redirect should have 302 status")
Test:assert_equal("/users", redirect_response.headers.Location, "Should have correct location header")
print()

-- Test 6: Flash messages
print("Test 6: Flash Messages")
local controller7 = BaseController:new(create_mock_request())
controller7:flash("Success message", "success")
controller7:flash("Error message", "error")

Test:assert_equal("Success message", controller7.flash_messages.success, "Should set success flash message")
Test:assert_equal("Error message", controller7.flash_messages.error, "Should set error flash message")
print()

-- Test 7: Authentication helpers
print("Test 7: Authentication Helpers")
local controller8 = BaseController:new(create_mock_request({}, { user_id = 42, user_name = "Alice" }))
local user = controller8:current_user()

Test:assert_not_nil(user, "Should return current user")
Test:assert_equal(42, user.id, "Should have correct user ID")
Test:assert_equal("Alice", user.name, "Should have correct user name")
Test:assert(controller8:authenticated(), "Should be authenticated")

local controller9 = BaseController:new(create_mock_request())
Test:assert(controller9:guest(), "Should be guest (not authenticated)")
print()

-- Test 8: Authorization
print("Test 8: Authorization")
local controller10 = BaseController:new(create_mock_request({}, { 
    user_id = 1, 
    user_roles = { "admin" } 
}))

Test:assert(controller10:has_role("admin"), "Should have admin role")
Test:assert(controller10:can("delete", {}), "Admin should be able to delete")

local controller11 = BaseController:new(create_mock_request({}, { 
    user_id = 2, 
    user_roles = { "user" } 
}))

Test:assert(not controller11:has_role("admin"), "Should not have admin role")
Test:assert(controller11:can("read", {}), "User should be able to read")
print()

-- Test 9: Pagination parameters
print("Test 9: Pagination Parameters")
local controller12 = BaseController:new(create_mock_request({ page = "2", per_page = "10" }))
local pagination = controller12:pagination_params()

Test:assert_equal(2, pagination.page, "Should have correct page")
Test:assert_equal(10, pagination.per_page, "Should have correct per_page")
Test:assert_equal(10, pagination.offset, "Should calculate correct offset")
print()

-- Test 10: Template rendering
print("Test 10: Template Rendering")
local controller13 = BaseController:new(create_mock_request())
controller13:flash("Welcome!", "notice")
local render_response = controller13:render("users/index", { title = "Users", users = {} })

Test:assert_equal(200, render_response.status, "Should have 200 status")
Test:assert_equal("text/html; charset=utf-8", render_response.headers["Content-Type"], "Should have HTML content type")
Test:assert(string.find(render_response.body, "Users"), "Should contain title in body")
Test:assert(string.find(render_response.body, "Welcome!"), "Should contain flash message in body")
print()

-- Print test summary
Test:summary() 