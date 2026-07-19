-- Handles playback for all Music Maker songs registered through this API: per-version stem and parameter control, plus position-preserving switching (crossfade or live morph) between versions

-- Crossfade length (seconds) used when switching between two versions of the same song
local crossFadeDuration = 0.3

-- Switch length (seconds) for the continuous backing stems: short so the shared backing stays seamless across a position-aligned switch instead of fading out and back in
local backingSwitchDuration = 0.05

-- The version group a song belongs to, identified by its anchor song. Returns nil if not grouped
local function songGroupOf(songName)
	if songName == nil then
		return nil
	end

	if mod.SongAnchor[songName] == nil and not mod.IsAnchor[songName] then
		return nil
	end

	local seen = {}
	while mod.SongAnchor[songName] ~= nil and not seen[songName] do
		seen[songName] = true
		songName = mod.SongAnchor[songName]
	end

	return songName
end

-- The loop length (seconds) registered for a version group (keyed by its anchor song), or nil
local function groupLoopLength(group)
	if group == nil then
		return nil
	end

	return mod.AnchorLoopLength[group]
end

-- Current playback position (seconds) of the tracked grouped song, from the game clock, wrapped into the group's loop length. Returns nil if untracked
local function currentTrackedPosition()
	local startTime = game.AudioState.MusicMakerAPI_PlaybackPositionZeroTime
	local group = game.AudioState.MusicMakerAPI_CurrentGroup
	if startTime == nil or group == nil then
		return nil
	end

	local position = game._worldTimeUnmodified - startTime
	local loopLength = groupLoopLength(group)
	if loopLength ~= nil and loopLength > 0 then
		position = position % loopLength
	end
	if position < 0 then
		position = 0
	end

	return position
end

-- Applies a song's stems, ambient params, and Section to a playing track: active stems fade to 1 and every other stem used on the event fades to 0, so switching versions only changes the audible layers
local function applyParams(soundId, songData, duration)
	local stems = songData.MusicMakerAPI_Stems
	if stems ~= nil then
		local activeSet = {}
		for _, stem in ipairs(stems) do
			activeSet[stem] = true
		end
		local known = mod.EventStems[songData.TrackName]
		if known ~= nil then
			for stem, _ in pairs(known) do
				SetSoundCueValue({ Id = soundId, Names = { stem }, Value = activeSet[stem] and 1 or 0, Duration = duration })
			end
		end
	end

	local ambientParams = songData.MusicMakerAPI_AmbientParams
	if ambientParams ~= nil then
		for param, value in pairs(ambientParams) do
			SetSoundCueValue({ Id = soundId, Names = { param }, Value = value, Duration = duration })
		end
	end

	local section = songData.MusicMakerAPI_MusicSection
	if section ~= nil then
		SetSoundCueValue({ Id = soundId, Names = { "Section" }, Value = section })
	end
end

-- The set of continuous (non-crossfaded) stem names for a group
local function continuousStemsFor(group)
	if group ~= nil and mod.AnchorContinuousStems[group] ~= nil then
		return mod.AnchorContinuousStems[group]
	end

	return { Drums = true, Bass = true, Guitar = true }
end

-- Applies a version's stems while crossfading: continuous backing stems switch instantly (the incoming instance is faded up quickly as a whole), every other stem fades in from silent over crossFadeDuration, so only the differing layers (e.g. vocals) crossfade between versions
local function applyParamsCrossfade(soundId, songData, continuousStems)
	local stems = songData.MusicMakerAPI_Stems
	if stems ~= nil then
		local activeSet = {}
		for _, stem in ipairs(stems) do
			activeSet[stem] = true
		end

		local known = mod.EventStems[songData.TrackName]
		if known ~= nil then
			for stem, _ in pairs(known) do
				local target = activeSet[stem] and 1 or 0
				if continuousStems[stem] then
					SetSoundCueValue({ Id = soundId, Names = { stem }, Value = target })
				else
					SetSoundCueValue({ Id = soundId, Names = { stem }, Value = 0 })
					SetSoundCueValue({ Id = soundId, Names = { stem }, Value = target, Duration = crossFadeDuration })
				end
			end
		end
	end

	local ambientParams = songData.MusicMakerAPI_AmbientParams
	if ambientParams ~= nil then
		for param, value in pairs(ambientParams) do
			SetSoundCueValue({ Id = soundId, Names = { param }, Value = value })
		end
	end

	local section = songData.MusicMakerAPI_MusicSection
	if section ~= nil then
		SetSoundCueValue({ Id = soundId, Names = { "Section" }, Value = section })
	end
end

-- Fades out the outgoing version: continuous backing stems are cut quickly so they do not double with the incoming backing, while the remaining stems (e.g. vocals) fade out as the instance is stopped over crossFadeDuration
local function crossfadeOutPrevious(previousId, continuousStems)
	if previousId == nil then
		return
	end

	for stem, _ in pairs(continuousStems) do
		SetSoundCueValue({ Id = previousId, Names = { stem }, Value = 0, Duration = backingSwitchDuration })
	end
	StopSound({ Id = previousId, Duration = crossFadeDuration })
