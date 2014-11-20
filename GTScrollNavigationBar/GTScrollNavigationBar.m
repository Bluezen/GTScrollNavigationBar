//
//  GTScrollNavigationBar.m
//  GTScrollNavigationBar
//
//  Created by Luu Gia Thuy on 21/12/13.
//  Copyright (c) 2013 Luu Gia Thuy. All rights reserved.
//

#import "GTScrollNavigationBar.h"

#define kNearZero 0.000001f

NSString* GTScrollNavigationBarFrameNotification = @"GTScrollNavigationBarFrameNotification";
NSString* GTScrollNavigationBarFrameNotificationOffsetYKey = @"GTScrollNavigationBarFrameNotificationOffsetYKey";
NSString* GTScrollNavigationBarFrameNotificationIsBarCondensedKey = @"GTScrollNavigationBarFrameNotificationIsBarCondensedKey";

@interface GTScrollNavigationBar () <UIGestureRecognizerDelegate>

@property (nonatomic, assign) CGFloat lastContentOffsetY;

- (BOOL)isNavigationBarCompact;

@end

@implementation GTScrollNavigationBar

@synthesize scrollView = _scrollView,
scrollState = _scrollState,
lastContentOffsetY = _lastContentOffsetY;

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.lastContentOffsetY = 0.0f;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarOrientationDidChange)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidChangeStatusBarOrientationNotification
                                                  object:nil];
    
    [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [_scrollView.panGestureRecognizer removeTarget:self action:@selector(finishStateTransitionIfNeeded:)];
}

