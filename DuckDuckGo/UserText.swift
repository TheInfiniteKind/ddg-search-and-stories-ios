//
//  UserText.swift
//  DuckDuckGo
//
//  Created by Mia Alexiou on 24/01/2017.
//  Copyright © 2017 DuckDuckGo. All rights reserved.
//

import Foundation

public struct UserText {
    
    public static let onboardingRealPrivacyTitle = forKey("onboarding.realprivacy.title")
    public static let onboardingRealPrivacyDescription = forKey( "onboarding.realprivacy.description")
    public static let onboardingContentBlockingTitle = forKey("onboarding.contentblocking.title")
    public static let onboardingContentBlockingDescription = forKey("onboarding.contentblocking.description")
    public static let onboardingTrackingTitle = forKey("onboarding.tracking.title")
    public static let onboardingTrackingDescription = forKey("onboarding.tracking.description")
    public static let onboardingPrivacyRightTitle = forKey("onboarding.privacyright.title")
    public static let onboardingPrivacyRightDescription = forKey("onboarding.privacyright.description")
    
    fileprivate static func forKey(_ key: String) -> String {
        return NSLocalizedString(key, comment: key)
    }
}
