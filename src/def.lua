---@meta NikkelM-Music_Maker_API
local public = {}

---@class MusicMakerSongData
---@field Id string The internal name of the song. Prefix this with your mod's `_PLUGIN.guid` to ensure uniqueness!
---@field TrackName string The FMOD event to play. Either a GUID string "{...}" of an event in a custom bank you register via `RegisterSoundBank`, or a base-game path like "/Music/IrisMusicScylla1_MC".
---@field InsertAfter string|nil The Id of an existing song (a base-game song like "Song_ArtemisSong", or another registered song) to insert this song after in the Music Maker list. Chain versions by pointing each at the previous one for a deterministic order. If nil, the song is appended to the end of the list.
---@field Name table Localized display name shown in the Music Maker list, e.g. { en = "My Song", de = "Mein Lied" }. The "en" key is required; missing languages fall back to English. Note that you need to double-escape square brackets: \\[Lyrics\\].
---@field Description table Localized description shown when the song is selected in the Music Maker, e.g. { en = "...", de = "..." }. The "en" key is required; missing languages fall back to English.
---@field InheritFrom table|nil Which existing song to inherit from, if applicable. Defaults to { "DefaultSongItem" }.
---@field Cost table|nil The resource cost to unlock this song. For display purposes, limit to at most five different resources. If nil, the inherited default of 100 CosmeticsPoints/Kudos is used.
---@field GameStateRequirements table|nil The requirements that must be met for this song to be purchasable. Supports all base-game requirement logic. Defaults to no requirements/always available.
---@field Rocking boolean|nil If true, the Music Maker will "rock out" to your song, instead of simply swaying.
---@field VersionOf string|nil The song this is a different version of (a base-game song like "Song_ArtemisSong", or another registered song). All songs that are versions of the same anchor form one group automatically, even across mods, and switching between them preserves the playback position (crossfade/live parameter morph). Supply the length of the anchor song via `RegisterVersionGroup`.
---@field Stems table|nil List of stem names (FMOD cue names, e.g. { "Guitar", "Bass", "Vocals", "Vocals2" }) to activate for this version. Every other stem used by the same FMOD event is deactivated (faded to 0), so switching between versions only changes which layers are audible. Omit to leave the event's stems untouched (e.g. a pre-mixed track/if you don't use Stems in your event).
---@field MusicSection number|nil Value for the "Section" FMOD parameter, used by base-game tracks to select the intensity or context of a continuous song. Leave empty unless you also define sections and transitions in your event.
---@field TrackOffset number|nil Seconds to seek into the track when playback starts. Defaults to 0/starting at the beginning of the track.
---@field AmbientParams table|nil Extra FMOD cue values (name -> number) to set on the AudioId of the played track, applied alongside the Stems. Use for non-stem parameters such as { LowPass = 0 }. Custom-bank songs generally do not need this. Leaving it unset preserves the normal parameter behaviour (e.g. music being quieter in the Training Grounds).
---@field UnlockImmediately boolean|nil If true, this song is unlocked immediately (the next time the save is loaded) instead of requiring purchase. Typically set by users through your own mod's config if you want to allow it, e.g. `UnlockImmediately = config.unlockEverything`.

---Registers a new song to be added to the Music Maker in the Crossroads.
---@param songData MusicMakerSongData The input data for the new song. Must be a valid MusicMakerSongData table.
---@return boolean successfullyRegistered True if the song was successfully registered, false otherwise.
public.RegisterSong = function(songData) end

---@class MusicMakerVersionGroupData
---@field AnchorSong string The song that every version in this group is a version of (usually a base-game song like "Song_ArtemisSong"). Matches the VersionOf of the group's songs.
---@field LoopLength number|nil The length in seconds of one loop of the shared arrangement, used to wrap a carried playback position. Measure it from your FMOD event, and if unsure round down rather than up, since a slightly short value keeps the carried seek inside real audio while too long can seek past the loop into silence.
---@field ContinuousStems table|nil List of stem names kept continuous when switching between this group's versions: they are switched quickly (not faded out and back in), while every other stem (e.g. vocals) crossfades. Defaults to { "Drums", "Bass", "Guitar" }. Pass {} to fade all stems.

---Registers the loop length for a version group, identified by its anchor song. Songs join a group automatically by declaring `VersionOf`.
---This call only supplies the anchor's loop length so a carried playback position can be wrapped.
---@param groupData MusicMakerVersionGroupData The input data for the version group. Must be a valid MusicMakerVersionGroupData table.
---@return boolean successfullyRegistered True if the version group was successfully registered, false otherwise.
public.RegisterVersionGroup = function(groupData) end

---Registers an FMOD sound bank to load when entering the Crossroads.
---Place the .bank file in your mod's `plugins_data` folder.
---@param bankPath string Absolute path to the .bank, e.g. `rom.path.combine(_PLUGIN.plugins_data_mod_folder_path, "Audio\\MyBank.bank")`.
---@return boolean successfullyRegistered True if the sound bank was registered, false otherwise.
public.RegisterSoundBank = function(bankPath) end

return public
