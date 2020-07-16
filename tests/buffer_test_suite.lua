local buffer = require("omgameserver.buffer")

local function test_buffer_from_bytes()
	local b1 = buffer.create_empty()
	buffer.write_int(b1, 16121991)
	local b2 = buffer.from_bytes(b1.bytes)
	assert(16121991 == buffer.read_int(b2))
end

local function test_buffer_get_length()
	local b = buffer.create_empty()
	buffer.write_int(b, 16)
	buffer.write_int(b, 12)
	buffer.write_int(b, 1991)
	assert(4 * 3 == buffer.get_length(b))
end

local function test_buffer_remaining()
	local b = buffer.create_empty()
	buffer.write_int(b, 16)
	buffer.write_int(b, 12)
	buffer.write_int(b, 1991)
	buffer.read_int(b)
	assert(2 * 4 == buffer.remaining(b))
end

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

local function test_buffer_unsigned_short()
	local b = buffer.create_empty()
	buffer.write_unsigned_short(b, 49152)
	assert(49152 == buffer.read_unsigned_short(b))
end

local function test_buffer_short()
	local b = buffer.create_empty()
	buffer.write_short(b, 16384)
	assert(16384 == buffer.read_short(b))
end

local function test_buffer_unsigned_int()
	local b = buffer.create_empty()
	buffer.write_unsigned_int(b, 2147483648)
	assert(2147483648 == buffer.read_unsigned_int(b))
end

local function test_buffer_int()
	local b = buffer.create_empty()
	buffer.write_int(b, 1073741824)
	assert(1073741824 == buffer.read_int(b))
end

local function test_buffer_float()
	local b = buffer.create_empty()
	local pi = 3.141592653589
	buffer.write_float(b, pi)
	assert(pi - buffer.read_float(b) < 0.000001)
end

local function test_buffer_double()
	local b = buffer.create_empty()
	local pi = 3.141592653589
	buffer.write_double(b, pi)
	assert(pi == buffer.read_double(b))
end

local function test_buffer_read_write_bytes()
	local b1 = buffer.create_empty()
	buffer.write_int(b1, 16)
	buffer.write_int(b1, 12)
	buffer.write_int(b1, 1991)
	local b2 = buffer.create_empty()
	local bytes = buffer.read_bytes(b1, 2 * 4)
	buffer.write_bytes(b2, bytes)
	buffer.write_int(b2, 1991)
	assert(16, buffer.read_int(b2))
	assert(12, buffer.read_int(b2))
	assert(1991, buffer.read_int(b2))
end

local function test_buffer_read_write_string()
	local b1 = buffer.create_empty()
	buffer.write_string(b1, "hello")
	buffer.write_string(b1, "world")
	assert("helloworld" == buffer.read_string(b1, 10))
end

local function test_buffer_write_buffer()
	local b1 = buffer.create_empty()
	buffer.write_int(b1, 16)
	buffer.write_int(b1, 12)
	buffer.write_int(b1, 1991)
	buffer.read_int(b1)
	local b2 = buffer.create_empty()
	buffer.write_buffer(b2, b1)
	assert(12 == buffer.read_int(b2))
	assert(1991 == buffer.read_int(b2))
end

local function test_buffer_get_hex()
	local b1 = buffer.create_empty()
	buffer.write_int(b1, 16)
	buffer.write_int(b1, 12)
	buffer.write_int(b1, 1991)
	assert("00 00 00 10 00 00 00 0C 00 00 07 C7" == buffer.get_hex(b1))
end

local buffer_test_suite = function()
	test_buffer_from_bytes()
	test_buffer_get_length()
	test_buffer_remaining()
	test_buffer_unsigned_byte()
	test_buffer_byte()
	test_buffer_unsigned_short()
	test_buffer_short()
	test_buffer_unsigned_int()
	test_buffer_int()
	test_buffer_float()
	test_buffer_double()
	test_buffer_read_write_bytes()
	test_buffer_read_write_string()
	test_buffer_write_buffer()
	test_buffer_get_hex()
	print("[OMGS/TESTS] test suite for buffer: passed")
end

return buffer_test_suite