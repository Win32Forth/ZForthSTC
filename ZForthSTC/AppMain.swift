//
//  AppMain.swift
//  ZForthSTC
//
//  Public domain.
//
//  Process entry: agent/headless channel or normal SwiftUI GUI.
//

import Foundation
import SwiftUI

@main
enum AppMain {
    static func main() {
        if AgentChannel.isRequested {
            AgentChannel.runAndExit()
        }
        ForthConsoleApp.main()
    }
}
