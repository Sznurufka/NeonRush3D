# NEON RUSH 3D — Android runner project

A playable Godot 4 3D endless-runner prototype. Includes three lanes, swipe/tap controls, keyboard controls for testing, jump, obstacles, coins, magnet/shield/speed power-ups, level progression, a coin shop, upgrades, unlockable skins and local save data.

## Requirements
- Godot Engine **4.3 or newer** (standard build, not .NET).
- For APK export: Android export templates matching your Godot version, Android SDK command-line tools/platform-tools, OpenJDK 17, and Android build tools. Godot's official Android export documentation has the current version-specific setup steps: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

## Open and test on computer
1. Extract this folder.
2. Start Godot Project Manager.
3. Click **Import**, select `project.godot`, then **Import & Edit**.
4. Press **F6/F5** or the Play button.
5. Keyboard: A/Left = move left, D/Right = move right, Space = jump. The on-screen buttons also work.

## Build an APK
1. Install Godot 4.3+ and matching export templates.
2. Configure Android SDK and Java in **Editor > Editor Settings > Export > Android**. Use JDK 17 and the SDK path installed on your machine. Install the SDK platform/build-tools versions requested by your Godot version.
3. Open **Project > Export**. If prompted, add an **Android** preset.
4. Set package name to something unique, e.g. `com.example.neonrush3d`. Set version name/code as needed.
5. For a personal test install, enable **Runnable** in the Android preset if that option is shown, then choose **Export Project** and save as `NeonRush3D.apk`.
6. If export reports missing Android build templates or SDK components, install the exact items listed by the error message and retry.

## Install on Samsung Galaxy A36
1. Copy `NeonRush3D.apk` to the phone (USB, Drive, or send it to yourself).
2. Open the APK from **My Files**.
3. If Android asks, allow **Install unknown apps** for the app you used to open the file, then return and tap **Install**.
4. Open **Neon Rush 3D**. For later builds, install the new APK over the old one using the same package ID and signing key.

## Controls
- Touch left/right arrows or swipe left/right to change lanes.
- Tap the center area or press the JUMP button to jump.
- Swipe up to jump.
- Use SHOP to spend coins on upgrades and skins.
- Block obstacles must be avoided; jump over the low orange barriers.
- Magnet, shield and speed-boost power-ups spawn during runs.

## Project layout
- `project.godot` — project configuration.
- `Main.tscn` — main scene.
- `scripts/main.gd` — procedural 3D world, gameplay, UI, shop and save system.

## Notes
This is a complete playable starter project, not a finished commercial release. It uses procedural primitive 3D art, so it has no external asset downloads. Before publishing, test on device, add your own app icon, review performance and create a signed release build. The save file is stored locally at `user://neon_rush_save.json`.
