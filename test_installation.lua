#!/usr/bin/env lua

-- Comando Installation Test
-- Simple test to verify comando is properly installed

local function test_installation()
    print("=== Comando Installation Test ===")
    
    -- Test 1: Can require main module
    local success, BaseController = pcall(require, "foguete.comando")
    if not success then
        print("✗ Failed to require 'foguete.comando'")
        return false
    end
    print("✓ Successfully required 'foguete.comando'")
    
    -- Test 2: Can create controller instance
    local controller = BaseController:new()
    if not controller then
        print("✗ Failed to create controller instance")
        return false
    end
    print("✓ Successfully created controller instance")
    
    -- Test 3: Controller has expected methods
    local methods = {
        "render", "json", "redirect", "params", "session", 
        "flash", "authenticate", "current_user", "param"
    }
    
    for _, method in ipairs(methods) do
        if type(controller[method]) ~= "function" then
            print("✗ Missing method: " .. method)
            return false
        end
    end
    print("✓ All expected methods present")
    
    print("\nCommando installation test passed! ✓")
    return true
end

return test_installation() 