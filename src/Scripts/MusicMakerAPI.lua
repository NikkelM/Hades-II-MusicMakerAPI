---@meta NikkelM-Music_Maker_API

---Registers a new song to be added to the Music Maker in the Crossroads.
---@param songData MusicMakerSongData The input data for the new song. Must be a valid MusicMakerSongData table.
---@return boolean successfullyRegistered True if the song was successfully registered, false otherwise.
public.RegisterSong = function(songData)
	-- #region Basic Input Validation
	-- Ensure required fields exist with correct types
	local requiredFields = {
		Id = "string",
		TrackName = "string",
		Name = "table",
		Description = "table",
	}
	for fieldName, fieldType in pairs(requiredFields) do
		if songData[fieldName] == nil then
			mod.DebugPrint("[MusicMakerAPI] Error: Missing required field '" ..
				fieldName .. "' in song data, cannot register song: " .. tostring(songData.Id or "Unknown"), 1)
			return false
		elseif type(songData[fieldName]) ~= fieldType then
			mod.DebugPrint("[MusicMakerAPI] Error: Field '" .. fieldName .. "' has incorrect type '" ..
				type(songData[fieldName]) .. "' (expected '" .. fieldType ..
				"') in song data, cannot register song: " .. tostring(songData.Id or "Unknown"), 1)
			return false
		end
	end

	-- Ensure no song with this ID already exists
	if mod.RegisteredSongNames[songData.Id] or game.WorldUpgradeData[songData.Id] ~= nil then
		mod.DebugPrint("[MusicMakerAPI] Error: A song with ID '" .. songData.Id ..
			"' already exists, cannot register duplicate song. Make sure to prefix your song with your \"_PLUGIN.guid\"!",
			1)
		return false
	end

	-- Ensure the Name and Description tables only contain valid language keys, and contain at least the english entry
	local hasEnglishName = false
	local hasEnglishDescription = false
	for _, textField in ipairs({ "Name", "Description" }) do
		for langCode, _ in pairs(songData[textField]) do
			if langCode == "en" then
				if textField == "Name" then
					hasEnglishName = true
				else
					hasEnglishDescription = true
				end
			end
			if not mod.ValidLanguageCodes[langCode] then
				mod.DebugPrint("[MusicMakerAPI] Warning: Invalid language code '" .. tostring(langCode) ..
					"' in field '" .. textField .. "' of song data: " .. tostring(songData.Id or "Unknown"), 2)
			end
		end
	end
	if not hasEnglishName then
		mod.DebugPrint("[MusicMakerAPI] Warning: Missing default English ('en') entry in Name field of song data: " ..
			tostring(songData.Id or "Unknown"), 2)
	end
	if not hasEnglishDescription then
		mod.DebugPrint(
			"[MusicMakerAPI] Warning: Missing default English ('en') entry in Description field of song data: " ..
			tostring(songData.Id or "Unknown"), 2)
	end
	-- #endregion

	-- #region Name (Id), TrackName
	local newSong = {
		-- This is NOT the DisplayName field, but the internal ID
		Name = songData.Id,
		TrackName = songData.TrackName,
	}
	-- #endregion

	-- #region InheritFrom
	if songData.InheritFrom ~= nil and type(songData.InheritFrom) == "table" then
		newSong.InheritFrom = songData.InheritFrom
	else
		newSong.InheritFrom = { "DefaultSongItem" }
		if songData.InheritFrom ~= nil then
			mod.WarnIncorrectType("InheritFrom", "table", type(songData.InheritFrom), songData.Id)
		end
	end
	-- #endregion

	-- #region InsertAfter
	-- Where to place the song in the Music Maker list is applied later, in MusicPlayerLogic
	if songData.InsertAfter ~= nil and type(songData.InsertAfter) ~= "string" then
		mod.WarnIncorrectType("InsertAfter", "string", type(songData.InsertAfter), songData.Id)
		songData.InsertAfter = nil
	end
	-- #endregion

	-- #region Cost
	if songData.Cost ~= nil and type(songData.Cost) == "table" then
		newSong.Cost = songData.Cost
	elseif songData.Cost ~= nil then
		mod.WarnIncorrectType("Cost", "table", type(songData.Cost), songData.Id)
	end
	-- #endregion

	-- #region GameStateRequirements
	if songData.GameStateRequirements ~= nil and type(songData.GameStateRequirements) == "table" then
		newSong.GameStateRequirements = songData.GameStateRequirements
	elseif songData.GameStateRequirements ~= nil then
		mod.WarnIncorrectType("GameStateRequirements", "table", type(songData.GameStateRequirements), songData.Id)
	end
	-- #endregion

	-- #region Rocking
	if songData.Rocking ~= nil and type(songData.Rocking) == "boolean" then
		newSong.Rocking = songData.Rocking
	elseif songData.Rocking ~= nil then
		mod.WarnIncorrectType("Rocking", "boolean", type(songData.Rocking), songData.Id)
	end
	-- #endregion

	-- #region Stems
	-- The stems this version activates. Every other stem used by any version of the event is deactivated at play time
	if songData.Stems ~= nil and type(songData.Stems) == "table" then
		local stemsAreStrings = true
		for _, stem in ipairs(songData.Stems) do
			if type(stem) ~= "string" then
				stemsAreStrings = false
				break
			end
		end
		if stemsAreStrings then
			newSong.MusicMakerAPI_Stems = songData.Stems
			-- Record which stems this song activates on its event, so the audio handler knows the full set of stems used across all versions of the event and can deactivate the ones that are not active
			mod.EventStems[songData.TrackName] = mod.EventStems[songData.TrackName] or {}
			for _, stem in ipairs(songData.Stems) do
				mod.EventStems[songData.TrackName][stem] = true
			end
		else
			mod.DebugPrint("[MusicMakerAPI] Warning: Stems must be a list of strings, ignoring Stems for song: " ..
				tostring(songData.Id), 2)
		end
	elseif songData.Stems ~= nil then
		mod.WarnIncorrectType("Stems", "table", type(songData.Stems), songData.Id)
	end
	-- #endregion

	-- #region AmbientParams
	-- Extra FMOD cue values applied to the AudioState.AmbientMusicId alongside the stems
	if songData.AmbientParams ~= nil and type(songData.AmbientParams) == "table" then
		local paramsAreValid = true
		for param, value in pairs(songData.AmbientParams) do
			if type(param) ~= "string" or type(value) ~= "number" then
				paramsAreValid = false
				break
			end
		end
		if paramsAreValid then
			newSong.MusicMakerAPI_AmbientParams = songData.AmbientParams
		else
			mod.DebugPrint(
				"[MusicMakerAPI] Warning: AmbientParams must map strings to numbers, ignoring AmbientParams for song: " ..
				tostring(songData.Id), 2)
		end
	elseif songData.AmbientParams ~= nil then
		mod.WarnIncorrectType("AmbientParams", "table", type(songData.AmbientParams), songData.Id)
	end
	-- #endregion

	-- #region MusicSection
	if songData.MusicSection ~= nil and type(songData.MusicSection) == "number" then
		newSong.MusicMakerAPI_MusicSection = songData.MusicSection
	elseif songData.MusicSection ~= nil then
		mod.WarnIncorrectType("MusicSection", "number", type(songData.MusicSection), songData.Id)
	end
	-- #endregion

	-- #region TrackOffset
	if songData.TrackOffset ~= nil and type(songData.TrackOffset) == "number" then
		newSong.MusicMakerAPI_TrackOffset = songData.TrackOffset
	elseif songData.TrackOffset ~= nil then
		mod.WarnIncorrectType("TrackOffset", "number", type(songData.TrackOffset), songData.Id)
	end
	-- #endregion

	-- Apply data inheritance and register the world upgrade for this song
	game.ProcessDataInheritance(newSong, game.WorldUpgradeData)
	game.WorldUpgradeData[songData.Id] = newSong

	-- #region Registration Tracking
	mod.RegisteredSongs[songData.Id] = songData
	mod.RegisteredSongNames[songData.Id] = true
	table.insert(mod.RegisteredSongOrder, songData.Id)
	table.insert(mod.AddedSongSjsonTextData, songData)
	-- #endregion

	-- #region VersionOf (version/variant grouping)
	-- This song is a version of songData.VersionOf. Every song that is a version of the same anchor is automatically in one group, even across mods
	if songData.VersionOf ~= nil and type(songData.VersionOf) == "string" then
		mod.SongAnchor[songData.Id] = songData.VersionOf
		mod.IsAnchor[songData.VersionOf] = true
	elseif songData.VersionOf ~= nil then
		mod.WarnIncorrectType("VersionOf", "string", type(songData.VersionOf), songData.Id)
	end
	-- #endregion

	-- #region UnlockImmediately
	-- The owning mod may ask (usually via its own config flag) to force-unlock this song
	if songData.UnlockImmediately then
		mod.SongsToUnlockImmediately[songData.Id] = true
	end
	-- #endregion

	mod.DebugPrint("[MusicMakerAPI] Registered song: " .. songData.Id, 3)
	return true
