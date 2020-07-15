local buffer = require("omgameserver.buffer")
local msgpack = require("omgameserver.msgpack")

local function test_buffer_unsigned_byte()
	local b = buffer.create_empty()
	buffer.write_unsigned_byte(b, 160)
	assert(160 == buffer.read_unsigned_byte(b))
end

local function test_buffer_byte()
	local b = buffer.create_empty()
	buffer.write_byte(b, 64)
	assert(64 == buffer.read_byte(b))
end

local M = {}

function M.run()
	print("[OMGS/TESTS] Run")
	test_buffer_unsigned_byte()
	test_buffer_byte()
end

return M