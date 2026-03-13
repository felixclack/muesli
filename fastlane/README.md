fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac doctor

```sh
[bundle exec] fastlane mac doctor
```

Show current signing and notarization readiness

### mac setup_local_signing

```sh
[bundle exec] fastlane mac setup_local_signing
```

Create a stable local self-signed signing identity for reinstall testing

### mac setup_signing

```sh
[bundle exec] fastlane mac setup_signing
```

Create or sync a Developer ID Application certificate with match

### mac local_install

```sh
[bundle exec] fastlane mac local_install
```

Build, sign, reinstall to /Applications, and launch the local app

### mac release

```sh
[bundle exec] fastlane mac release
```

Build, sign, notarize, and package a release DMG and ZIP

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
