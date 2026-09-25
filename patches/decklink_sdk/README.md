# DeckLink SDK headers

Both the Windows and the Linux build of FFmpeg compile against the headers in this directory,
so the two use the same Blackmagic Desktop Video SDK version. `build_libdecklink` in
`cross_compile_ffmpeg.sh` stops the build if they are not the same version.

| directory  | contents                                                                        |
|------------|---------------------------------------------------------------------------------|
| `linux/`   | `Linux/include` from the SDK, as is                                             |
| `windows/` | `DeckLinkAPI.h` and `DeckLinkAPI_i.c`, generated with widl from the SDK's `Win/include` IDL, plus `DeckLinkAPIVersion.h` and the license text the generated files lose |

Fill or refresh them from an unpacked SDK (a registration-gated download from
blackmagicdesign.com/support) with:

    $ patches/decklink_sdk/update.sh "/path/to/Blackmagic DeckLink SDK 15.3"

The SDK version also sets the oldest usable driver: FFmpeg refuses Desktop Video drivers older
than the SDK it was built with.

## Why linux/ and windows/ are not in git

`.gitignore` keeps them out for now. The headers carry Blackmagic's license, which allows
reproducing and distributing them "in accordance with" the SDK's End User License Agreement and
requires the copyright notice to go with every copy. Section 0.1 of that agreement exempts the
`Win/Include`, `Linux/Include` and `Mac/Include` folders from its restrictive clauses, so
committing them looks allowed - but this repository is public, and that is a reading of someone
else's license worth having confirmed before publishing their files. Once it is settled, remove
the two lines from `.gitignore` and commit the directories; until then every build machine runs
`update.sh` once.
