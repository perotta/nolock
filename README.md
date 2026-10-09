# NoLock

A native macOS menu bar app for uninterrupted work. Requires macOS 13 or later. No external packages or Xcode project required; build with Apple's Swift command line tools.

NoLock holds display and system sleep assertions while enabled, refreshes user activity every 30 seconds, and nudges the cursor two points and back every 30 seconds once you've been idle for two minutes. Real mouse or keyboard input starts a fresh two-minute countdown. It never clicks or types, skips nudges while a mouse button is held, and won't return the cursor over your own movement.

## Install

```sh
./scripts/install.sh
```

This builds `dist/NoLock.app`, copies it to `~/Applications/NoLock.app`, and opens it. Click **Enable cursor movement**, then enable **NoLock** in **System Settings → Privacy & Security → Accessibility**. Accessibility and event-posting access are checked every second and when the app becomes active. Once access is recognized, the permission card disappears and the idle countdown appears. Power assertions work while you finish setup; cursor movement requires the permission.

If an older temporary-signature build shows a permission card despite an enabled toggle, renew the existing NoLock entry in Accessibility for the updated app. A transition from temporary signing to a developer signature may require this once; subsequent builds keep the same developer identity.

Click the cursor icon in the menu bar to show or hide a movable controls window. Drag its title bar or empty background to position it wherever you like; the position is remembered across launches. Closing the window keeps NoLock running in the menu bar. The window contains pause, test a nudge, and **Launch at login** controls. Right-click the menu bar icon for quick pause and quit actions. Pausing or quitting releases all sleep assertions. Protection starts enabled on first launch, and your toggle choice is remembered.

Manual locking, deliberate sleep, closing a laptop's lid, forced organizational policies, and power or thermal emergencies can still lock or sleep the Mac. A screen saver configured to start before two minutes may still start before the first cursor nudge; choose an idle delay longer than two minutes for the cursor mechanism. NoLock doesn't change your system settings or bypass an existing lock screen.

## Build and verify

```sh
./scripts/test.sh
./scripts/build.sh
dist/NoLock.app/Contents/MacOS/NoLock --smoke-test
pmset -g assertions
```

The smoke test creates and releases actual power assertions and reports cursor permission. With the app running, `pmset` should show `NoLock: keep the display awake` and `NoLock: keep ongoing work running`. Use **Test a nudge** after granting Accessibility to check the visible movement. The unit tests cover idle timing, user activity, permission/session/drag gating, and multiple-display boundaries.

The test script selects a full Xcode for its own process when available, because some Command Line Tools releases omit Swift Testing runtime dependencies. It doesn't change your global developer-tool selection.

The build uses an installed Apple Development identity when available and remembers its selection locally for subsequent updates. Set `CODE_SIGN_IDENTITY` to override that selection. Without a developer identity, it falls back to ad-hoc signing, which may require renewing Accessibility access after updates. This is a local app, not a notarized public distribution. The build targets the current Mac's architecture.

## Apple API references

- [Power assertion types](https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes)
- [Declare user activity](https://developer.apple.com/documentation/iokit/1557127-iopmassertiondeclareuseractivity)
- [Quartz event source states](https://developer.apple.com/documentation/coregraphics/cgeventsourcestateid)
- [Event posting permission](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess())