end

local purchaseInProgress = false

modutil.mod.Path.Wrap("MusicianMusic", function(base, trackName, args)
	local songName = game.GameState.MusicPlayerSongName
	local newGroup = songGroupOf(songName)

	local purchaseSwitch = purchaseInProgress
	purchaseInProgress = false
	local inMusicPlayerAction = game.ActiveScreens.MusicPlayer or purchaseSwitch

	-- Only run our custom logic for modded tracks
	if mod.RegisteredSongNames[songName] then
		args = args or {}
		local songData = game.WorldUpgradeData[songName]
		local offset = songData.MusicMakerAPI_TrackOffset

		local previousId = game.AudioState.AmbientMusicId
		local previousGroup = game.AudioState.MusicMakerAPI_CurrentGroup

		-- Carry the seek position only when the player bought a new song, otherwise (e.g. save load) start fresh
		local sameGroupSwitch = previousId ~= nil and previousGroup ~= nil and previousGroup == newGroup and
				inMusicPlayerAction

		-- Same underlying FMOD event (shared TrackName): stems and ambient params can morph in place, but a Section change only takes effect when the track is re-triggered, so only morph when the Section is unchanged
		if previousId ~= nil and trackName == game.AudioState.AmbientTrackName then
			local currentSongData = game.WorldUpgradeData[game.AudioState.MusicMakerAPI_CurrentSongName]
			local currentSection = currentSongData ~= nil and currentSongData.MusicMakerAPI_MusicSection or nil
			if songData.MusicMakerAPI_MusicSection == currentSection then
				game.AudioState.MusicMakerAPI_CurrentSongName = songName
				game.AudioState.MusicMakerAPI_CurrentGroup = newGroup
				game.UpdateAmbientMusicParameters({ Params = {} })
				applyParams(previousId, songData, 1.0)
				return
			end
		end

		local carriedPosition = sameGroupSwitch and currentTrackedPosition() or nil

		if carriedPosition ~= nil then
			-- Same song, different event: crossfade at the carried position so the switch feels immediate
			local newId = PlaySound({ Name = songData.TrackName, Id = game.CurrentHubRoom.AmbientMusicSourceId })
			SetVolume({ Id = newId, Value = 0, Duration = 0 })
			SetSoundPosition({ Id = newId, Position = carriedPosition + (offset or 0) })
			SetSoundSource({ Id = newId, DestinationId = game.CurrentHubRoom.AmbientMusicSourceId })
			if songData.MusicMakerAPI_Stems ~= nil then
				-- Keep the shared backing continuous and only crossfade the differing stems (e.g. vocals) between versions
				local continuous = continuousStemsFor(newGroup)
				applyParamsCrossfade(newId, songData, continuous)
				SetVolume({ Id = newId, Value = game.CurrentHubRoom.AmbientMusicVolume, Duration = backingSwitchDuration })
				crossfadeOutPrevious(previousId, continuous)
			else
				-- A pre-mixed version with no stems: crossfade the whole instance
				applyParams(newId, songData, nil)
				SetVolume({ Id = newId, Value = game.CurrentHubRoom.AmbientMusicVolume, Duration = crossFadeDuration })
				if previousId ~= nil then
					StopSound({ Id = previousId, Duration = crossFadeDuration })
				end
			end
			game.AudioState.AmbientMusicId = newId
			game.AudioState.AmbientTrackName = trackName
		else
			-- Different song (or first play): quick cut the old track, then start fresh after a short gap to avoid pops
			if previousId ~= nil then
				StopSound({ Id = previousId, Duration = 0.25 })
				game.AudioState.AmbientMusicId = nil
			end
			game.wait(0.3)
			game.AudioState.AmbientMusicId = PlaySound({
				Name = songData.TrackName,
				Id = game.CurrentHubRoom.AmbientMusicSourceId
			})
			game.AudioState.AmbientTrackName = trackName
			SetVolume({ Id = game.AudioState.AmbientMusicId, Value = 0 })
			local startOffset = offset or 0
			if startOffset ~= 0 then
				SetSoundPosition({ Id = game.AudioState.AmbientMusicId, Position = startOffset })
			end
			game.AudioState.MusicMakerAPI_PlaybackPositionZeroTime = game._worldTimeUnmodified
			game.UpdateAmbientMusicParameters({ Params = {} })
			applyParams(game.AudioState.AmbientMusicId, songData, 1.0)
		end
		game.AudioState.MusicMakerAPI_CurrentSongName = songName
		game.AudioState.MusicMakerAPI_CurrentGroup = newGroup
	elseif newGroup ~= nil then
		-- A grouped vanilla song: keep tracking its position so switching to or from a modded version stays seamless
		local songData = game.WorldUpgradeData[songName]
		local isGroupedVanilla = songData ~= nil and trackName == songData.TrackName
		if not isGroupedVanilla then
			base(trackName, args)
			return
		end

		local previousId = game.AudioState.AmbientMusicId
		local previousGroup = game.AudioState.MusicMakerAPI_CurrentGroup

		-- Base no-ops if this exact track is already playing, keep our tracking intact
		if previousId ~= nil and trackName == game.AudioState.AmbientTrackName then
			base(trackName, args)
			game.AudioState.MusicMakerAPI_CurrentSongName = songName
			game.AudioState.MusicMakerAPI_CurrentGroup = newGroup
			return
		end


		-- Carry the seek position only when the player bought a new song, otherwise (e.g. save load) start fresh
		local sameGroupSwitch = previousId ~= nil and previousGroup ~= nil and previousGroup == newGroup and
				inMusicPlayerAction
		local carriedPosition = sameGroupSwitch and currentTrackedPosition() or nil

		if carriedPosition ~= nil then
			-- Crossfade to the vanilla version at the carried position, mirroring the modded path
			local continuous = continuousStemsFor(newGroup)
			local newId = PlaySound({ Name = trackName, Id = game.CurrentHubRoom.AmbientMusicSourceId })
			SetVolume({ Id = newId, Value = 0, Duration = 0 })
			SetSoundPosition({ Id = newId, Position = carriedPosition })
			SetSoundSource({ Id = newId, DestinationId = game.CurrentHubRoom.AmbientMusicSourceId })
			local ambientParams = game.CurrentHubRoom.AmbientMusicParams
			if ambientParams ~= nil then
				for param, value in pairs(ambientParams) do
					SetSoundCueValue({ Id = newId, Name = param, Value = value })
				end
			end
			-- Bring the vanilla backing up quickly so it stays continuous, and let the outgoing version's non-backing stems (e.g. vocals) fade out
			SetVolume({ Id = newId, Value = game.CurrentHubRoom.AmbientMusicVolume, Duration = backingSwitchDuration })
			crossfadeOutPrevious(previousId, continuous)
			game.AudioState.AmbientMusicId = newId
			game.AudioState.AmbientTrackName = trackName
		else
			base(trackName, args)
			game.AudioState.MusicMakerAPI_PlaybackPositionZeroTime = game._worldTimeUnmodified
		end
		game.AudioState.MusicMakerAPI_CurrentSongName = songName
		game.AudioState.MusicMakerAPI_CurrentGroup = newGroup
	else
		base(trackName, args)
		game.AudioState.MusicMakerAPI_CurrentGroup = nil
		game.AudioState.MusicMakerAPI_CurrentSongName = nil
		game.AudioState.MusicMakerAPI_PlaybackPositionZeroTime = nil
	end
end)

