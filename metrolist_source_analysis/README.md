# Metrolist YouTube Music Streaming Implementation - Complete Source Analysis

## Architecture Overview

The streaming pipeline works as follows:

1. **`YTPlayerUtils.playerResponseForPlayback()`** - Main entry point. Iterates through fallback clients, gets player responses, selects audio formats
2. **`InnerTube.player()`** - Sends POST to `https://music.youtube.com/youtubei/v1/player` with `PlayerBody` JSON
3. **`CipherDeobfuscator`** - Handles signature decryption + n-parameter (throttle) transformation via WebView executing player.js
4. **`PoTokenGenerator`** - Generates BotGuard/PoToken via WebView for web clients
5. **ExoPlayer** - Downloads audio bytes using `OkHttpDataSource` with the resolved URL + headers

## Key Files by Component

### Core InnerTube Module (`innertube/`)
- `InnerTube.kt` - HTTP client, all InnerTube API calls
- `YouTube.kt` - High-level API (search, browse, player, etc.)
- `YouTubeConstants.kt` - Constants
- `NetworkConfig.kt` - HTTP client configuration

### Client Configs & Request Bodies (`innertube/models/`)
- `YouTubeClient.kt` - All client definitions (WEB_REMIX, IOS, ANDROID_VR, etc.)
- `Context.kt` - InnerTube request context
- `MediaInfo.kt` - Media metadata model

### Request Bodies (`innertube/models/body/`)
- `PlayerBody.kt` - The /player POST body

### Response Models (`innertube/models/response/`)
- `PlayerResponse.kt` - StreamingData, Format, VideoDetails, etc.
- `NextResponse.kt` - Watch next results

### Stream Resolution (`app/.../utils/`)
- `YTPlayerUtils.kt` - **THE MOST CRITICAL FILE** - stream URL resolution, format selection, fallback strategy

### Cipher/Signature Decryption (`app/.../utils/cipher/`)
- `CipherDeobfuscator.kt` - Orchestrator for sig deobfuscation + n-transform
- `FunctionNameExtractor.kt` - Extracts sig/n function names from player.js
- `PlayerJsFetcher.kt` - Downloads and caches player.js
- `PlayerConfigParser.kt` - Parses player config
- `PlayerConfigStore.kt` - Config storage and refresh
- `CipherWebView.kt` - WebView that executes the cipher JS

### PoToken Generation (`app/.../utils/potoken/`)
- `PoTokenGenerator.kt` - BotGuard token generation via WebView
- `PoTokenWebView.kt` - WebView for PoToken
- `PoTokenResult.kt` - Result model

### Fallback Strategy (`innertube/strategy/`)
- `ContentAwareFallbackStrategy.kt` - Client fallback ordering based on content type

### Caching (`app/.../playback/`)
- `StreamUrlCache.kt` - URL cache with TTL
- `MusicService.kt` - ExoPlayer setup, ResolvingDataSource, OkHttp headers
