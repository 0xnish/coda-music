# Changelog

All notable changes to CODA MUSIC will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.5.0] - 2026-08-07

### Fixed
- Search suggestions not loading (typed map-list mismatch caused a runtime cast error)
- Lyrics timeout regression — LRCLib is now a fast path and no longer blocked by a slow Lyrica instance
- Slow-network playback auto-retry
- Search history ordering
- Miniplayer progress bar lag by seeking only on drag end

### Improved
- Background isolate for smooth animations
- Installer branding

## [2.2.0] - 2026-07-17

### Fixed
- Equalizer mpv filter syntax (correct positional parameters for equalizer and scaletempo)
- Intermittent song loading failures with automatic retry on timeout
- Loading retry no longer gives up — retries indefinitely until song plays
- Equalizer reference invalidation after player stop/clear cycles

### Improved
- Switch toggle hover states in dark theme (no longer appears fully white)
- Switch toggle animation smoothness

## [1.0.0] - 2025-07-11

### Added
- YouTube Music streaming and search
- Lyrics support (LRCLib, Lyrica providers)
- Billboard charts (Hot 100, Billboard 200, genre charts)
- Spotify charts integration
- Local audio library support
- Built-in audio streaming server
- Auto-update notifications
- Material 3 dynamic theming
- Blur effects and modern UI
