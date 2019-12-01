#!/usr/bin/env lua5.1

local http = require "socket.http"
local url = require "socket.url"
local json = require "dkjson"
local posix = require "posix"

http.USERAGENT = "CracowTTSSLuaInterface 0.0.1 (xterm compatible; Linux x86_64; render=ttssJsonParser)"
local blink = true

local function getStopNumber(stop)
	local body, code, header = http.request("http://www.ttss.krakow.pl/internetservice/services/lookup/autocomplete/json?query="..url.escape(stop))
	if not body then
		print(code .. ": while trying to get stop number")
		return
	end
	local obj, pos, err = json.decode(body)
	if not obj then
		print(err .. ": while decoding data")
		return
	end
	if #obj == 0 then
		print("No results for given name.")
		return
	end
	if obj[1].count > 1 then
		for i,v in ipairs(obj) do
			if i ~= 1 then
				print(("%5s\t%s"):format(v.id, v.name:gsub("&oacute;", "ó")))
			end
		end
		return
	else
		return obj[2].id
	end
end

local function getMPKData(stop)
	local body, code, header = http.request("http://www.ttss.krakow.pl/internetservice/services/passageInfo/stopPassages/stop?stop="..stop)
	if not body then
		print(code .. ": while trying to get MPK data")
		return
	end
	local obj, pos, err = json.decode(body)
	if not obj then
		print(err .. ": while decoding data")
		return
	end
	return obj
end

local function departs(time, status)
	if status == "STOPPING" or time == "0 Min" then
		if blink then return ">>>>" else return "" end
	else
		return time
	end
end

local function utf8_len(str)
	local _, count = string.gsub(str, "[^\128-\193]", "")
	return count
end

local function center(text, width, fill)
	fill = fill or " "
	local pad = math.floor((width-utf8_len(text))/2)
	local out = ""
	for i=1, pad do
		out = out .. fill
	end
	out = out .. text
	while utf8_len(out) < width do
		out = out .. fill
	end
	return out
end

local function prettyPrint(data)
	print(" ____________________________________")
	print("|                                    |")
	print("|" .. center(data.stopShortName .. " " .. data.stopName, 36) .. "|")
	print("|____________________________________|")
	if #data.actual == 0 then
		print("\n" .. center("Przerwa w kursowaniu", 38) .. "\n" .. center("komunikacji miejskiej", 38))
	else
		for _,v in ipairs(data.actual) do
			print(("%3s\t%-20s\t%5s"):format(v.patternText, v.direction, departs(v.mixedTime, v.status)))
		end
	end
end

local function status(data) -- status: PLANNING PREDICTED STOPPING
	for _,v in ipairs(data.actual) do
		print(v.patternText .. "  " .. v.mixedTime .. "  " .. v.status)
	end
end


--------------------------------------------------------------------------------
local _arg_ = ""
if #arg > 1 then
	for _,v in ipairs(arg) do
		_arg_ = _arg_ .. v .. " "
	end
else
	_arg_ = arg[1]
end

local stop = tonumber(arg[1]) or getStopNumber(_arg_)
if stop then
	while true do
		data = getMPKData(stop)
		if not data then
			print("Error: no data!")
			break
		end
		for i=0, 20 do
			os.execute("clear")
			prettyPrint(data)
			blink = not blink
			posix.sleep(1)
		end
	end
end