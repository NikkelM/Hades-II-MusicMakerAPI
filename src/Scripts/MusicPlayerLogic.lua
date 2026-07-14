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
		game.AddWorldUpgrade(songId)
		if not game.Contains(game.GameState.UnlockedMusicPlayerSongs, songId) then
			table.insert(game.GameState.UnlockedMusicPlayerSongs, songId)
		end
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

-- Retroactively repair songs that were unlocked via AddWorldUpgrade but never added to UnlockedMusicPlayerSongs (e.g. from an older version of a consumer mod before this was fixed).
modutil.mod.Path.Wrap("DoPatches", function(base)
	if game.GameState ~= nil and game.GameState.WorldUpgradesAdded ~= nil then
		for songId, _ in pairs(mod.RegisteredSongNames) do
			if game.GameState.WorldUpgradesAdded[songId] == true
					and not game.Contains(game.GameState.UnlockedMusicPlayerSongs, songId) then
				table.insert(game.GameState.UnlockedMusicPlayerSongs, songId)
			end
		end
	end

	base()
end)
