-- Called after all other mods have loaded - executes Sjson hooks for all newly added songs here
-- #region HelpText
local textOrder = { "Id", "DisplayName", "Description" }

for language, _ in pairs(mod.ValidLanguageCodes) do
	local helpTextFile = rom.path.combine(rom.paths.Content(),
		"Game/Text/" .. language .. "/HelpText." .. language .. ".sjson")

	sjson.hook(helpTextFile, function(data)
		for _, song in ipairs(mod.AddedSongSjsonTextData) do
			local entry = {
				Id = song.Id,
				DisplayName = song.Name[language] or song.Name.en or song.Id,
				Description = song.Description[language] or song.Description.en or "",
			}
			table.insert(data.Texts, sjson.to_object(entry, textOrder))
		end
	end)
end
-- #endregion
