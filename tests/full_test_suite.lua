local buffer_test_suite = require("tests.buffer_test_suite")
local msgpack_test_suite = require("tests.msgpack_test_suite")

local full_test_suite = function()
	buffer_test_suite()
	msgpack_test_suite()
end

return full_test_suite