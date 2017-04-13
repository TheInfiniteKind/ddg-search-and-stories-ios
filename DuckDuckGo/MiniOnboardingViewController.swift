//
//  OnboardingViewController.swift
//  DuckDuckGo
//
//  Created by Mia Alexiou on 03/03/2017.
//  Copyright © 2017 DuckDuckGo. All rights reserved.
//

import UIKit

class MiniOnboardingViewController: UIViewController, UIPageViewControllerDelegate {
    
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var bottomMarginConstraint: NSLayoutConstraint!
    
    private weak var pageController: UIPageViewController!
    private var transitioningToPage: OnboardingPageViewController?
    fileprivate var dataSource: OnboardingDataSource!
    var dismissHandler: (() -> Void)?
  
    static func loadFromStoryboard() -> MiniOnboardingViewController {
        let storyboard = UIStoryboard.init(name: "MiniOnboarding", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "MiniOnboardingViewController") as! MiniOnboardingViewController
        controller.dataSource = OnboardingDataSource(storyboard: storyboard, mini:true)
        return controller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurePageControl()
    }
    
    private func configurePageControl() {
        pageControl.numberOfPages = dataSource.count
        pageControl.currentPage = 0
    }
    
    override func viewDidLayoutSubviews() {
        configureDisplayForVerySmallHandsets()
    }
    
    private func configureDisplayForVerySmallHandsets() {
        if view.bounds.height <= 480 && view.bounds.width <= 480 {
            bottomMarginConstraint?.constant = 0
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? UIPageViewController {
            prepare(forPageControllerSegue: controller)
        }
    }
    
    private func prepare(forPageControllerSegue controller: UIPageViewController) {
        pageController = controller
        controller.dataSource = dataSource
        controller.delegate = self
        goToPage(index: 0)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let next = pendingViewControllers.first as? OnboardingPageViewController else { return }
        transitioningToPage = next
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if !completed {
            guard let previous = previousViewControllers.first as? OnboardingPageViewController else { return }
            guard let index = dataSource.index(of: previous) else { return }
            configureDisplay(forPage: index)
        } else {
            guard let current = transitioningToPage else { return }
            guard let index = dataSource.index(of: current) else { return }
            configureDisplay(forPage: index)
        }
        transitioningToPage = nil
    }
    
    private func configureDisplay(forPage index: Int) {
        pageControl.currentPage = index
        currentPageController().resetImage()
    }
    
    fileprivate func transition(withRatio ratio: CGFloat) {
//        transitionBackgroundColor(withRatio: ratio)
//        shrinkImages(withRatio: ratio)
    }
    
    private func shrinkImages(withRatio ratio: CGFloat) {
        let currentImageScale = 1 - (0.2 * (1 - ratio))
        currentPageController().scaleImage(currentImageScale)
        
        let nextImageScale = 1 - (0.2 * ratio)
        transitioningToPage?.scaleImage(nextImageScale)
    }
    
    private func goToPage(index: Int) {
        let controllers = [dataSource.controller(forIndex: index)]
        pageController.setViewControllers(controllers, direction: .forward, animated: true, completion: nil)
        configureDisplay(forPage: index)
    }
    
    @IBAction func onPageSelected(_ sender: UIPageControl) {
        goToPage(index: sender.currentPage)
    }
    
    @IBAction func onDonePressed(_ sender: UIButton) {
      if let dismissHandler = self.dismissHandler {
        dismissHandler()
      }
    }
    
    @IBAction func onLastPageSwiped(_ sender: Any) {
//        finishOnboardingFlow()
    }
    
    fileprivate func currentPageController() -> OnboardingPageViewController {
        return dataSource.controller(forIndex: pageControl.currentPage) as! OnboardingPageViewController
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

