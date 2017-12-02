//
// UIScrollView+SVInfiniteScrolling.m
//
// Created by Sam Vermette on 23.04.12.
// Copyright (c) 2012 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVPullToRefresh
//

#import <QuartzCore/QuartzCore.h>
#import "UIScrollView+SVInfiniteScrolling.h"

#import <Agamotto/Agamotto.h>
#import <Stanley/Stanley.h>

static CGFloat const SVInfiniteScrollingViewHeight = 60;

@interface SVInfiniteScrollingDotView : UIView

@property (nonatomic, strong) UIColor *arrowColor;

@end


@interface SVInfiniteScrollingView ()

@property (nonatomic, copy) void (^infiniteScrollingHandler)(void);

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, readwrite) SVInfiniteScrollingState state;
@property (nonatomic, readwrite) SVInfiniteScrollingDirection direction;
@property (nonatomic, strong) NSMutableArray *viewForState;
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, readwrite) CGFloat originalBottomInset;
@property (nonatomic, readwrite) CGFloat originalTopInset;
@property (nonatomic, assign) BOOL wasTriggeredByUser;
@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, assign) CGFloat triggerOffset;

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForInfiniteScrolling;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;

- (void)addScrollViewObservers;
@end



#pragma mark - UIScrollView (SVInfiniteScrollingView)
#import <objc/runtime.h>

static char UIScrollViewInfiniteScrollingBottomView;
static char UIScrollViewInfiniteScrollingTopView;

UIEdgeInsets scrollViewOriginalContentInsets;

@interface UIScrollView ()
@property (nonatomic, strong, readwrite) SVInfiniteScrollingView *infiniteScrollingView;
@property (nonatomic, strong) SVInfiniteScrollingView *infiniteScrollingTopView;
@property (nonatomic, strong) SVInfiniteScrollingView *infiniteScrollingBottomView;
@property (nonatomic, assign) SVInfiniteScrollingDirection currentDirection;
@end

@implementation UIScrollView (SVInfiniteScrolling)

@dynamic infiniteScrollingView;
@dynamic infiniteScrollTriggerOffset;

- (void)addInfiniteScrollingWithActionHandler:(void (^)(void))actionHandler {
    [self addInfiniteScrollingWithActionHandler:actionHandler direction:SVInfiniteScrollingDirectionBottom];
}

- (void)addInfiniteScrollingWithActionHandler:(void (^)(void))actionHandler direction:(SVInfiniteScrollingDirection)direction {
    
    if(!self.infiniteScrollingView || (self.infiniteScrollingView.direction != direction)) {
        
        CGFloat yOrigin = 0;
        switch (direction) {
            case SVInfiniteScrollingDirectionBottom:
                yOrigin = self.contentSize.height;
                break;
            case SVInfiniteScrollingDirectionTop:
                yOrigin = -SVInfiniteScrollingViewHeight;
                break;
        }
        
        SVInfiniteScrollingView *view = [[SVInfiniteScrollingView alloc] initWithFrame:CGRectMake(0, yOrigin, self.bounds.size.width, SVInfiniteScrollingViewHeight)];
        view.infiniteScrollingHandler = actionHandler;
        view.scrollView = self;
        view.direction = direction;
        [self addSubview:view];
        
        view.originalBottomInset = self.contentInset.bottom;
        view.originalTopInset = self.contentInset.top;
        self.infiniteScrollingView = view;
        self.showsInfiniteScrolling = YES;
    }
}

- (void)triggerInfiniteScrolling {    
    self.infiniteScrollingView.state = SVInfiniteScrollingStateTriggered;
    [self.infiniteScrollingView startAnimating];
}

- (void)setInfiniteScrollingView:(SVInfiniteScrollingView *)infiniteScrollingView {
    [self setInfiniteScrollingView:infiniteScrollingView direction:infiniteScrollingView.direction];
}

- (SVInfiniteScrollingView *)infiniteScrollingView {
    switch (self.currentDirection) {
        case SVInfiniteScrollingDirectionTop:
            return objc_getAssociatedObject(self, &UIScrollViewInfiniteScrollingTopView);
        case SVInfiniteScrollingDirectionBottom:
        default:
            return objc_getAssociatedObject(self, &UIScrollViewInfiniteScrollingBottomView);
    }
}

- (void)setInfiniteScrollingView:(SVInfiniteScrollingView *)infiniteScrollingView direction:(SVInfiniteScrollingDirection)direction {
    self.currentDirection = direction;
    switch (direction) {
        case SVInfiniteScrollingDirectionBottom:
            self.infiniteScrollingBottomView = infiniteScrollingView;
            break;
        case SVInfiniteScrollingDirectionTop:
            self.infiniteScrollingTopView = infiniteScrollingView;
            break;
    }
}

- (SVInfiniteScrollingView *)infiniteScrollingViewForDirection:(SVInfiniteScrollingDirection)direction {
    switch (direction) {
        case SVInfiniteScrollingDirectionTop:
            return self.infiniteScrollingTopView;
        case SVInfiniteScrollingDirectionBottom:
        default:
            return self.infiniteScrollingBottomView;
    }
}

