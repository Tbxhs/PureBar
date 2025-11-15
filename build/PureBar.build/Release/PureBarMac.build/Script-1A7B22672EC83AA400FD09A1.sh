#!/bin/sh
/usr/bin/sandbox-exec -p "(version 1)
(deny default)
(import \"system.sb\")
(allow file-read*)
(allow process*)
(allow mach-lookup (global-name \"com.apple.lsd.mapdb\"))
(allow mach-lookup (global-name \"com.apple.mobileassetd.v2\"))
(allow file-write*
    (subpath \"/private/tmp\")
    (subpath \"/private/var/tmp\")
    (subpath \"/private/var/folders/30/38n_9d155tg9ydc76h8q7s8c0000gn/T\")
    (subpath \"/private/var/folders/30/38n_9d155tg9ydc76h8q7s8c0000gn/C\")
)
(deny file-write*
    (subpath \"/Users/james/dev/PureBar\")
)
(allow file-write*
    (subpath \"/Users/james/Library/Developer/Xcode/DerivedData/PureBar-fjmpgodslxlxaabmqdjuznbqbull/Build/Intermediates.noindex/BuildToolPluginIntermediates/PureBar.output/PureBarMac/SwiftLint\")
    (subpath \"/private/var/folders/30/38n_9d155tg9ydc76h8q7s8c0000gn/T/TemporaryItems\")
)
" /Users/james/Library/Developer/Xcode/DerivedData/PureBar-fjmpgodslxlxaabmqdjuznbqbull/SourcePackages/artifacts/purebartools/SwiftLintBinary/SwiftLintBinary.artifactbundle/swiftlint-0.61.0-macos/bin/swiftlint lint --strict --config /Users/james/dev/PureBar//.swiftlint.yml --cache-path /Users/james/Library/Developer/Xcode/DerivedData/PureBar-fjmpgodslxlxaabmqdjuznbqbull/Build/Intermediates.noindex/BuildToolPluginIntermediates/PureBar.output/PureBarMac/SwiftLint//cache /Users/james/dev/PureBar/