end

---Registers the loop length for a version group, identified by its anchor song. Songs join a group automatically by declaring `VersionOf`.
---This call only supplies the anchor's loop length so a carried playback position can be wrapped.
---@param groupData MusicMakerVersionGroupData The input data for the version group. Must be a valid MusicMakerVersionGroupData table.
---@return boolean successfullyRegistered True if the version group was successfully registered, false otherwise.
public.RegisterVersionGroup = function(groupData)
	if type(groupData) ~= "table" or type(groupData.AnchorSong) ~= "string" then
		mod.DebugPrint("[MusicMakerAPI] Error: RegisterVersionGroup requires a table with a string AnchorSong.", 1)
		return false
	end

	if groupData.LoopLength ~= nil then
		mod.AnchorLoopLength[groupData.AnchorSong] = groupData.LoopLength
	end

	mod.DebugPrint("[MusicMakerAPI] Registered version group anchored on: " .. groupData.AnchorSong, 3)
	return true
end

---Registers an FMOD sound bank to load when entering the Crossroads.
---Place the .bank file in your mod's `plugins_data` folder.
---@param bankPath string Absolute path to the .bank, e.g. `rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, "Audio\\MyBank.bank")`.
---@return boolean successfullyRegistered True if the sound bank was registered, false otherwise.
public.RegisterSoundBank = function(bankPath)
	if type(bankPath) ~= "string" then
		mod.DebugPrint("[MusicMakerAPI] Error: RegisterSoundBank expects a string path, got " .. type(bankPath), 1)
		return false
	end

	for _, existing in ipairs(mod.RegisteredSoundBanks) do
		if existing.Path == bankPath then
			return true
		end
	end

	table.insert(mod.RegisteredSoundBanks, { Path = bankPath })
	mod.DebugPrint("[MusicMakerAPI] Registered sound bank: " .. bankPath, 3)

	return true
end
