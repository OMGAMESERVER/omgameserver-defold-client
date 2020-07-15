local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub
local string_format = string.format
local math_floor = math.floor
local math_frexp = math.frexp
local math_ldexp = math.ldexp
local bit_band = bit.band
local bit_rshift = bit.rshift

local M = {}

-- Local functions forward declarations
local get_length
local get_hex

local function create_empty()
	local buffer = {
		__tostring = function(self)
			return "[pos=" .. self.read_position .. ", len=" .. get_length(self)
			.. ", hex=\"" .. get_hex(self) .. "\"]"
		end,
	}
	buffer.bytes = ""
	buffer.read_position = 1

	return buffer
end
M.create_empty = create_empty

local function from_bytes(bytes)
	local buffer = create_empty()
	buffer.bytes = bytes

	return buffer
end
M.from_bytes = from_bytes

get_length = function(buffer)
	return #buffer.bytes
end
M.get_length = get_length

local function remaining(buffer)
	return #buffer.bytes - buffer.read_position + 1
end
M.remaining = remaining

local function read_unsigned_byte(buffer)
	local buffer_read_position = buffer.read_position

	local value = string_byte(buffer.bytes, buffer_read_position)

	buffer.read_position = buffer_read_position + 1

	return value
end
M.read_unsigned_byte = read_unsigned_byte

local function read_byte(buffer)
	local value = read_unsigned_byte(buffer)

	if (value > 127) then
		return -256 + value
	else
		return value
	end
end
M.read_byte = read_byte

local function write_unsigned_byte(buffer, value)	
	buffer.bytes = buffer.bytes .. string_char(value)

	return buffer
end
M.write_unsigned_byte = write_unsigned_byte

local function write_byte(buffer, value)
	if (value < 0) then
		value = value + 256
	end

	return write_unsigned_byte(buffer, value)
end
M.write_byte = write_byte

local function read_unsigned_short(buffer)
	local buffer_read_position = buffer.read_position

	local b2, b1 = string_byte(buffer.bytes, buffer_read_position, buffer_read_position + 1)
	local value = b1 + 256 * b2

	buffer.read_position = buffer_read_position + 2

	return value
end
M.read_unsigned_short = read_unsigned_short

local function read_short(buffer)
	local value = read_unsigned_short(buffer)

	if (value > 32767) then
		return -65536 + value
	else
		return value
	end
end
M.read_short = read_short

local function write_unsigned_short(buffer, value)
	local b2 = bit_band(bit_rshift(value, 8), 0xFF)
	local b1 = bit_band(value, 0xFF)

	buffer.bytes = buffer.bytes .. string_char(b2, b1)

	return buffer
end
M.write_unsigned_short = write_unsigned_short

local function write_short(buffer, value)
	if (value < 0) then
		value = value + 65536
	end

	return write_unsigned_short(buffer, value)
end
M.write_short = write_short

local function read_unsigned_int(buffer)
	local buffer_read_position = self.read_position

	local b4, b3, b2, b1 = string_byte(buffer.bytes, buffer_read_position, buffer_read_position + 3)
	local value = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216

	buffer.read_position = buffer_read_position + 4

	return value
end
M.read_unsigned_int = read_unsigned_int

local function read_int(buffer)
	local value = read_unsigned_int(buffer)

	if (value > 2147483647) then
		return -4294967296 + value
	else
		return value
	end
end
M.read_int = read_int

local function write_unsigned_int(buffer, value)
	local b4 = bit_band(bit_rshift(value, 24), 0xFF)
	local b3 = bit_band(bit_rshift(value, 16), 0xFF)
	local b2 = bit_band(bit_rshift(value, 8), 0xFF)
	local b1 = bit_band(value, 0xFF)

	buffer.bytes = buffer.bytes .. string_char(b4, b3, b2, b1)

	return buffer
end
M.write_unsigned_int = write_unsigned_int

local function write_int(buffer, value)
	if (value < 0) then
		value = value + 4294967296
	end

	return write_unsigned_int(buffer, value)
end
M.write_int = write_int

local function read_float(buffer)
	local buffer_read_position = buffer.read_position

	local b4, b3, b2, b1 = string_byte(buffer.bytes, buffer_read_position, buffer_read_position + 3)

	buffer.read_position = buffer_read_position + 4

	local e = (b4 % 128) * 2 + math_floor(b3 / 128)
	if (e == 0) then
		return 0
	end

	local sign = 1
	if (b4 > 127) then
		sign = -1
	end

	local m = (((b3 % 128) * 65536 + b2 * 256 + b1) / 8388608 + 1) * sign

	return math_ldexp(m, e - 127)
