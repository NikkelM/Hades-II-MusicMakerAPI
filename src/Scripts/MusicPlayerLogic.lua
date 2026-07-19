-- Sets up the Music Maker song list once all mods have registered their songs

-- Insert every registered song into the Music Maker list, after its InsertAfter entry.
-- Also works for songs that should be inserted after other modded songs.
local remaining = {}
for _, songId in ipairs(mod.RegisteredSongOrder) do
	table.insert(remaining, songId)
end

local madeProgress = true
while madeProgress and #remaining > 0 do
	madeProgress = false
	local stillRemaining = {}
	for _, songId in ipairs(remaining) do
		local insertAfter = mod.RegisteredSongs[songId].InsertAfter
		if insertAfter == nil then
			-- No explicit position given: append to the end of the list
			table.insert(game.ScreenData.MusicPlayer.Songs, songId)
			madeProgress = true
		else
			local insertIndex = nil
			for i, existingSong in ipairs(game.ScreenData.MusicPlayer.Songs) do
				if existingSong == insertAfter then
					insertIndex = i
					break
				end
			end
			if insertIndex then
				table.insert(game.ScreenData.MusicPlayer.Songs, insertIndex + 1, songId)
				madeProgress = true
			else
				table.insert(stillRemaining, songId)
			end
		end
	end
	remaining = stillRemaining
end

for _, songId in ipairs(remaining) do
	mod.DebugPrint("[MusicMakerAPI] Warning: Could not insert song '" .. songId ..
		"' - its InsertAfter entry '" .. tostring(mod.RegisteredSongs[songId].InsertAfter) ..
		"' was not found in the Music Maker list.", 2)
end

-- Unlock the songs whose owning mod asked for them to be unlocked immediately (usually via that mod's own config)
local function unlockFlaggedSongs()
	for songId, _ in pairs(mod.SongsToUnlockImmediately) do
		public.UnlockSong(songId)
	end
end

if next(mod.SongsToUnlockImmediately) ~= nil then
	-- These three hooks cover the different ways of returning to the Crossroads
	for _, hookName in ipairs({ "DeathAreaRoomTransition", "HubPostBountyLoad", "HubPostDreamLoad" }) do
		modutil.mod.Path.Wrap(hookName, function(base, source, args)
			unlockFlaggedSongs()
			return base(source, args)
		end)
	end
end

-- Include modded songs in the pool of unlocked songs
modutil.mod.Path.Wrap("MusicPlayerGetShuffledPlaylist", function(base, args)
	local originalUnlocked = game.ShallowCopyTable(game.GameState.UnlockedMusicPlayerSongs)
	for _, songId in ipairs(mod.GetAvailableModdedSongs()) do
		table.insert(game.GameState.UnlockedMusicPlayerSongs, songId)
	end

	local playlist = base(args)

	game.GameState.UnlockedMusicPlayerSongs = originalUnlocked

	return playlist
end)

-- Don't insert modded songs into the base unlocked pool, instead move to our own
modutil.mod.Path.Wrap("HandleMusicPlayerPurchase", function(base, screen, button)
	base(screen, button)

	local songId = button ~= nil and button.Data ~= nil and button.Data.Name or nil
	if songId ~= nil and mod.RegisteredSongNames[songId] then
		if game.Contains(game.GameState.UnlockedMusicPlayerSongs, songId) then
			for i = #game.GameState.UnlockedMusicPlayerSongs, 1, -1 do
				if game.GameState.UnlockedMusicPlayerSongs[i] == songId then
					table.remove(game.GameState.UnlockedMusicPlayerSongs, i)
					break
				end
			end
			mod.AddUnlockedModdedSong(songId)
		end
	end
end)
