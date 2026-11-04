# Joplin macOS isolated instance

Build a separate **native Apple Silicon Joplin 3.5.5** application with its own
profile, a dark navy icon and one foreground Dock application. Run it alongside
a newer personal Joplin client without Docker or Intel emulation.

This is an unofficial, version-pinned packaging tool, not a Joplin fork or a
server compatibility fix. It distributes only original build tools. Obtain
Joplin itself from the [official 3.5.5 release](https://github.com/laurent22/joplin/releases/tag/v3.5.5).
That release is marked as a pre-release upstream.

## Requirements

- An Apple Silicon Mac. The working installation was tested on macOS 15.7.3.
- Apple's Command Line Tools: install with `xcode-select --install` if needed.
- Native ARM64 Python 3.9 or later, available as `python3`.
- The official **Joplin-3.5.5-arm64.DMG**. Mount it, but do not replace your
  newer application in `/Applications`.

## Build and install

1. Back up your Joplin profiles and quit Joplin before setting up the new instance.
2. Clone this repository or download and extract its source ZIP.
3. In Terminal, enter the repository directory and run the following, replacing
   the source path with the `Joplin.app` inside your mounted DMG:

   ```sh
   python3 build.py "/Volumes/Joplin/Joplin.app"
   ```

   The builder checks the version, ARM64 executable, pinned application archive
   header and original code signature. It copies the app, builds the native
   startup executable, recolours its icon, signs the completed bundle and
   verifies the result. It refuses to overwrite an existing output.

4. Move `dist/Joplin-Institute-3.5.5.app` into your **user Applications folder**
   (`~/Applications`). Keep your personal Joplin separately. Install the final
   copy before granting it Keychain access.
5. Open that installed app, configure its synchronisation account and download
   its notes. When macOS requests **Joplin Safe Storage** access, enter your Mac
   login password in the system dialog and choose **Always Allow** for this app.
6. Drag that installed app into the Dock. Quit it with **⌘Q**, reopen it from the
   dark icon, and confirm that it synchronises without another password prompt.

The build does not install or launch the app, access passwords, edit existing
profiles, configure synchronisation, change server metadata or alter the Dock.

Options:

```sh
python3 build.py "/path/to/Joplin.app" --output "/path/to/New-Institute.app"
python3 build.py "/path/to/Joplin.app" --icon "/path/to/custom.icns"
```

The default icon recolours the supplied vendor icon to RGB **4, 18, 35**
(`#041223`), preserving its white letter and transparency. No Joplin artwork
is included in this repository.

## Isolation and startup

The generated app always selects:

```text
Profile: ~/Library/Application Support/Joplin-Institute
Instance ID: institute
Bundle identifier: local.joplin.institute355
```

Its ARM64 startup executable replaces itself with the bundled Electron
executable using `execv`, adding:

```text
--profile "<institute-profile-directory>" --alt-instance-id institute --no-welcome
```

There is one foreground application, with Electron's normal background helper
processes. The startup code also disables automatic updates for this instance.
The application name stays **Joplin** to retain the native Safe Storage service.
The vendor JavaScript archive is not modified.

This repository builds **one additional institute instance**. Changing the output
filename alone does not create another isolated profile or instance. To adapt it
for further instances, change the profile directory and instance ID in
`src/main.swift`, and `BUNDLE_ID` in `build.py`, before building.

## Signing and saved passwords

This custom build uses **local ad-hoc signatures**, not an Apple Developer ID or
notarisation. Hardened runtime remains enabled. Alongside the vendor Electron
entitlements, it requires the app-only entitlement
`com.apple.security.cs.disable-library-validation=true` so its locally signed
Electron libraries can load. This reduces library-signature protection for this
app. No system-wide security setting is changed. Review `src/entitlements.plist`
before building.

macOS may request approval when first opening a locally modified application.
Use the system's per-app approval flow only if you trust this build; do not
disable Gatekeeper globally. Organisation-managed Macs may prohibit local builds.

The application uses Joplin's native credential storage. This tool does not
extract, migrate or print credentials. Configure your account directly in Joplin;
if you have forgotten the account password, use the server's reset process or
contact its administrator. **Always Allow** remembers Keychain access for the
final signed application. Rebuilding or re-signing it can require fresh approval.

## Profile and server compatibility

- Never share a profile directory between different Joplin versions. Do not copy
  a newer client's database into this older profile or change its schema version.
- Each instance has its own synchronisation account settings. Configure the
  personal client for the personal account and the institute client for the
  institute account.
- Isolation does not repair an outdated server, sharing permissions or an
  account's minimum-client requirement. Resolve those with the administrator;
  the builder does not modify them.
- Keep old clients only as long as needed. Reassess the setup after the server
  is updated and back up before any migration.

## Validation and removal

Verify the installed bundle with:

```sh
codesign --verify --deep --strict "$HOME/Applications/Joplin-Institute-3.5.5.app"
```

In Joplin's settings, confirm the institute profile directory, then check the
synchronisation configuration. Verify that the personal client still uses its
own profile. Reopening the institute app from its Dock icon must retain its
profile, saved password and single dark icon.

To remove the custom application, quit it and remove its app bundle and Dock
shortcut. Its profile remains in `~/Library/Application Support/Joplin-Institute`;
keep that directory until you have exported or backed up any needed data.

## Licence

The original build tools are available under the MIT licence in `LICENSE`.
Joplin remains separately licensed by its authors. No Joplin binaries, artwork,
notes, databases or credentials are distributed here. This project is not
affiliated with the Joplin project.
