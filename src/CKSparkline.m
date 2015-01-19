#import "CKSparkline.h"

@implementation CKSparkline
{
    float targetValue;
    float computedTargetValue;
    BOOL dataContainsTargetValue;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self initializeDefaults];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self initializeDefaults];
    }
    
    return self;
}

#pragma mark - View Configuration

@synthesize selected;
@synthesize lineColor;
@synthesize lineWidth;
@synthesize highlightedLineColor;
@synthesize drawPoints;
@synthesize drawArea;

- (void)initializeDefaults
{
    self.selected = NO;
    self.backgroundColor = [UIColor clearColor];
    self.lineColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    self.targetlineColor=[UIColor blackColor];
    self.highlightedLineColor = [UIColor whiteColor];
    self.lineWidth = 1.0;
    self.drawPoints = NO;
    self.drawArea = NO;
    self.drawTargetDashed=NO;
    
    dataContainsTargetValue=NO;
}

- (void)setSelected:(BOOL)isSelected
{
    selected = isSelected;    
    [self setNeedsDisplay];
}

#pragma mark - Data Management

@synthesize data;
@synthesize computedData;

- (void)setData:(NSArray *)newData
{
    
    //setData has now been modified slighly to accept an array of arrays. The first
    //object in the array needs to contain the graph data. The second item in the array should
    //be a target value.
    //We do this because if we use a property for setting the target we would always need to
    //force the user to set it before setting the data property. This is not intuitive and
    //could lead to confusion so it is better to code for an array that contains an array of data as the first
    //object and a target value as the second object. If the target object is nil is also enables
    //us to code for a target value not being present and avoid drawing a target line.
    
    CK_ARC_RELEASE(data);
    data = CK_ARC_RETAIN([newData objectAtIndex:0]);
    
    //Check to see if a target value was passed and if so, assign to class variable targetValue and update a flag indicating target is available.
    if ([newData count]==2)
    {
        dataContainsTargetValue =YES;
        targetValue = [[newData objectAtIndex:1] floatValue];
    }
    
    [self recalculateComputedData];
    [self setNeedsDisplay];
}

