#import "ASTGestureHandler.h"
#import <QuartzCore/QuartzCore.h>

@interface ASTGestureHandler ()
@property (nonatomic, retain) UIView *pieceForReset;

@end



@implementation ASTGestureHandler{

}

#pragma mark - Utility methods

/**
 Scale and rotation transforms are applied relative to the layer's anchor point this method moves a gesture recognizer's view's anchor point between the user's fingers.
 */
- (void)adjustAnchorPointForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        UIView *piece = gestureRecognizer.view;
        CGPoint locationInView = [gestureRecognizer locationInView:piece];
        CGPoint locationInSuperview = [gestureRecognizer locationInView:piece.superview];
        
        piece.layer.anchorPoint = CGPointMake(locationInView.x / piece.bounds.size.width, locationInView.y / piece.bounds.size.height);
        piece.center = locationInSuperview;
    }
}


/**
 Display a menu with a single item to allow the piece's transform to be reset.
 */
- (void)showResetMenu:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        NSLog(@"lock_TWEAK | show menu");
        [self.delegate becomeFirstResponder];
        self.pieceForReset = [gestureRecognizer view];
        
        /*
         Set up the reset menu.
         */
        NSString *menuItemTitle = NSLocalizedString(@"Reset", @"Reset menu item title");
        UIMenuItem *resetMenuItem = [[UIMenuItem alloc] initWithTitle:menuItemTitle action:@selector(resetPiece:)];
        
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        [menuController setMenuItems:@[resetMenuItem]];
        
        CGPoint location = [gestureRecognizer locationInView:[gestureRecognizer view]];
        CGRect menuLocation = CGRectMake(location.x, location.y, 0, 0);
        [menuController setTargetRect:menuLocation inView:[gestureRecognizer view]];
        
        [menuController setMenuVisible:YES animated:YES];
    }
}


/**
 Animate back to the default anchor point and transform.
 */
- (void)resetPiece:(UIMenuController *)controller
{
    UIView *pieceForReset = self.pieceForReset;
    
    CGPoint centerPoint = CGPointMake(CGRectGetMidX(pieceForReset.bounds), CGRectGetMidY(pieceForReset.bounds));
    CGPoint locationInSuperview = [pieceForReset convertPoint:centerPoint toView:[pieceForReset superview]];
    
    [[pieceForReset layer] setAnchorPoint:CGPointMake(0.5, 0.5)];
    [pieceForReset setCenter:locationInSuperview];
    
    [UIView beginAnimations:nil context:nil];
    [pieceForReset setTransform:CGAffineTransformIdentity];
    [UIView commitAnimations];
}

#pragma mark - Creating Gestures

-(UIPanGestureRecognizer *) delegatedPanGestureRecognizer{
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]
                                          initWithTarget:self
                                          action:@selector(panPiece:)];
    panGesture.delegate = self;
    return panGesture;
}

-(UIRotationGestureRecognizer *) delegatedRotationGestureRecognizer{
    UIRotationGestureRecognizer *rotateGesture = [[UIRotationGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(rotatePiece:)];
    rotateGesture.delegate = self;
    return rotateGesture;
}

-(UIPinchGestureRecognizer *) delegatedPinchGestureRecognizer{
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
                                              initWithTarget:self
                                              action:@selector(scalePiece:)];
    pinchGesture.delegate = self;
    return pinchGesture;
}

-(UILongPressGestureRecognizer *) delegatedMenuGestureRecognizer{
    UILongPressGestureRecognizer *menuGesture = [[UILongPressGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(showResetMenu:)];
    //menuGesture.delegate = self;
    return menuGesture;
}


#pragma mark - Touch handling

/**
 Shift the piece's center by the pan amount.
 Reset the gesture recognizer's translation to {0, 0} after applying so the next callback is a delta from the current position.
 */
- (void)panPiece:(UIPanGestureRecognizer *)gestureRecognizer
{
    UIView *piece = [gestureRecognizer view];
    
    [self adjustAnchorPointForGestureRecognizer:gestureRecognizer];
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan || [gestureRecognizer state] == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gestureRecognizer translationInView:[piece superview]];
        
        [piece setCenter:CGPointMake([piece center].x + translation.x, [piece center].y + translation.y)];
        [gestureRecognizer setTranslation:CGPointZero inView:[piece superview]];
    }
}


/**
 Rotate the piece by the current rotation.
 Reset the gesture recognizer's rotation to 0 after applying so the next callback is a delta from the current rotation.
 */
- (void)rotatePiece:(UIRotationGestureRecognizer *)gestureRecognizer
{
    [self adjustAnchorPointForGestureRecognizer:gestureRecognizer];
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan || [gestureRecognizer state] == UIGestureRecognizerStateChanged) {
        [gestureRecognizer view].transform = CGAffineTransformRotate([[gestureRecognizer view] transform], [gestureRecognizer rotation]);
        [gestureRecognizer setRotation:0];
    }
}


/**
 Scale the piece by the current scale.
 Reset the gesture recognizer's rotation to 0 after applying so the next callback is a delta from the current scale.
 */
- (void)scalePiece:(UIPinchGestureRecognizer *)gestureRecognizer
{
    [self adjustAnchorPointForGestureRecognizer:gestureRecognizer];
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan || [gestureRecognizer state] == UIGestureRecognizerStateChanged) {
        [gestureRecognizer view].transform = CGAffineTransformScale([[gestureRecognizer view] transform], [gestureRecognizer scale], [gestureRecognizer scale]);
        [gestureRecognizer setScale:1];
    }
}


/**
 Ensure that the pinch, pan and rotate gesture recognizers on a particular view can all recognize simultaneously.
 Prevent other gesture recognizers from recognizing simultaneously.
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // If the gesture recognizers are on different views, don't allow simultaneous recognition.
    if (gestureRecognizer.view != otherGestureRecognizer.view) {
        return NO;
    }
    
    // If either of the gesture recognizers is the long press, don't allow simultaneous recognition.
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return NO;
    }
    
    return YES;
}
@end