- (void)setShowsInfiniteScrolling:(BOOL)showsInfiniteScrolling {
    if (!self.infiniteScrollingView)
        return;
    
    self.infiniteScrollingView.hidden = !showsInfiniteScrolling;
    
    if(!showsInfiniteScrolling) {
        [self.infiniteScrollingView resetScrollViewContentInset];
        if (self.infiniteScrollingView.isObserving) {
            self.infiniteScrollingView.isObserving = NO;
        }
    }
    else {
        if (!self.infiniteScrollingView.isObserving) {
            [self.infiniteScrollingView addScrollViewObservers];
            [self.infiniteScrollingView setScrollViewContentInsetForInfiniteScrolling];
            self.infiniteScrollingView.isObserving = YES;
            
            [self.infiniteScrollingView setNeedsLayout];
            
            CGFloat yOrigin = 0;
            switch (self.infiniteScrollingView.direction) {
                case SVInfiniteScrollingDirectionBottom:
                    yOrigin = self.contentSize.height;
                    break;
                case SVInfiniteScrollingDirectionTop:
                    yOrigin = -SVInfiniteScrollingViewHeight;
                    break;
            }
            
            self.infiniteScrollingView.frame = CGRectMake(0, yOrigin, self.infiniteScrollingView.bounds.size.width, SVInfiniteScrollingViewHeight);
        }
    }
}

- (BOOL)showsInfiniteScrolling {
    return !self.infiniteScrollingView.hidden;
}

- (void)setInfiniteScrollTriggerOffset:(CGFloat)infiniteScrollTriggerOffset {
    if(!self.infiniteScrollingView)
        return;
    
    self.infiniteScrollingView = [self infiniteScrollingViewForDirection:SVInfiniteScrollingDirectionBottom];
    self.infiniteScrollingView.triggerOffset = infiniteScrollTriggerOffset;
}

- (void)setInfiniteScrollingBottomView:(SVInfiniteScrollingView *)infiniteScrollingBottomView {
    [self willChangeValueForKey:@"UIScrollViewInfiniteScrollingBottomView"];
    objc_setAssociatedObject(self, &UIScrollViewInfiniteScrollingBottomView, infiniteScrollingBottomView, OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"UIScrollViewInfiniteScrollingBottomView"];
}

- (SVInfiniteScrollingView *)infiniteScrollingBottomView {
    return objc_getAssociatedObject(self, &UIScrollViewInfiniteScrollingBottomView);
}

- (void)setInfiniteScrollingTopView:(SVInfiniteScrollingView *)infiniteScrollingTopView {
    [self willChangeValueForKey:@"UIScrollViewInfiniteScrollingTopView"];
    objc_setAssociatedObject(self, &UIScrollViewInfiniteScrollingTopView, infiniteScrollingTopView, OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"UIScrollViewInfiniteScrollingTopView"];
}

- (SVInfiniteScrollingView *)infiniteScrollingTopView {
    return objc_getAssociatedObject(self, &UIScrollViewInfiniteScrollingTopView);
}

- (void)setCurrentDirection:(SVInfiniteScrollingDirection)currentDirection {
    objc_setAssociatedObject(self, @selector(currentDirection), @(currentDirection), OBJC_ASSOCIATION_ASSIGN);
}

- (SVInfiniteScrollingDirection)currentDirection {
    return [(NSNumber *)objc_getAssociatedObject(self, @selector(currentDirection)) intValue];
}

@end


#pragma mark - SVInfiniteScrollingView
@implementation SVInfiniteScrollingView

// public properties
@synthesize infiniteScrollingHandler, activityIndicatorViewStyle;

@synthesize state = _state;
@synthesize scrollView = _scrollView;
@synthesize activityIndicatorView = _activityIndicatorView;


- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        // default styling values
        self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = SVInfiniteScrollingStateStopped;
        self.enabled = YES;
        
        self.viewForState = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
    }
    
    return self;
}

