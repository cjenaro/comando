package = "comando"
version = "0.0.1-1"
source = {
   url = "git+https://github.com/foguete-dev/comando.git",
   tag = "v0.0.1"
}
description = {
   summary = "Base controller helpers for Foguete framework",
   detailed = [[
      Comando provides base controller functionality and helper methods 
      for handling HTTP requests and responses in the Foguete web framework.
      
      Features include request/response handling, parameter parsing, 
      session management, authentication, authorization, and rendering utilities.
   ]],
   homepage = "https://github.com/foguete-dev/comando",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "dkjson"
}
build = {
   type = "builtin",
   modules = {
      ["comando"] = "src/comando.lua",
      ["comando.base_controller"] = "src/base_controller.lua",
      ["comando.response_helpers"] = "src/response_helpers.lua",
      ["comando.auth_helpers"] = "src/auth_helpers.lua",
      ["comando.param_helpers"] = "src/param_helpers.lua"
   }
}
external_dependencies = {
   OPENSSL = {
      header = "openssl/opensslv.h"
   }
} 