end
M.read_float = read_float

local function write_float(buffer, value)
	local sign = 0
	if (value < 0) then
		sign = 1
		value = -value
	end

	local m, e
	if (value == 0) then
		m = 0
		e = 0
	else
		m, e = math_frexp(value)
		-- Multiply to 2 for convert from [0.5; 1.0] in [1.0; 2.0] as IEEE754
		m = (m * 2 - 1) * 8388608
		e = e + 126
	end

	local b1 = m % 256
	local b2 = math_floor(m / 256) % 256
	local b3 = (math_floor(m / 65536) + e * 128) % 256
	local b4 = math_floor((math_floor(m / 65536) + e * 128) / 256) + sign * 128

	buffer.bytes = buffer.bytes .. string_char(b4, b3, b2, b1)

	return buffer
end
M.write_float = write_float

local function read_double(buffer)
	local buffer_read_position = buffer.read_position

	local b8, b7, b6, b5, b4, b3, b2, b1 = string_byte(buffer.bytes, buffer_read_position, buffer_read_position + 7)

	buffer.read_position = buffer_read_position + 8

	local e = (b8 % 128) * 2 + math_floor(b7 / 16)
	if (e == 0) then
		return 0
	end

	local sign = 1
	if (b8 > 127) then
		sign = -1
	end

	local m = (((b7 % 16) * 281474976710656 + 
	b6 * 1099511627776 + 
	b5 * 4294967296 + 
	b4 * 16777216 + 
	b3 * 65536 + 
	b2 * 256 + b1) / 4503599627370496 + 1) * sign

	return math_ldexp(m, e - 127)
end
M.read_double = read_double

local function write_double(buffer, value)
	local sign = 0
	if (value < 0) then
		sign = 1
		value = -value
	end

	local m, e
	if (value == 0) then
		m = 0
		e = 0
	else
		m, e = math_frexp(value)
		-- Multiply to 2 for convert from [0.5; 1.0] in [1.0; 2.0] as IEEE754
		m = (m * 2 - 1) * 4503599627370496
		e = e + 1022
	end

	local b1 = m % 256
	local b2 = math_floor(m / 256) % 256
	local b3 = math_floor(m / 65536) % 256
	local b4 = math_floor(m / 16777216) % 256
	local b5 = math_floor(m / 4294967296) % 256
	local b6 = math_floor(m / 1099511627776) % 256
	local b7 = math_floor(math_floor(m / 281474976710656) + e * 16) % 256
	local b8 = math_floor((math_floor(m / 281474976710656) + e * 16) / 256) + sign * 128

	buffer.bytes = buffer.bytes .. string_char(b8, b7, b6, b5, b4, b3, b2, b1)

	return buffer
end
M.write_double = write_double

local function read_bytes(buffer, length)
	local buffer_read_position = buffer.read_position

	local bytes
	if (length) then
		bytes = string_sub(buffer.bytes, buffer_read_position, buffer_read_position + length - 1)
		buffer.read_position = buffer_read_position + length
	else
		bytes = string_sub(buffer.bytes, buffer_read_position)
		buffer.read_position = #buffer.bytes
	end

	return bytes
end
M.read_bytes = read_bytes

local function write_bytes(buffer, bytes)
	buffer.bytes = buffer.bytes .. bytes

	return buffer
end
M.write_bytes = write_bytes

local function read_string(buffer, length)
	return read_bytes(buffer, length)
end
M.read_string = read_string

local function write_string(buffer, string)
	return write_bytes(buffer, string)
end
M.write_string = write_string

local function write_buffer(target, source)
	return write_bytes(target, source.bytes)
end
M.write_buffer = write_buffer

get_hex = function(buffer)
	if (#buffer.bytes == 0) then
		return ""
	else
		local self_bytes = buffer.bytes
		local result = string_format("%X", string_byte(self_bytes, 1))

		for index = 2, #self_bytes do
			local h = string_format("%X", string_byte(self_bytes, index))
			if (#h == 1) then
				result = result .. " 0".. h
			else
				result = result .. " " .. h
			end
		end

		return result
	end
end
M.get_hex = get_hex

return M