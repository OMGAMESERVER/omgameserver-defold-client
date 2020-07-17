local buffer = require("omgameserver.buffer")

local buffer_create_empty = buffer.create_empty
local buffer_write_byte = buffer.write_byte
local buffer_write_unsigned_byte = buffer.write_unsigned_byte
local buffer_write_short = buffer.write_short
local buffer_write_unsigned_short = buffer.write_unsigned_short
local buffer_write_int = buffer.write_int
local buffer_write_unsigned_int = buffer.write_unsigned_int
local buffer_write_float = buffer.write_float
local buffer_write_double = buffer.write_double
local buffer_write_bytes = buffer.write_bytes
local buffer_write_buffer = buffer.write_buffer
local buffer_read_byte = buffer.read_byte
local buffer_read_unsigned_byte = buffer.read_unsigned_byte
local buffer_read_short = buffer.read_short
local buffer_read_unsigned_short = buffer.read_unsigned_short
local buffer_read_int = buffer.read_int
local buffer_read_unsigned_int = buffer.read_unsigned_int
local buffer_read_string = buffer.read_string
local buffer_read_float = buffer.read_float
local buffer_read_double = buffer.read_double

local math_floor = math.floor

-- Debug mode toggle
local DEBUG = false

-- Local functions forward declarations
local is_an_array
local decode_array
local decode_map

