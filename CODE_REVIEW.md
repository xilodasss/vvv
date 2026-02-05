# Code Review Notes

## Scope checked
- `TeleportModule.lua`

## Findings
1. **Crash risk on startup**: The script destroyed `PlayerGui.DraconicHubGui` without checking whether it exists.
2. **SetCore timing errors**: `StarterGui:SetCore("SendNotification", ...)` can throw if called before Roblox core is ready.
3. **Service duplication**: `Players` and `LocalPlayer` were initialized twice in different sections, which makes maintenance harder.

## Fixes applied
- Added safe `FindFirstChild` checks before destroying `DraconicHubGui`.
- Wrapped `SetCore` notification call in `pcall` to avoid hard failure.
- Consolidated `Players` / `LocalPlayer` initialization at the top of the file.
