//
//  main.swift
//  PureBarMac
//
//  Created by cyan on 1/2/24.
//

import AppKit

Bundle.swizzleInfoDictionaryOnce

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
