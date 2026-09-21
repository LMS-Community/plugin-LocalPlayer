# Signing the `squeezelite` binary

In order for macOS not to complain about the `squeezelite` binary, we have to sign and notarize it.

Signing:

```
codesign --force \
  --options runtime \
  --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  squeezelite
```

Verify signature:

```
codesign --verify --verbose=4 squeezelite
codesign -dv --verbose=4 squeezelite
```

Don't notarize the entire plugin ZIP just because that's what you're distributing. Apple notarization is
primarily concerned with the executable code; your Perl scripts/data don't need to be code-signed just
because they're in the same ZIP.

```
mkdir notarize
cp squeezelite notarize/

ditto -c -k --keepParent notarize squeezelite-notarize.zip

xcrun notarytool submit squeezelite-notarize.zip \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "APP_SPECIFIC_PASSWORD" \
  --wait
```

The last command should return with something like:

```
Current status: Accepted.......
Processing complete
  id: f1c732f3-0ed4-496d-bc12-cdf874e0c1be
  status: Accepted
```

