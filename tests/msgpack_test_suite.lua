local msgpack = require("omgameserver.msgpack")

local function test_msgpack_simpletest()
	local b = msgpack.encode({
		payload = "helloworld"
	})
	local t = msgpack.decode(b)
	assert(t.payload == "helloworld")
end

local msgpack_test_suite = function()
	test_msgpack_simpletest()
	print("[OMGS/TESTS] test suite for msgpack: passed")
end

return msgpack_test_suite