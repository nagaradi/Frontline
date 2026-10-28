FRONTLINE - CONSOLIDATED OFFLINE BATTLE-ROYALE PROTOTYPE
Godot target: Godot 4.7.x, Compatibility renderer

IMPORTANT
- This is an evolving prototype, not a finished PUBG clone.
- Most new environment and weapon visuals are procedural placeholders. The included soldier model is from the user's original project.
- Keep your original ZIP as a backup. Extract this archive into a NEW folder before importing it in Godot.
- This environment cannot run the Godot editor, so the project was checked for file/resource consistency but has NOT received a live runtime test. Please report any red Godot errors.

FEATURES PRESENT IN THIS CONSOLIDATED BUILD
- Third-person player camera and soldier model.
- WASD movement, Space jump, Shift sprint, mouse look/shoot, touch joystick, mobile camera-look gesture, Aim zoom, and mobile buttons.
- Larger responsive mobile controls: Fire, Aim, Reload, Switch, Pickup, Grenade, Smoke, Drink, First Aid, Med Kit, and hold-to-sprint.
- M416, AKM, SCAR-L, Groza, AWM and Pistol profiles with magazine sizes, damage, fire delay, and reload timings.
- Procedural held-weapon placeholder, muzzle flash, bullet tracer and hit marker.
- Larger terrain area with generated grass/asphalt textures, roads, open-door buildings, cover, trees, rocks and distant hills.
- Procedural sky and sunlight/shadows.
- Safe-zone shrink and damage, red-zone warning/strike events, airdrop crates with red smoke beacon.
- Enemy chasing/attacking, kill count, temporary death body, loot crate and minimap enemy/loot markers.
- Limited survival inventory, loot pickup, health/ammo/weapon HUD, minimap safe-zone ring, and event countdown.

PC CONTROLS
- WASD: move
- Mouse: look around (click to capture cursor)
- Left mouse: fire (after cursor is captured)
- Right mouse: aim toggle
- Space: jump
- Shift: sprint
- Escape: release/capture cursor
- E: legacy ammo pickup where supported; use PICKUP button for weapon/loot items

OPENING THE PROJECT
1. Extract the ZIP into a new folder.
2. In Godot Project Manager choose Import.
3. Select the extracted folder's project.godot.
4. Open the project and press F6 to run the current main scene.
5. If Godot shows an error, copy the full first red error from the Output panel.

MOBILE FIRE
- Touch and hold FIRE to shoot continuously.
- Release FIRE to stop. The current weapon's cooldown sets the firing rate.
- Drag in the clear middle-right screen area to rotate the camera; avoid dragging directly over the action buttons.

ANDROID APK (when ready to export)
1. Install the matching Godot 4.7.x export templates in Godot Editor > Manage Export Templates.
2. Open Project > Export, add an Android preset, and follow Godot's Android SDK/JDK setup prompts.
3. For a local test APK, use a debug build; a release APK requires a signing key.
4. Export the APK and install it on the phone. The project has not yet been runtime-tested, so fix any Godot errors before relying on the APK.

PAUSE MENU (v11)
- On PC, press Escape to pause/resume the match.
- On touch screens, tap the pause icon below the minimap.
- RESUME returns to the match; RESTART MATCH reloads the current scene.
