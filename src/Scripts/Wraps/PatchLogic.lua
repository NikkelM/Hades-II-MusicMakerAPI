modutil.mod.Path.Wrap("DoPatches", function(base)
	if game.GameState ~= nil then
		game.GameState.ModsNikkelMMusicMakerAPI_UnlockedSongs = game.GameState.ModsNikkelMMusicMakerAPI_UnlockedSongs or {}

		-- Adopt ownership recorded by older API versions (which put modded songs into the vanilla list) or by AddWorldUpgrade, so upgrading the API keeps everything the player already unlocked
		for songId, _ in pairs(mod.RegisteredSongNames) do
			if game.Contains(game.GameState.UnlockedMusicPlayerSongs, songId) or game.GameState.WorldUpgradesAdded[songId] then
				mod.AddUnlockedModdedSong(songId)
			end
		end
	end

	base()

	-- Runs after vanilla DoPatches (which re-adds owned songs from the screen list when GameState.UnlockedMusicPlayerSongs starts empty), so any registered modded song vanilla put back into the shuffle list is removed here.
	if game.GameState ~= nil then
		for i = #game.GameState.UnlockedMusicPlayerSongs, 1, -1 do
			if mod.RegisteredSongNames[game.GameState.UnlockedMusicPlayerSongs[i]] then
				table.remove(game.GameState.UnlockedMusicPlayerSongs, i)
			end
		end
	end
end)
