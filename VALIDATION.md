# Validation

Validated on an Apple Silicon Mac running macOS 15.7.3 on 4 November 2026.

- Python syntax and both Swift sources passed their syntax/type checks.
- A complete build from the official Joplin 3.5.5 ARM64 DMG succeeded.
- The original vendor code signature passed verification before copying.
- The completed app passed `codesign --verify --deep --strict`.
- Its identifier is `local.joplin.institute355`, its bootstrap executable is
  `Joplin`, and its Electron executable is `JoplinCore`.
- The packaged JavaScript archive is byte-for-byte identical to the vendor
  archive. The executable's native code section is unchanged; its signature is
  replaced during packaging.
- The generated icon was visually checked: dark navy field, white J and
  transparent background.
- Building over an existing output was refused without replacing it.
- A source with the wrong version was rejected without creating an output app.

The same startup source and signing arrangement were previously verified in the
working installed instance: the institute profile was selected, one foreground
Dock app was shown, and synchronisation succeeded after quitting and reopening
without another password prompt following the final Keychain **Always Allow**
grant. The newly generated packaging-test copy was not launched or installed,
to avoid disturbing that authorised installation.

Other Joplin versions, Intel Macs and other macOS releases have not been
validated by this repository. No server metadata or credential migration is
included in these build checks.