- (void)layoutSubviews {
    self.activityIndicatorView.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInset {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    
    switch (self.direction) {
        case SVInfiniteScrollingDirectionBottom:
            currentInsets.bottom = self.originalBottomInset;
            break;
        case SVInfiniteScrollingDirectionTop:
            currentInsets.top = self.originalTopInset;
            break;
    }
    
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInsetForInfiniteScrolling {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    
    switch (self.direction) {
        case SVInfiniteScrollingDirectionBottom:
            currentInsets.bottom = self.originalBottomInset + SVInfiniteScrollingViewHeight;
            break;
        case SVInfiniteScrollingDirectionTop:
            currentInsets.top = self.originalTopInset + SVInfiniteScrollingViewHeight;
            break;
    }
    
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset {
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                     }
                     completion:NULL];
}

#pragma mark - Observing
- (void)addScrollViewObservers {
    [self.scrollView KAG_addObserverForKeyPaths:@[@kstKeypath(self.scrollView,contentOffset), @kstKeypath(self.scrollView,contentSize)] options:NSKeyValueObservingOptionNew block:^(NSString * _Nonnull keyPath, id  _Nullable value, NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change) {
        if([keyPath isEqualToString:@kstKeypath(self.scrollView,contentOffset)]) {
            CGPoint newPoint = [[change valueForKey:NSKeyValueChangeNewKey] CGPointValue];
            switch (self.direction) {
                case SVInfiniteScrollingDirectionBottom: {
                    // only scrolls when pulling up
                    if(newPoint.y >= 0)
                        [self scrollViewDidScroll:newPoint];
                    break;
                }
                case SVInfiniteScrollingDirectionTop: {
                    if(newPoint.y < 0)
                        [self scrollViewDidScroll:newPoint];
                    break;
                }
                default:
                    break;
            }
        } else if([keyPath isEqualToString:@kstKeypath(self.scrollView,contentSize)]) {
            [self layoutSubviews];
            
            CGFloat yOrigin = 0;
            switch (self.direction) {
                case SVInfiniteScrollingDirectionBottom:
                    yOrigin = self.scrollView.contentSize.height;
                    break;
                case SVInfiniteScrollingDirectionTop:
                    yOrigin = -SVInfiniteScrollingViewHeight;
                    break;
            }
            
            self.frame = CGRectMake(0, yOrigin, self.bounds.size.width, SVInfiniteScrollingViewHeight);
        }
    }];
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    if(self.state != SVInfiniteScrollingStateLoading && self.enabled) {
        
        CGFloat scrollOffsetThreshold = 0;
        switch (self.direction) {
            case SVInfiniteScrollingDirectionBottom:
                scrollOffsetThreshold = self.scrollView.contentSize.height-self.scrollView.bounds.size.height-self.triggerOffset;
                break;
            case SVInfiniteScrollingDirectionTop:
                scrollOffsetThreshold = MAX(0.0, self.frame.origin.y-self.originalTopInset);
                break;
        }
        
        if(!self.scrollView.isDragging && self.state == SVInfiniteScrollingStateTriggered)
            self.state = SVInfiniteScrollingStateLoading;
        else if(contentOffset.y > scrollOffsetThreshold && self.state == SVInfiniteScrollingStateStopped && self.scrollView.isDragging && self.direction == SVInfiniteScrollingDirectionBottom)
            self.state = SVInfiniteScrollingStateTriggered;
        else if(contentOffset.y < scrollOffsetThreshold  && self.state != SVInfiniteScrollingStateStopped && self.direction == SVInfiniteScrollingDirectionBottom)
            self.state = SVInfiniteScrollingStateStopped;
        else if(contentOffset.y < scrollOffsetThreshold && self.state == SVInfiniteScrollingStateStopped && self.scrollView.isDragging && self.direction == SVInfiniteScrollingDirectionTop)
            self.state = SVInfiniteScrollingStateTriggered;
        else if(contentOffset.y > scrollOffsetThreshold  && self.state != SVInfiniteScrollingStateStopped && self.direction == SVInfiniteScrollingDirectionTop)
            self.state = SVInfiniteScrollingStateStopped;
    }
}

#pragma mark - Getters

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityIndicatorView.activityIndicatorViewStyle;
}

#pragma mark - Setters

- (void)setCustomView:(UIView *)view forState:(SVInfiniteScrollingState)state {
    id viewPlaceholder = view;
    
    if(!viewPlaceholder)
        viewPlaceholder = @"";
    
    if(state == SVInfiniteScrollingStateAll)
        [self.viewForState replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[viewPlaceholder, viewPlaceholder, viewPlaceholder]];
    else
        [self.viewForState replaceObjectAtIndex:state withObject:viewPlaceholder];
    
    self.state = self.state;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
}

#pragma mark -

- (void)triggerRefresh {
    self.state = SVInfiniteScrollingStateTriggered;
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)startAnimating{
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)stopAnimating {
    self.state = SVInfiniteScrollingStateStopped;
}

- (void)setState:(SVInfiniteScrollingState)newState {
    
    if(_state == newState)
        return;
    
    SVInfiniteScrollingState previousState = _state;
    _state = newState;
    
    for(id otherView in self.viewForState) {
        if([otherView isKindOfClass:[UIView class]])
            [otherView removeFromSuperview];
    }
    
    id customView = [self.viewForState objectAtIndex:newState];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    
    if(hasCustomView) {
        [self addSubview:customView];
        CGRect viewBounds = [customView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [customView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    }
    else {
        CGRect viewBounds = [self.activityIndicatorView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [self.activityIndicatorView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
        
        switch (newState) {
            case SVInfiniteScrollingStateStopped:
                [self resetScrollViewContentInset];
                [self.activityIndicatorView stopAnimating];
                break;
                
            case SVInfiniteScrollingStateTriggered:
                [self setScrollViewContentInsetForInfiniteScrolling];
                [self.activityIndicatorView startAnimating];
                break;
                
            case SVInfiniteScrollingStateLoading:
                [self.activityIndicatorView startAnimating];
                break;
        }
    }
    
    // Sets the current direction
    self.scrollView.currentDirection = self.direction;
    
    if(previousState == SVInfiniteScrollingStateTriggered && newState == SVInfiniteScrollingStateLoading && self.infiniteScrollingHandler && self.enabled)
        self.infiniteScrollingHandler();
}

@end