- (void)recalculateComputedData
{
    CGFloat max = 0.0;
    CGFloat min = FLT_MAX;
    NSMutableArray *mutableComputedData = [[NSMutableArray alloc] initWithCapacity:[self.data count]];
    
    for (NSNumber *dataValue in self.data) {
        min = MIN([dataValue floatValue], min);
        max = MAX([dataValue floatValue], max);
    }
    
    //If a target value has been specified then we should also factor this value into the min and max.
    //We can also go ahead and compute the new target value for graphing.
    
    if(dataContainsTargetValue)
    {
        min = MIN(targetValue, min);
        max = MAX(targetValue, max);
        
        computedTargetValue=(targetValue - min) / (max - min + 1.0);
    }
    
    for (NSNumber *dataValue in self.data) {
        CGFloat floatValue = ([dataValue floatValue] - min) / (max - min + 1.0);
        NSNumber *value = [[NSNumber alloc] initWithFloat:floatValue];
        
        [mutableComputedData addObject:value];
        
        CK_ARC_RELEASE(value);
    }
    
    CK_ARC_RELEASE(computedData);    
    computedData = mutableComputedData;
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    if ([self.computedData count] < 1) {
        return;
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorRef displayColor = [(self.selected ? self.highlightedLineColor : self.lineColor) CGColor];
    CGContextSetStrokeColorWithColor(context, displayColor);    
    CGContextSetLineWidth(context, self.lineWidth);
    
    [self updateBoundary];
    
    if (self.drawArea) {
        UIColor *displayColorInstance = [UIColor colorWithCGColor:displayColor];
        UIColor *areaColor = [displayColorInstance colorWithAlphaComponent:0.4];
        
        CGContextSetFillColorWithColor(context, [areaColor CGColor]);
        [self drawAreaInRect:rect withContext:context];
    }
    
    [self drawLineInRect:rect withContext:context];
    
    if(dataContainsTargetValue)
    {
        [self drawTargetLineInRect:rect withContext:context];
    }
    
    if (self.drawPoints) {
        CGContextSetFillColorWithColor(context, displayColor);
        [self drawPointsInRect:rect withContext:context];
    }
}

- (void)drawLineInRect:(CGRect)rect withContext:(CGContextRef)context
{
    CGContextSaveGState(context);
    CGContextBeginPath(context);                
    CGContextMoveToPoint(context, boundary.min.x, boundary.max.y - (boundary.max.y - boundary.min.y) * [[computedData objectAtIndex:0] floatValue]);
    
    for (int i = 1; i < [self.computedData count]; i++) {
        CGPoint point = calculatePosition(self.computedData, i, &boundary);
        CGContextAddLineToPoint(context, point.x, point.y);        
    }
    
    CGContextStrokePath(context);    
    CGContextRestoreGState(context);
}

- (void)drawTargetLineInRect:(CGRect)rect withContext:(CGContextRef)context
{
    
    static CGFloat const kDashedPhase           = (0.0f);
    static CGFloat const kDashedLinesLength[]   = {4.0f, 2.0f};
    static size_t const kDashedCount            = (2.0f);
    
    CGColorRef displayColor=[[self.targetlineColor colorWithAlphaComponent:0.7] CGColor];
    CGContextSetLineWidth(context, 0.5);
    CGContextSetStrokeColorWithColor(context, displayColor);
    
    CGContextSaveGState(context);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, boundary.min.x, boundary.max.y - (boundary.max.y - boundary.min.y) * computedTargetValue);
    
    for (int i = 1; i < [self.computedData count]; i++) {
        CGPoint point = CGPointMake(boundary.min.x + (boundary.max.x - boundary.min.x) * (i / ([data count] - 1)), boundary.max.y - (boundary.max.y - boundary.min.y) * computedTargetValue);
        CGContextAddLineToPoint(context, point.x, point.y);
    }
    
    if(self.drawTargetDashed)
    {
        CGContextSetLineDash(context, kDashedPhase, kDashedLinesLength, kDashedCount);
    }
    
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

- (void)drawAreaInRect:(CGRect)rect withContext:(CGContextRef)context
{
    CGPoint point;
    
    CGContextSaveGState(context);
    CGContextBeginPath(context);                
    CGContextMoveToPoint(context, boundary.min.x, boundary.max.y - (boundary.max.y - boundary.min.y) * [[computedData objectAtIndex:0] floatValue]);
    
    for (int i = 1; i < [self.computedData count]; i++) {
        point = calculatePosition(self.computedData, i, &boundary);
        CGContextAddLineToPoint(context, point.x, point.y);        
    }
    
    CGContextAddLineToPoint(context, point.x, CGRectGetMaxY(rect));
    CGContextAddLineToPoint(context, boundary.min.x, CGRectGetMaxY(rect));
    
    CGContextFillPath(context);
    CGContextRestoreGState(context);
}

- (void)drawPointsInRect:(CGRect)rect withContext:(CGContextRef)context
{
    CGContextSaveGState(context);
    
    CGFloat pointSize = calculatePointSize(self.lineWidth);
    
    CGContextFillEllipseInRect(context, CGRectMake(boundary.min.x - pointSize / 2.0, (boundary.max.y - (boundary.max.y - boundary.min.y) * [[computedData objectAtIndex:0] floatValue]) - pointSize / 2.0, pointSize, pointSize));
    
    for (int i = 1; i < [self.computedData count]; i++) {
        if (i == [self.computedData count] - 1) {
            CGContextSetFillColorWithColor(context, [[UIColor redColor] CGColor]);
        }
        
        CGPoint point = calculatePosition(self.computedData, i, &boundary);
        CGContextFillEllipseInRect(context, CGRectMake(point.x - pointSize / 2.0, point.y - pointSize / 2.0, pointSize, pointSize));
    }
    
    CGContextRestoreGState(context);
}

- (void)updateBoundary
{
    CGRect lineRect;
    CGFloat lineSize = self.lineWidth;
    CGFloat pointSize = calculatePointSize(lineSize);
    
    if (self.drawPoints) {
        lineRect = CGRectInset(self.bounds, lineSize / 2.0 + pointSize, lineSize / 2.0 + pointSize);
    } else {
        lineRect = CGRectInset(self.bounds, lineSize, lineSize);
    }
    
    CKBoundary lineBoundary = {
        { CGRectGetMinX(lineRect), CGRectGetMinY(lineRect) },
        { CGRectGetMaxX(lineRect), CGRectGetMaxY(lineRect) }
    };
    
    boundary = lineBoundary;
}

#pragma mark Helper Functions

static inline CGFloat calculatePointSize(CGFloat lineWidth)
{
    return lineWidth + log(20.0 * lineWidth);
}

static inline CGPoint calculatePosition(NSArray *data, int index, CKBoundary *boundary)
{
    return CGPointMake(boundary->min.x + (boundary->max.x - boundary->min.x) * ((CGFloat)index / ([data count] - 1)), boundary->max.y - (boundary->max.y - boundary->min.y) * [[data objectAtIndex:index] floatValue]);
}

#pragma mark -

- (void)dealloc
{    
#if ! __has_feature(objc_arc)
    [super dealloc];
    
    [data release];
    [computedData release];    
    [lineColor release];
    [highlightedLineColor release];
#endif
}

@end
