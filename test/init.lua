local ot = require "openThermLibrary"
-------------
-- USE OF OpenTherm
-------------

log("start...")

ot.init(5, 4)
ot.begin()
local req = ot.buildGetBoilerStatusRequest(true, true, false, false, false)
ot.sendRequest(req, function(response, responseStatus) log("response => ", response, " status => ", responseStatus) end)