- (void)setScrollView:(UIScrollView*)scrollView
{
    [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [_scrollView.panGestureRecognizer removeTarget:self action:@selector(finishStateTransitionIfNeeded:)];
    
    _scrollView = scrollView;
    
    [self resetToDefaultPositionWithAnimation:NO];
    
    [_scrollView addObserver:self forKeyPath:@"contentOffset" options:0 context:NULL];
    [_scrollView.panGestureRecognizer addTarget:self action:@selector(finishStateTransitionIfNeeded:)];
    
    self.lastContentOffsetY = scrollView.contentOffset.y;
}

- (BOOL)isNavigationBarCompact {
    return self.frame.origin.y != [self statusBarHeight];
}

- (void)resetToDefaultPositionWithAnimation:(BOOL)animated
{
    if ([self isNavigationBarCompact]) {
        CGRect frame = self.frame;
        frame.origin.y = [self statusBarHeight];
        [self setFrame:frame alpha:1.0f animated:animated];
    }
    
    self.scrollState = GTScrollNavigationBarNone;
}

- (void)compactWithAnimation:(BOOL)animated
{
    if (![self isNavigationBarCompact]) {
        CGRect frame = self.frame;
        
        CGFloat minY = [self statusBarHeight] - CGRectGetHeight(frame);
        
        frame.origin.y = minY;
        [self setFrame:frame alpha:kNearZero animated:animated];
    }
    
    self.scrollState = GTScrollNavigationBarNone;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual:self.scrollView] && [keyPath isEqualToString:@"contentOffset"]) {
        [self handleScrollViewDidScroll:self.scrollView];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - notifications
- (void)statusBarOrientationDidChange
{
    [self resetToDefaultPositionWithAnimation:NO];
}

- (void)applicationDidBecomeActive
{
    [self resetToDefaultPositionWithAnimation:NO];
}

#pragma mark - Scrolling

#define kScrollThreshold 0.0f

- (void)handleScrollViewDidScroll:(UIScrollView *)scrollView {
    
    CGFloat contentOffsetY = scrollView.contentOffset.y;
    
    // Don't try to scroll navigation bar if there's not enough room
    if (scrollView.bounds.size.height >= scrollView.contentSize.height ) {
        if (contentOffsetY >= (scrollView.contentSize.height - scrollView.frame.size.height) &&
            self.isNavigationBarCompact) {
            self.scrollState = GTScrollNavigationBarScrollingUp;
        } else {
            [self resetToDefaultPositionWithAnimation:YES];
        }
        return;
    }
    
    if (contentOffsetY < (kScrollThreshold - scrollView.contentInset.top) && self.isNavigationBarCompact) {
        [self resetToDefaultPositionWithAnimation:YES];
        return;
    } else if (contentOffsetY < (kScrollThreshold - scrollView.contentInset.top)) {
        self.lastContentOffsetY = contentOffsetY;
        return;
    } // If we exceed the height of content with a vertical bounce, do nothing
    else if ( contentOffsetY > (scrollView.contentSize.height - scrollView.frame.size.height) ) {
        self.lastContentOffsetY = scrollView.contentSize.height - scrollView.frame.size.height;
        if (self.isNavigationBarCompact) {
            self.scrollState = GTScrollNavigationBarScrollingUp;
        }
        return;
    }
    
    CGFloat deltaY = contentOffsetY - self.lastContentOffsetY;
    if (deltaY < 0.0f) {
        self.scrollState = GTScrollNavigationBarScrollingDown;
    } else if (deltaY > 0.0f) {
        self.scrollState = GTScrollNavigationBarScrollingUp;
    }
    
    CGRect frame = self.frame;
    CGFloat alpha = 1.0f;
    CGFloat statusBarHeight = [self statusBarHeight];
    CGFloat maxY = statusBarHeight;
    
    CGFloat minY = maxY - CGRectGetHeight(frame);
    
    frame.origin.y -= deltaY;
    frame.origin.y = MIN(maxY, MAX(frame.origin.y, minY));
    
    alpha = (frame.origin.y - (minY + statusBarHeight)) / (maxY - (minY + statusBarHeight));
    alpha = MAX(kNearZero, alpha);
    
    [self setFrame:frame alpha:alpha animated:NO];
    
    self.lastContentOffsetY = contentOffsetY;
}

- (void)finishStateTransitionIfNeeded:(UIPanGestureRecognizer *)panGesture {
    if (panGesture.state == UIGestureRecognizerStateEnded ||
        panGesture.state == UIGestureRecognizerStateCancelled) {
        
        CGRect frame = self.frame;
        CGFloat alpha = 1.0f;
        CGFloat statusBarHeight = [self statusBarHeight];
        CGFloat maxY = statusBarHeight;
        CGFloat minY = maxY - CGRectGetHeight(frame);
        
        CGFloat contentOffsetYDelta = 0.0f;
        if (self.scrollState == GTScrollNavigationBarScrollingDown ||
            self.scrollView.contentOffset.y < (kScrollThreshold - self.scrollView.contentInset.top)) {
            
            contentOffsetYDelta = maxY - frame.origin.y;
            frame.origin.y = maxY;
            alpha = 1.0f;
        }
        else if (self.scrollState == GTScrollNavigationBarScrollingUp) {
            contentOffsetYDelta = minY - frame.origin.y;
            frame.origin.y = minY;
            alpha = kNearZero;
        }
        
        [self setFrame:frame alpha:alpha animated:YES];
        
        if (!self.scrollView.decelerating && !self.translucent) {
            CGPoint newContentOffset = CGPointMake(self.scrollView.contentOffset.x,
                                                   self.scrollView.contentOffset.y - contentOffsetYDelta);
            [self.scrollView setContentOffset:newContentOffset animated:YES];
        }
    }
}

#pragma mark - helper methods
- (CGFloat)statusBarHeight
{
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    
    return MIN(statusBarFrame.size.height, statusBarFrame.size.width);
}

- (void)setFrame:(CGRect)frame alpha:(CGFloat)alpha animated:(BOOL)animated
{
    if (animated) {
        [UIView beginAnimations:@"GTScrollNavigationBarAnimation" context:nil];
    }
    
    float statusBarHeight = [self statusBarHeight];
    
    frame.origin.x = 0.0f;
    if (frame.origin.y > statusBarHeight) {
        frame.origin.y = statusBarHeight;
    } else if (frame.origin.y < statusBarHeight - frame.size.height) {
        frame.origin.y = statusBarHeight - frame.size.height;
    }
    
    CGFloat offsetY = CGRectGetMinY(frame) - CGRectGetMinY(self.frame);
    
    for (UIView* view in self.subviews) {
        bool isBackgroundView = view == [self.subviews objectAtIndex:0];
        bool isViewHidden = view.hidden || view.alpha == 0.0f;
        if (isBackgroundView || isViewHidden)
            continue;
        view.alpha = alpha;
    }
    self.frame = frame;
    
    if (!self.translucent) {
        CGRect parentViewFrame = self.scrollView.superview.frame;
        parentViewFrame.origin.y += offsetY;
        parentViewFrame.size.height -= offsetY;
        self.scrollView.superview.frame = parentViewFrame;
    }
    
    CGRect backgroundViewRect = self.bounds;
    backgroundViewRect.origin.y -= [self statusBarHeight];
    backgroundViewRect.size.height += [self statusBarHeight];
    UIView* backgroundView = self.subviews[0];
    backgroundView.frame = backgroundViewRect;
    
    if (animated) {
        [UIView commitAnimations];
    }
    
    NSDictionary *userInfo = @{GTScrollNavigationBarFrameNotificationOffsetYKey        : @(offsetY),
                               GTScrollNavigationBarFrameNotificationIsBarCondensedKey : @([self isNavigationBarCompact])};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GTScrollNavigationBarFrameNotification
                                                        object:self
                                                      userInfo:userInfo];
}

@end

@implementation UINavigationController (GTScrollNavigationBarAdditions)

@dynamic scrollNavigationBar;

- (GTScrollNavigationBar*)scrollNavigationBar
{
    return (GTScrollNavigationBar*)self.navigationBar;
}

@end
