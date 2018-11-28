local ot = require "openThermLibrary"
-------------
-- USE OF OpenTherm
-------------

print("start...")

ot.init(5, 4)
ot.begin()
print("response => ", ot.getBoilerStatus())