local function encode_value(value)
	local value_type = type(value)
	local buffer = buffer_create_empty()

	if (value_type == "boolean") then
		if (value) then
			buffer_write_unsigned_byte(buffer, 0xc3)
		else
			buffer_write_unsigned_byte(buffer, 0xc2)
		end

	elseif (value_type == "number") then
		-- integer
		if (value == math_floor(value)) then
			if (value >= 0) then
				if (value < 128) then
					buffer_write_unsigned_byte(buffer, value)
				elseif (value < 256) then
					buffer_write_unsigned_byte(buffer, 0xcc)
					buffer_write_unsigned_byte(buffer, value)
				elseif (value < 65536) then
					buffer_write_unsigned_byte(buffer, 0xcd)
					buffer_write_unsigned_short(buffer, value)
				elseif (value < 4294967296) then
					buffer_write_unsigned_byte(buffer, 0xce)
					buffer_write_unsigned_int(buffer, value)
				else
					-- uint 64 - not supported, in client and server replaced by double
					buffer_write_unsigned_byte(buffer, 0xcf)
					buffer_write_double(buffer, value)
				end
			else
				if (value >= -32) then
					buffer_write_unsigned_byte(buffer, 0xe0 + (value + 32))
				elseif (value >= -128) then
					buffer_write_unsigned_byte(buffer, 0xd0)
					buffer_write_byte(buffer, value)
				elseif (value >= -32768) then
					buffer_write_unsigned_byte(buffer, 0xd1)
					buffer_write_short(buffer, value)
				elseif (value >= -2147483648) then
					buffer_write_unsigned_byte(buffer, 0xd2)
					buffer_write_int(buffer, value)
				else
					-- int 64 - not supported, in client and server replaced by double
					buffer_write_unsigned_byte(buffer, 0xcb)
					buffer_write_double(buffer, value)
				end
			end

			-- float
		else
			-- TODO pack as float64 (0xcb)
			buffer_write_unsigned_byte(buffer, 0xca)
			buffer_write_float(buffer, value)
		end

	elseif (value_type == "string") then
		local len = #value

		if (len < 32) then
			buffer_write_unsigned_byte(buffer, 0xa0 + len)
		elseif (len < 256) then
			buffer_write_unsigned_byte(buffer, 0xd9)
			buffer_write_unsigned_byte(buffer, len)
		elseif (len < 65536) then
			buffer_write_unsigned_byte(buffer, 0xda)
			buffer_write_unsigned_short(buffer, len)
		else
			buffer_write_unsigned_byte(buffer, 0xdb)
			buffer_write_unsigned_int(buffer, len)
		end

		buffer_write_bytes(buffer, value)

	elseif (value_type == "table") then
		local elements = {}

		-- It seems to be a proper Lua array
		if (is_an_array(value)) then
			for _, v in pairs(value) do
				elements[#elements + 1] = encode_value(v)
			end
			local length = #elements
			if length < 16 then
				buffer_write_unsigned_byte(buffer, 0x90 + length)
			elseif length < 65536 then
				buffer_write_unsigned_byte(buffer, 0xdc)
				buffer_write_unsigned_short(buffer, length)
			else
				buffer_write_unsigned_byte(buffer, 0xdd)
				buffer_write_unsigned_int(buffer, length)
			end

			-- Encode as a map
		else
			for k, v in pairs(value) do
				elements[#elements + 1] = encode_value(k)
				elements[#elements + 1] = encode_value(v)
			end

			local length = math_floor(#elements / 2)
			if length < 16 then
				buffer_write_unsigned_byte(buffer, 0x80 + length)
			elseif length < 65536 then
				buffer_write_unsigned_byte(buffer, 0xde)
				buffer_write_unsigned_short(buffer, length)
			else
				buffer_write_unsigned_byte(buffer, 0xdf)
				buffer_write_unsigned_int(buffer, length)
			end
		end

		for _, v in pairs(elements) do
			buffer_write_buffer(buffer, v)
		end
	else
		if (DEBUG) then
			print("[OMGS/MSGPACK] Unknown value type " .. value_type)
		end
	end

	return buffer
end

local function decode_value(buffer)
	local byte = buffer_read_unsigned_byte(buffer)

	-- false
	if (byte == 0xc2) then
		return false
	-- true
	elseif (byte == 0xc3) then
		return true
	-- bin 8
	elseif (byte == 0xc4) then
		local length = buffer_read_unsigned_byte(buffer)
		return buffer_read_bytes(buffer, length)
	-- bin 16
	elseif (byte == 0xc5) then
		local length = buffer_read_unsigned_short(buffer)
		return buffer_read_bytes(buffer, length)
	-- bin 32
	elseif (byte == 0xc6) then
		local length = buffer_read_unsigned_int(buffer)
		return buffer_read_bytes(buffer, length)
	-- float 32
	elseif (byte == 0xca) then
		return buffer_read_float(buffer)
	-- float 64
	elseif (byte == 0xcb) then
		return buffer_read_double(buffer)
	-- uint 8
	elseif (byte == 0xcc) then
		return buffer_read_unsigned_byte(buffer)
	-- uint 16
	elseif (byte == 0xcd) then
		return buffer_read_unsigned_short(buffer)	
	-- uint 32
	elseif (byte == 0xce) then
		return buffer_read_unsigned_int(buffer)	
	-- uint 64 - not supported, in client and server replaced by double
	elseif (byte == 0xcf) then
		return buffer_read_double(buffer)
	-- int 8
	elseif (byte == 0xd0) then
		return buffer_read_byte(buffer)
	-- int 16
	elseif (byte == 0xd1) then
		return buffer_read_short(buffer)
	-- int 32
	elseif (byte == 0xd2) then
		return buffer_read_int(buffer)
	-- int 64 - not supported, in client and server replaced by double
	elseif (byte == 0xd3) then
		return buffer_read_double(buffer)
	-- str 8
	elseif (byte == 0xd9) then
		local length = buffer_read_unsigned_byte(buffer)
		return buffer_read_string(buffer, length)
	-- str 16
	elseif (byte == 0xda) then
		local length = buffer_read_unsigned_short(buffer)
		return buffer_read_string(buffer, length)
	-- str 32
	elseif (byte == 0xdb) then
		local length = buffer_read_unsigned_int(buffer)
		return buffer_read_string(buffer, length)
	-- array 16
	elseif (byte == 0xdc) then
		local length = buffer_read_unsigned_short(buffer)
		return decode_array(buffer, length)
	-- array 32
	elseif (byte == 0xdd) then
		local length = buffer_read_unsigned_int(buffer)
		return decode_array(buffer, length)
	-- map 16
	elseif (byte == 0xde) then
		local length = buffer_read_unsigned_short(buffer)
		return decode_map(buffer, length)
	-- map 32
	elseif (byte == 0xdf) then
		local length = buffer_read_unsigned_int(buffer)
		return decode_map(buffer, length)
	-- positive fixint (0xxxxxxx)
	elseif (byte >= 0x00 and byte <= 0x7f)then
		return byte
	-- fixmap (1000xxxx)
	elseif (byte >= 0x80 and byte <= 0x8f)then
		return decode_map(buffer, byte - 0x80)
	-- fixarray (1001xxxx)
	elseif (byte >= 0x90 and byte <= 0x9f)then
		return decode_array(buffer, byte - 0x90)
	-- fixstr (101xxxxx)
	elseif (byte >= 0xa0 and byte <= 0xbf)then
		return buffer_read_string(buffer, byte - 0xa0)
	-- negative fixint (111xxxxx)
	elseif (byte >= 0xe0 and byte <= 0xff)then
		return -32 + (byte - 0xe0)
	end
end

is_an_array = function(value)
	local expected = 1
	for k in pairs(value) do
		if k ~= expected then
			return false
		end

		expected = expected + 1
	end

	return true
end

decode_array = function(buffer, length)
	local elements = {}
	for i = 1, length do
		elements[i] = decode_value(buffer)
	end

	return elements
end

decode_map = function(buffer, length)
	local elements, key, value = {}
	for _ = 1, length do
		key = decode_value(buffer)
		value = decode_value(buffer)

		elements[key] = value
	end

	return elements
end

local M = {}

function M.debug(value)
	DEBUG = value or true
end

function M.encode(table)
	if (DEBUG) then
		return encode_value(table)
	else
		-- Protect call in non debug mode
		local ok, data = pcall(encode_value, table)
		if ok then
			return data
		else
			return nil, table .. " cannot encode to msgpack"
		end
	end
end

function M.decode(buffer)
	if (DEBUG) then
		return decode_value(buffer)
	else
		-- Protect call in non debug mode
		local ok, data = pcall(decode_value, buffer)
		if ok then
			return data
		else
			return nil, buffer .. " cannot decode from msgpack"
		end
	end
end

return M