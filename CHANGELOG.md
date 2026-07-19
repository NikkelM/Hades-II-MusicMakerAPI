# Changelog

## v1.1.0

<!--Releasenotes start-->
- Added `MusicMakerAPI.UnlockSong(songId)`, which mods should use to unlock a registered song instead of inserting it into `GameState.UnlockedMusicPlayerSongs` directly.
- Modded songs are no longer added to the game's `UnlockedMusicPlayerSongs` list. They are now tracked in a separate, API-managed list and added into the music player shuffle only while their mod is installed, so uninstalling or updating a song mod can no longer corrupt the shuffle or the saved playlist. Songs already unlocked with older versions are migrated automatically.
- Fixed a crash when entering the Crossroads if a previously unlocked song has since been removed and the game attempts to play it.
<!--Releasenotes end-->

## v1.0.0

- Initial release.
