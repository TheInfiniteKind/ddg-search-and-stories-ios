//
//  OnboardingSettings.swift
//  DuckDuckGo
//
//  Created by Mia Alexiou on 03/03/2017.
//  Copyright © 2017 DuckDuckGo. All rights reserved.
//

import Foundation

struct OnboardingSettings {
    
    private let suit = "settingsSuit"
    
    private struct Keys {
        static let hasSeenOnboarding = "hasSeenOnboarding"
    }
    
    public var hasSeenOnboarding: Bool {
        get {
            return userDefaults()?.bool(forKey: Keys.hasSeenOnboarding) ?? false
        }
        set(newValue) {
            userDefaults()?.set(newValue, forKey: Keys.hasSeenOnboarding)
        }
    }
    
    private func userDefaults() -> UserDefaults? {
        return UserDefaults(suiteName: suit)
    }
}
