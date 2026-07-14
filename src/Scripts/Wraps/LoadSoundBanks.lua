-- Loads every registered FMOD sound bank when entering the Crossroads
local function loadRegisteredBanks()
	for _, bank in ipairs(mod.RegisteredSoundBanks) do
		rom.audio.load_bank(bank.Path)
	end
end

-- This must be the same as the wrap for HubPostBountyLoad and HubPostDreamLoad
modutil.mod.Path.Wrap("DeathAreaRoomTransition", function(base, source, args)
	loadRegisteredBanks()
	return base(source, args)
end)

-- If returning from a Chaos Trial, this will be called instead of DeathAreaRoomTransition
modutil.mod.Path.Wrap("HubPostBountyLoad", function(base, source, args)
	loadRegisteredBanks()
	return base(source, args)
end)

-- If returning from a Dream Dive, this will be called instead of DeathAreaRoomTransition
modutil.mod.Path.Wrap("HubPostDreamLoad", function(base, source, args)
	loadRegisteredBanks()
	return base(source, args)
end)