-- On a same-group version switch, put Mel's music-choice request lines on cooldown so the game naturally skips her quip over the fade
local function suppressVersionSwitchQuip(newSong, previousSong)
	if newSong ~= nil and previousSong ~= nil and newSong ~= previousSong then
		local newGroup = songGroupOf(newSong)
		if newGroup ~= nil and newGroup == songGroupOf(previousSong) then
			game.TriggerCooldown("MelMusicPlayerRequestSpeech")
		end
	end
end

modutil.mod.Path.Wrap("SelectMusicPlayerItem", function(base, screen, button)
	local newSong = button ~= nil and button.Data ~= nil and button.Data.Name or nil
	suppressVersionSwitchQuip(newSong, game.GameState.MusicPlayerSongName)

	base(screen, button)
end)

modutil.mod.Path.Wrap("HandleMusicPlayerPurchase", function(base, screen, button)
	local newSong = button ~= nil and button.Data ~= nil and button.Data.Name or nil
	suppressVersionSwitchQuip(newSong, game.GameState.MusicPlayerSongName)

	base(screen, button)
end)

-- To track if the seek position should be carried forward, as the new track starts while the screen is closed
modutil.mod.Path.Wrap("DoMusicPlayerPurchase", function(base, screen, button)
	purchaseInProgress = true
	base(screen, button)
end)

modutil.mod.Path.Wrap("RestoreMusicianMusic", function(base, source, args)
	-- Remove any modded songs that no longer exist from the playlist
	if game.GameState.MusicPlayerPlaylist ~= nil then
		for i = #game.GameState.MusicPlayerPlaylist, 1, -1 do
			if game.WorldUpgradeData[game.GameState.MusicPlayerPlaylist[i]] == nil then
				table.remove(game.GameState.MusicPlayerPlaylist, i)
			end
		end
	end

	-- If the selected song is gone, continue from a still-valid playlist entry, otherwise clear it so the game's own guard safely skips playback
	if game.GameState.MusicPlayerSongName ~= nil and game.WorldUpgradeData[game.GameState.MusicPlayerSongName] == nil then
		if game.GameState.MusicPlayerPlaylist ~= nil and game.GameState.MusicPlayerPlaylist[1] ~= nil then
			game.GameState.MusicPlayerSongName = game.GameState.MusicPlayerPlaylist[1]
		else
			game.GameState.MusicPlayerSongName = nil
		end
	end

	return base(source, args)
end)
