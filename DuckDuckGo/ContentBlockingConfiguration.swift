//
//  ContentBlockingConfiguration.swift
//  DuckDuckGo
//
//  Created by Mia Alexiou on 03/03/2017.
//  Copyright © 2017 DuckDuckGo. All rights reserved.
//

import UIKit

class ContentBlockingConfiguration: OnboardingPageConfiguration {

    init(_ miniVersion:Bool) {
        super.init(title: UserText.onboardingContentBlockingTitle,
                   description: OnboardingPageConfiguration.adjustDescription(title: UserText.onboardingContentBlockingDescription,
                                                                              minify:miniVersion),
                   image: #imageLiteral(resourceName: "OnboardingContentBlocking"),
                   background: UIColor.onboardingContentBlockingBackground)
    }
    
}
