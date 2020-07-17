local msgpack = require("omgameserver.msgpack")
local buffer = require("omgameserver.buffer")

local function create_buffer_from_byte_array(array)
	local b = buffer.create_empty()
	for i = 1, #array do buffer.write_unsigned_byte(b, array[i]) end
	return b
end

local function compare_table(t1, t2)
	for k, v in pairs(t1) do
		if type(t1[k]) == "table" then
			if (not compare_table(t1[k], t2[k])) then return false end
		else 
			if (t1[k] ~= t2[k]) then return false end
		end
	end
	return true
end

-- To prepare data was used this tool - https://kawanet.github.io/msgpack-lite/
local test_data = {
	boolean = {
		lua_table = { key1 = true, key2 = false },
		msgpack_buffer = create_buffer_from_byte_array({130, 164, 107, 101, 121, 49, 195, 164, 107, 101, 121, 50, 194}),
	},
	integer = {
		lua_table = { 
			positive_fixint = 64, unit8 = 160, unit16 = 1024, uint32 = 1048575, 
			negative_fixint = -16, int8 = -64, int16 = -4095, int32 = -268435455 
		},
		msgpack_buffer = create_buffer_from_byte_array({136, 175, 112, 111, 115, 105, 116, 105, 118, 101, 95, 102, 105, 120, 105, 110, 116, 64, 165, 117, 110, 105, 116, 56, 204, 160, 166, 117, 110, 105, 116, 49, 54, 205, 4, 0, 166, 117, 105, 110, 116, 51, 50, 206, 0, 15, 255, 255, 175, 110, 101, 103, 97, 116, 105, 118, 101, 95, 102, 105, 120, 105, 110, 116, 240, 164, 105, 110, 116, 56, 208, 192, 165, 105, 110, 116, 49, 54, 209, 240, 1, 165, 105, 110, 116, 51, 50, 210, 240, 0, 0, 1}),
	},
	strings = {
		lua_table = {
			fixstr = "Fixstr",
			str8 = "Str8str8str8str8str8str8str8str8str8str8",
			str16 = "Str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16str16",
			ключ = "значение"
		},
		msgpack_buffer = create_buffer_from_byte_array({132, 166, 102, 105, 120, 115, 116, 114, 166, 70, 105, 120, 115, 116, 114, 164, 115, 116, 114, 56, 217, 40, 83, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 115, 116, 114, 56, 165, 115, 116, 114, 49, 54, 218, 1, 9, 83, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 115, 116, 114, 49, 54, 168, 208, 186, 208, 187, 209, 142, 209, 135, 176, 208, 183, 208, 189, 208, 176, 209, 135, 208, 181, 208, 189, 208, 184, 208, 181})
	},
	arrays = {
		lua_table = {
			fixarray = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
			array16 = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32 }
		},
		msgpack_buffer = create_buffer_from_byte_array({130, 168, 102, 105, 120, 97, 114, 114, 97, 121, 153, 1, 2, 3, 4, 5, 6, 7, 8, 9, 167, 97, 114, 114, 97, 121, 49, 54, 220, 0, 32, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32})
	},
	maps = {
		lua_table = {
			fixmap = {
				["1"] = 1, ["2"] = 2, ["4"] = 4, ["8"] = 8
			},
			map16 = {
				["1"] = 1, ["2"] = 2, ["4"] = 4, ["8"] = 8, ["16"] = 16, ["32"] = 32, ["64"] = 64, ["128"] = 128, ["256"] = 256, ["512"] = 512, 
				["1024"] = 1024, ["2048"] = 2048, ["4096"] = 4096, ["8192"] = 8192, ["16384"] = 16384, ["32768"] = 32768, ["65536"] = 65536
			}
		},
		msgpack_buffer = create_buffer_from_byte_array({130, 166, 102, 105, 120, 109, 97, 112, 132, 161, 49, 1, 161, 50, 2, 161, 52, 4, 161, 56, 8, 165, 109, 97, 112, 49, 54, 222, 0, 17, 161, 49, 1, 161, 50, 2, 161, 52, 4, 161, 56, 8, 162, 49, 54, 16, 162, 51, 50, 32, 162, 54, 52, 64, 163, 49, 50, 56, 204, 128, 163, 50, 53, 54, 205, 1, 0, 163, 53, 49, 50, 205, 2, 0, 164, 49, 48, 50, 52, 205, 4, 0, 164, 50, 48, 52, 56, 205, 8, 0, 164, 52, 48, 57, 54, 205, 16, 0, 164, 56, 49, 57, 50, 205, 32, 0, 165, 49, 54, 51, 56, 52, 205, 64, 0, 165, 51, 50, 55, 54, 56, 205, 128, 0, 165, 54, 53, 53, 51, 54, 206, 0, 1, 0, 0})
	}
}

local function test_msgpack_simpletest()
	assert(msgpack.decode(msgpack.encode({ payload = "helloworld" })).payload == "helloworld")
end

local function test_msgpack_boolean()
	assert(compare_table(test_data.boolean.lua_table, msgpack.decode(test_data.boolean.msgpack_buffer)) == true)
	assert(compare_table(test_data.boolean.lua_table, msgpack.decode(msgpack.encode(test_data.boolean.lua_table))) == true)
end

local function test_msgpack_integer()
	assert(compare_table(test_data.integer.lua_table, msgpack.decode(test_data.integer.msgpack_buffer)) == true)
	assert(compare_table(test_data.integer.lua_table, msgpack.decode(msgpack.encode(test_data.integer.lua_table))) == true)
end

local function test_msgpack_strings()
	assert(compare_table(test_data.strings.lua_table, msgpack.decode(test_data.strings.msgpack_buffer)) == true)
	assert(compare_table(test_data.strings.lua_table, msgpack.decode(msgpack.encode(test_data.strings.lua_table))) == true)
end

local function test_msgpack_array()
	assert(compare_table(test_data.arrays.lua_table, msgpack.decode(test_data.arrays.msgpack_buffer)) == true)
	assert(compare_table(test_data.arrays.lua_table, msgpack.decode(msgpack.encode(test_data.arrays.lua_table))) == true)
end

local function test_msgpack_map()
	assert(compare_table(test_data.maps.lua_table, msgpack.decode(test_data.maps.msgpack_buffer)) == true)
	assert(compare_table(test_data.maps.lua_table, msgpack.decode(msgpack.encode(test_data.maps.lua_table))) == true)
end

local msgpack_test_suite = function()
	test_msgpack_simpletest()
	test_msgpack_boolean()
	test_msgpack_integer()
	test_msgpack_strings()
	test_msgpack_array()
	test_msgpack_map()
	print("[OMGS/TESTS] test suite for msgpack: passed")
end

return msgpack_test_suite