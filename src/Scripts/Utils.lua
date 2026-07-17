-- Shared helpers and registration state for the Music Maker API

mod.ValidLanguageCodes = {
	de = true,
	el = true,
	en = true,
	es = true,
	fr = true,
	it = true,
	ja = true,
	ko = true,
	pl = true,
	["pt-BR"] = true,
	ru = true,
	tr = true,
	uk = true,
	["zh-CN"] = true,
	["zh-TW"] = true,
}

-- Maps songIds to the full song data table passed to RegisterSong
mod.RegisteredSongs = {}
-- Ordered list of registered songIds, so insertion into the Music Maker list is deterministic
mod.RegisteredSongOrder = {}
-- Set of registered songIds, for a fast "is this one of our songs" check in the audio handler
mod.RegisteredSongNames = {}
-- Maps songIds to the song (vanilla or modded) it is a version of
mod.SongAnchor = {}
-- Is true for a songName if at least one registered song is a version of it
mod.IsAnchor = {}
-- Maps a songName to its loop length in seconds
mod.AnchorLoopLength = {}
-- Maps a group anchor songName to a set of stem names kept continuous (switched quickly, not crossfaded) when switching between its versions
mod.AnchorContinuousStems = {}
-- Array of song text entries, for the per-language HelpText sjson hooks
mod.AddedSongSjsonTextData = {}
-- Array of { Path = absolutePath } sound banks to load when entering the Crossroads
mod.RegisteredSoundBanks = {}
-- Maps FMOD event TrackNames to a set of stem names any registered version activates on that event
-- Used to deactivate every stem not active in the version currently playing
mod.EventStems = {}
-- Set of songIds whose owning mod asked (usually via a config flag) to unlock them immediately
mod.SongsToUnlockImmediately = {}

---Logs a message at the specified log level with colour coding.
---@param t any The message to log.
---@param level number|nil The log level. 0 = Off, 1 = Errors, 2 = Warnings, 3 = Info, 4 = Debug. nil omits the level display.
function mod.LogMessage(t, level)
	if level == 1 then
		-- Using rom.log.error would actually throw an error
		print(string.format("\27[31m[ERROR] %s\27[0m", tostring(t)))
	elseif level == 2 then
		rom.log.warning(tostring(t))
	elseif level == 3 then
		rom.log.info(tostring(t))
	elseif level == 4 then
		rom.log.debug(tostring(t))
	end
end

---Prints a message to the console at the specified log level.
---@param t any The message to print.
---@param level number|nil The verbosity level required to print the message. 0 = Off/Always printed, 1 = Errors, 2 = Warnings, 3 = Info, 4 = Debug
function mod.DebugPrint(t, level)
	level = level or 0
	if config.logLevel >= level then
		if type(t) == "table" then
			mod.PrintTable(t, nil, nil)
		else
			mod.LogMessage(t, level)
		end
	end
end

---Prints a table (or any other printable entity) up to a certain depth.
---@param t any The table to print, can also be another printable entity.
---@param maxDepth number|nil The maximum depth to print the table to, after which it is cut off with ...
---@param indent number|nil The current indentation level.
function mod.PrintTable(t, maxDepth, indent)
	if type(t) ~= "table" then
		print(t)
		return
	end

	indent = indent or 0
	maxDepth = maxDepth or 20
	if indent > maxDepth then
		print(string.rep("  ", indent) .. "...")
		return
	end

	local formatting = string.rep("  ", indent)
	for k, v in pairs(t) do
		if type(v) == "table" then
			print(formatting .. k .. ":")
			mod.PrintTable(v, maxDepth, indent + 1)
		else
			print(formatting .. k .. ": " .. tostring(v))
		end
	end
end

---Logs a warning about an incorrect type in the passed songData.
---@param fieldName string The name of the field with the incorrect type.
---@param expectedType string The expected type of the field.
---@param actualType string The actual type of the field.
---@param songId string The ID of the song data where the incorrect type was found.
function mod.WarnIncorrectType(fieldName, expectedType, actualType, songId)
	mod.DebugPrint("[MusicMakerAPI] Warning: Field '" .. fieldName .. "' has incorrect type '" ..
		actualType .. "' (expected '" .. expectedType ..
		"') in song data: " .. tostring(songId), 2)
end
