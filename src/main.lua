---@meta _
-- grabbing our dependencies,
-- these funky (---@) comments are just there
--	 to help VS Code find the definitions of things

import = require

---@diagnostic disable-next-line: undefined-global
local mods = rom.mods

---@module 'SGG_Modding-ENVY-auto'
mods['SGG_Modding-ENVY'].auto()
-- ^ this gives us `public` and `import`, among others
--	and makes all globals we define private to this plugin.
---@diagnostic disable: lowercase-global

---@diagnostic disable-next-line: undefined-global
rom = rom
---@diagnostic disable-next-line: undefined-global
_PLUGIN = _PLUGIN

-- get definitions for the game's globals
---@module 'game'
game = rom.game
---@module 'game-import'
---@diagnostic disable-next-line: undefined-global
import_as_fallback(game)

---@module 'SGG_Modding-SJSON'
sjson = mods['SGG_Modding-SJSON']
---@module 'SGG_Modding-ModUtil'
modutil = mods['SGG_Modding-ModUtil']

---@module 'SGG_Modding-Chalk'
chalk = mods["SGG_Modding-Chalk"]
---@module 'SGG_Modding-ReLoad'
reload = mods['SGG_Modding-ReLoad']

---@module 'config'
config = chalk.auto 'config.lua'
-- ^ this updates our `.cfg` file in the config folder!
---@diagnostic disable-next-line: undefined-global
public.config = config -- so other mods can access our config

local function on_ready()
	mod = modutil.mod.Mod.Register(_PLUGIN.guid)
	if config.enabled == false then return end

	-- Everything that other mods might need
	import "Scripts/Utils.lua"
	import "Scripts/MusicMakerAPI.lua"
end

-- Loaded after all other mods, so that all new tracks have already been registered
local function on_ready_late()
	if config.enabled == false then return end

	import "Scripts/MusicPlayerLogic.lua"
	import "Scripts/Wraps/AudioLogic.lua"
	import "Scripts/Wraps/LoadSoundBanks.lua"
	import "Scripts/Wraps/PatchLogic.lua"
	import "Scripts/SjsonHooks.lua"
end

local function on_reload()
	if config.enabled == false then return end
end

local function on_reload_late()
	if config.enabled == false then return end
end

-- this allows us to limit certain functions to not be reloaded.
local loader = reload.auto_multiple()

-- this runs only when modutil and the game's lua is ready
modutil.once_loaded.game(function()
	loader.load("early", on_ready, on_reload)
end)

-- again but loaded later than other mods
mods.on_all_mods_loaded(function()
	modutil.once_loaded.game(function()
		loader.load("late", on_ready_late, on_reload_late)
	end)
end)
