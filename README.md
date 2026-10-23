# Aetherist

A simple Roblox script loader with a local supported-game library.

> **Author:** [HolexDeveloper](https://github.com/HolexDeveloper)

## How It Works

`loader.lua` waits for the game to load and detects the local player, then checks `game.GameId` against a local `CONFIG` table of supported games:

- **Supported game detected** → the corresponding script is fetched and executed.
- **No matching GameId** → the loader falls back to running:
  ```lua
  loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Entrenched.lua", true))()
  ```

## Supported Games

| Game ID | Title | Link |
|---------|-------|------|
| `3678761576` | Entrenched WW1 | [Roblox](https://www.roblox.com/games/3678761576/ENTRENCHED) |

## Usage

Execute `loader.lua` in your preferred Roblox executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/loader.lua"))()
```

## Adding a Game

Add a new entry to the `CONFIG` table inside `loader.lua`:

```lua
local CONFIG = {
    [3678761576] = {
        title = "Entrenched WW1",
        url = "https://www.roblox.com/games/3678761576/ENTRENCHED",
        script = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Entrenched.lua",
    },
    -- Add new games here:
    -- [GAME_ID] = {
    --     title = "Game Name",
    --     url = "https://www.roblox.com/games/GAME_ID/Game-Name",
    --     script = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/YourScript.lua",
    -- },
}
```

## File Structure

```
├── loader.lua       -- Main loader (game-ID detection + fallback)
└── Entrenched.lua   -- Script for Entrenched WW1 (do not modify logic without permission)
```

## Contributing

Contributions are welcome! You may contribute to the scripts in this repository, but **credit must be given to the repository owner**: [HolexDeveloper](https://github.com/HolexDeveloper). See the [LICENSE](LICENSE) for details.

When contributing:
1. Fork the repository and create a feature branch.
2. Do **not** change the Luau code inside `Entrenched.lua` unless explicitly approved.
3. Keep attribution/credits intact in all files.
4. Open a pull request describing your changes.

## License

This project is licensed under a custom license that permits contribution with required attribution — see [LICENSE](LICENSE).
