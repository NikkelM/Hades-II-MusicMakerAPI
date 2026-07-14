# Music Maker API

A developer library that makes it easy to add new songs to the Music Maker in the Crossroads in Hades II. Does nothing by itself.

## Features

Through this library, you can easily add new songs to the Music Maker.
It supports both single-track and multi-track music, and you can add different songs for different combinations of active stems in a single FMOD event (e.g. an instrumental and an instrumental+vocals version).

> New to adding music to Hades II?
> Check out the detailed guide on our wiki to learn how to add audio to the game: [Audio Guide on the Hades II Modding Wiki](https://sgg-modding.github.io/Hades2ModWiki/docs/category/audio)

If you add multi-track songs, you can additionally enable seemless switching between them - instead of restarting from the beginning, switching between two versions of the same track will simply change the active stems.
To enable this, set each version's `VersionOf` property to the song it is a version of (a base-game song, or another API-registered song); all versions of the same song are then grouped together automatically, even across different mods.
You only need to supply the group's shared loop length (the length of the track) through `MusicMakerAPI.RegisterVersionGroup()`.

## Usage

Start by adding `NikkelM-Music_Maker_API` as a dependency in your `thunderstore.toml` (ensure you use the latest version):

```toml
NikkelM-Music_Maker_API = "1.0.0"
```

Next, include the Music Maker API in your `main.lua`, alongside other dependencies:

```lua
---@module "NikkelM-Music_Maker_API"
MusicMakerAPI = mods["NikkelM-Music_Maker_API"]
```

### Registering Soundbanks

You will most likely have a `.bank` file with your new songs packaged with your mod.
You can register this file with the Music Maker API to have it automatically handle loading it when required.
To do so, place your `.bank` files in your mod's `plugins_data` folder and call `MusicMakerAPI.RegisterSoundBank` for each of your banks (including the `.bank` extension):

```lua
MusicMakerAPI.RegisterSoundBank(rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, "Audio\\AuthorNameModNameCustomMusic.bank"))
```

The API will automatically load all registered banks when the player enters the Crossroads (including the Training Grounds), regardless of which transition is used (`DeathAreaRoomTransition`, `HubPostBountyLoad`, or `HubPostDreamLoad`).
Duplicate bank names are silently ignored.

You can alternatively also load the banks yourself within your mod code, if it better fits your workflow.

### Registering Songs

Now, you can add a new song to the Music Maker by calling `MusicMakerAPI.RegisterSong(musicMakerSongData)`, where `musicMakerSongData` is of type `MusicMakerSongData`.
If you have your development environment set up correctly, VS Code should offer autocompletion and type hints for this table.
Otherwise, you can always refer to the `def.lua` file in the Music Maker API source, or the below example, for all available fields.

```lua
MusicMakerAPI.RegisterSong({
	-- REQUIRED
	Id = _PLUGIN.guid .. "ArtemisSong_Duet",
	TrackName = "{00000000-0000-0000-0000-000000000000}", -- The event GUID for this track, from the exported GUIDS.txt in FMOD
	InsertAfter = "Song_ArtemisSong",
	-- At least "en" must be provided for Name and Description
	Name = {
		en = "Moonlight Guide Us \\[Duet\\]", -- Square brackets need to be double-escaped to display correctly!
		de = "Mondlicht leite uns \\[Duet\\]",
	},
	Description = {
		en = "Theme the Silver Sisters use to strengthen their connection and steady their resolve.",
		-- ...
	},
	-- OPTIONAL
	-- Stems to activate; every other stem used by any version of this FMOD event is deactivated
	-- If your event does not rely on any stems being active/you did not add any automations using parameters, leave this empty
	Stems = { "Guitar", "Bass", "Vocals" },
	Cost = { 
		CosmeticsPoints = 250
	},
	GameStateRequirements = {
		{ 
			PathTrue = { "GameState", "WorldUpgradesAdded", "Song_ArtemisSong" }
		},
	},
	UnlockImmediately = config.unlockEverything,
	VersionOf = "Song_ArtemisSong", -- If you use `RegisterVersionGroup()`, make this song join the given group, by its `AnchorSong`
})
```

### Grouping songs for seamless switching

When several songs are versions of the same underlying track, you can make the Music Maker switch between them seamlessly: instead of restarting from the beginning, it carries the playback position over and crossfades, so it sounds like the active stems (or who is singing) are simply toggled.

A song joins a group by setting `VersionOf` (see the `RegisterSong` example above) to the song it is a version of.
That anchor can be a base-game song, one of your own songs, or a song from another mod.
Every song that resolves to the same anchor is joined into one group automatically, even across mods, so no group identifier needs to be coordinated.

Register the anchor's loop length once so the carried position wraps correctly (optional - without it, a carried position simply is not wrapped):

```lua
MusicMakerAPI.RegisterVersionGroup({
	AnchorSong = "Song_ArtemisSong",
	LoopLength = 177.34,
})
```

To group songs you add yourself, pick one of them as the anchor (leave its `VersionOf` unset) and point every other version at the anchor's exact `Id`:

```lua
local anchorId = _PLUGIN.guid .. "MySong" -- the version every other version is a version of

-- The anchor: no VersionOf
MusicMakerAPI.RegisterSong({ Id = anchorId, --[[ TrackName, Name, ... ]] })
-- The other versions: VersionOf points at the anchor's exact Id
MusicMakerAPI.RegisterSong({ Id = _PLUGIN.guid .. "MySong_Vocals", VersionOf = anchorId, --[[ ... ]] })
MusicMakerAPI.RegisterSong({ Id = _PLUGIN.guid .. "MySong_Duet", VersionOf = anchorId, --[[ ... ]] })

MusicMakerAPI.RegisterVersionGroup({ AnchorSong = anchorId, LoopLength = 177.34 })
```

To anchor on another mod's song instead, set `VersionOf` to that song's exact registered `Id` and declare that mod as a dependency so the song is present.

Make sure `VersionOf` matches the anchor's `Id` exactly (including your `_PLUGIN.guid` prefix), and keep a single clear anchor per group: do not point two songs at each other in a cycle, or each song will end up in its own group.