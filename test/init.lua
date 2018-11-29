local ot = require "openThermLibrary"
-------------
-- USE OF OpenTherm
-------------

print("start...")

ot.begin(5, 4)
print("response => ", ot.getBoilerStatus())