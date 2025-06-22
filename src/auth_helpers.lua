-- Authentication and Authorization Helper Methods
-- Provides auth functionality for controllers

local AuthHelpers = {}

-- Check if user is authenticated
function AuthHelpers:authenticate()
    if not self.session.user_id then
        return self:redirect("/login")
    end
    return nil -- Continue processing
end

-- Get current authenticated user
function AuthHelpers:current_user()
    if not self._current_user and self.session.user_id then
        -- This would typically load from database
        -- For now, return a mock user object
        local roles = self.session.user_roles or {}
        
        -- Mock different users with different roles for testing
        if self.session.user_id == 1 then
            roles = {"admin"}
        elseif self.session.user_id == 2 then
            roles = {"user"}
        end
        
        self._current_user = {
            id = self.session.user_id,
            name = self.session.user_name or "User",
            email = self.session.user_email,
            roles = roles
        }
    end
    return self._current_user
end

-- Check if user is authenticated
function AuthHelpers:authenticated()
    return self:current_user() ~= nil
end

-- Check if user is guest (not authenticated)
function AuthHelpers:guest()
    return not self:authenticated()
end

-- Authorize user for specific action/resource
function AuthHelpers:authorize(action, resource)
    local user = self:current_user()
    if not user then
        return self:json({ status = "error", message = "Authentication required" }, 403)
    end
    
    if not self:can(action, resource) then
        return self:json({ status = "error", message = "Insufficient permissions" }, 403)
    end
    
    return nil -- Continue processing
end

-- Check if current user can perform action on resource
function AuthHelpers:can(action, resource)
    local user = self:current_user()
    if not user then
        return false
    end
    
    -- Simple role-based authorization
    -- In a real implementation, this would use a proper authorization system
    if self:has_role("admin") then
        return true -- Admin can do everything
    end
    
    -- Special case for admin panel
    if action == "admin" and resource == "panel" then
        return self:has_role("admin")
    end
    
    if action == "read" then
        return true -- All authenticated users can read
    end
    
    if action == "create" or action == "update" or action == "delete" then
        return self:has_role("editor") or self:owns_resource(resource)
    end
    
    return false
end

-- Check if user has specific role
function AuthHelpers:has_role(role)
    local user = self:current_user()
    if not user or not user.roles then
        return false
    end
    
    for _, user_role in ipairs(user.roles) do
        if user_role == role then
            return true
        end
    end
    
    return false
end

-- Check if user owns the resource
function AuthHelpers:owns_resource(resource)
    local user = self:current_user()
    if not user or not resource then
        return false
    end
    
    -- Simple ownership check
    if resource.user_id and resource.user_id == user.id then
        return true
    end
    
    if resource.owner_id and resource.owner_id == user.id then
        return true
    end
    
    return false
end

-- Require specific role
function AuthHelpers:require_role(role)
    if not self:has_role(role) then
        return self:forbidden("Role '" .. role .. "' required")
    end
    return nil
end

-- Require admin role
function AuthHelpers:require_admin()
    return self:require_role("admin")
end

-- Require editor role or higher
function AuthHelpers:require_editor()
    if not (self:has_role("admin") or self:has_role("editor")) then
        return self:forbidden("Editor role required")
    end
    return nil
end

-- Login user
function AuthHelpers:login(user)
    self.session.user_id = user.id
    self.session.user_name = user.name
    self.session.user_email = user.email
    self.session.user_roles = user.roles or {}
    self._current_user = user
end

-- Logout user
function AuthHelpers:logout()
    self.session.user_id = nil
    self.session.user_name = nil
    self.session.user_email = nil
    self.session.user_roles = nil
    self._current_user = nil
end

-- Remember user (for persistent login)
function AuthHelpers:remember(user, token)
    -- This would typically set a remember token cookie
    -- and store it in the database
    self.session.remember_token = token
end

-- Forget remembered user
function AuthHelpers:forget()
    self.session.remember_token = nil
end

return AuthHelpers 