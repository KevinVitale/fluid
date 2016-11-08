//
//  HelloWorldLayer.m
//  fluid
//
//  Created by Kevin Vitale on 4/28/11.
//  Copyright Domino's Pizza 2011. All rights reserved.
//

// Import the interfaces
#import "HelloWorldScene.h"
#import "CCTouchDispatcher.h"

/* macros */

#define IX(i,j) ((i)+(N+2)*(j))

/* external definitions (from solver.c) */

extern void dens_step ( int N, float * x, float * x0, float * u, float * v, float diff, float dt );
extern void vel_step ( int N, float * u, float * v, float * u0, float * v0, float visc, float dt );

/* global variables */

static int N;
static float dt, diff, visc;
static float force, source;
static int dvel;

static float * u, * v, * u_prev, * v_prev;
static float * dens, * dens_prev;
static float * all_Verts, * all_Colors;
static GLubyte * all_Indices;

static int win_x, win_y;
static int omx, omy, mx, my;

/*
 ----------------------------------------------------------------------
 free/clear/allocate simulation data
 ----------------------------------------------------------------------
 */


static void free_data ( void ) {
	if ( u ) free ( u );
	if ( v ) free ( v );
	if ( u_prev ) free ( u_prev );
	if ( v_prev ) free ( v_prev );
	if ( dens ) free ( dens );
	if ( dens_prev ) free ( dens_prev );
	if ( all_Verts ) free ( all_Verts );
	if ( all_Indices ) free ( all_Indices) ;
	if ( all_Colors ) free ( all_Colors );
}

static void clear_data ( void ) {
	int i, size = (N+2)*(N+2), vertSize = ((N * N) * 12), indexSize = ((N * N) * 6), colorSize = ((N * N) * 28);
	
	for ( i=0 ; i<size ; i++ ) {
		u[i] = v[i] = u_prev[i] = v_prev[i] = dens[i] = dens_prev[i] = 0.0f;
	}
	
	for ( i=0 ; i<vertSize ; i++ ) {
		all_Verts[i] = 0.f;
	}
	for ( i=0 ; i<indexSize ; i++ ) {
		all_Indices[i] = 0.f;
	}
	for ( i=0 ; i<colorSize ; i++ ) {
		all_Colors[i] = 0.f;
	}	
}

static int allocate_data ( void ) {
	int size = (N+2)*(N+2), vertSize = ((N * N) * 12), indexSize = ((N * N) * 6), colorSize = ((N * N) * 28);
	
	u			= (float *) malloc ( size*sizeof(float) );
	v			= (float *) malloc ( size*sizeof(float) );
	u_prev		= (float *) malloc ( size*sizeof(float) );
	v_prev		= (float *) malloc ( size*sizeof(float) );
	dens		= (float *) malloc ( size*sizeof(float) );	
	dens_prev	= (float *) malloc ( size*sizeof(float) );
	all_Verts	= (float *) malloc ( vertSize*sizeof(float) );
	all_Indices = (float *) malloc ( indexSize*sizeof(GLubyte) );
	all_Colors  = (float *) malloc ( colorSize*sizeof(float) );
	
	
	if ( !u || !v || !u_prev || !v_prev || !dens || !dens_prev ) {
		fprintf ( stderr, "cannot allocate data\n" );
		return ( 0 );
	}
	
	return ( 1 );
}

/*
 ----------------------------------------------------------------------
 OpenGL specific drawing routines
 ----------------------------------------------------------------------
 */

static void draw_velocity ( void ) {
	int i, j;
	__block float x, y, h;
	
	h = (1.0f/N);
	
	glLineWidth ( 1.0f );
	
	// Default GL states: GL_TEXTURE_2D, GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	// Needed states: GL_VERTEX_ARRAY, 
	// Unneeded states: GL_TEXTURE_2D, GL_TEXTURE_COORD_ARRAY, GL_COLOR_ARRAY	
	glDisable(GL_TEXTURE_2D);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
	
    dispatch_queue_t iQueue = dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_queue_t jQueue = dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(N+1, iQueue, ^(size_t i) {
        x = (i-0.5f)*h;
        dispatch_apply(N+1, jQueue, ^(size_t j) {
            y = (j-0.5f)*h;
			
			// Get the start-end vertices //
			CGPoint origin 		= CGPointMake(x * win_x, y * win_y);
			CGPoint destination	= CGPointMake((x+u[IX(i,j)]) * win_x, (y+v[IX(i,j)]) * win_y);
			
			ccVertex2F vertices[2] = {
				{ origin.x * CC_CONTENT_SCALE_FACTOR(), origin.y * CC_CONTENT_SCALE_FACTOR() },
				{ destination.x * CC_CONTENT_SCALE_FACTOR(), destination.y * CC_CONTENT_SCALE_FACTOR() }
			};
			
			glVertexPointer(2, GL_FLOAT, 0, vertices);	
			glDrawArrays(GL_LINES, 0, 2);
        });
    });
    
    
    /*
	for ( i=1 ; i<=N ; i++ ) {
		x = (i-0.5f)*h;
		for ( j=1 ; j<=N ; j++ ) {
			y = (j-0.5f)*h;
			
			// Get the start-end vertices //
			CGPoint origin 		= CGPointMake(x * win_x, y * win_y);
			CGPoint destination	= CGPointMake((x+u[IX(i,j)]) * win_x, (y+v[IX(i,j)]) * win_y);
			
			ccVertex2F vertices[2] = {
				{ origin.x * CC_CONTENT_SCALE_FACTOR(), origin.y * CC_CONTENT_SCALE_FACTOR() },
				{ destination.x * CC_CONTENT_SCALE_FACTOR(), destination.y * CC_CONTENT_SCALE_FACTOR() }
			};
			
			glVertexPointer(2, GL_FLOAT, 0, vertices);	
			glDrawArrays(GL_LINES, 0, 2);
		}
	}
     */
	
	// restore default state
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnable(GL_TEXTURE_2D);
}

static void draw_density ( void ) {
	
	int i, j, size = (N+2)*(N+2);
	float x, y, h, d00, d01, d10, d11;
	
	h = 1.0f/N;
	
	
	
	// Default GL states: GL_TEXTURE_2D, GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	// Needed states: GL_VERTEX_ARRAY, 
	// Unneeded states: GL_TEXTURE_2D, GL_TEXTURE_COORD_ARRAY, GL_COLOR_ARRAY	
	glDisable(GL_TEXTURE_2D);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	
	for ( i=0 ; i<size ; i++ ) {
		u_prev[i] = v_prev[i] = dens_prev[i] = 0.0f;
	}
	
	for ( i=0 ; i<=N ; i++ ) {
		x = (i-0.5f)*h;
		for ( j=0 ; j<=N ; j++ ) {
			y = (j-0.5f)*h;
			

			d00 = dens[IX(i,j)];
			d01 = dens[IX(i,j+1)];
			d10 = dens[IX(i+1,j)];
			d11 = dens[IX(i+1,j+1)];
			
			GLfloat vertices[] = {
				x * win_x, 		y * win_y, 0, 		//bottom left corner
				x * win_x, 		(y+h) * win_y, 0, 	//top left corner
				(x+h) * win_x, 	(y+h) * win_y, 0, 	//top right corner
				(x+h) * win_x, 	y * win_y, 0		// bottom right corner
			};
			
			GLfloat colors[] = {
				d00, d00, d00, 1.f,
				d01, d01, d01, 1.f,
				d11, d11, d11, 1.f,
				d10, d10, d10, 1.f,
				d01, d01, d01, 1.f,
				d11, d11, d11, 1.f,
				d10, d10, d10, 1.f
			};
			
			GLubyte indices[] = {
				0,1,2, 	// first triangle (bottom left - top left - top right)
				0,2,3	// second triangle (bottom left - top right - bottom right)
			};
			
			glVertexPointer(3, GL_FLOAT, 0, vertices);
			glColorPointer(4, GL_FLOAT, 0, colors);
			glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_BYTE, indices);
		}
	}
	
	// restore default state
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnable(GL_TEXTURE_2D);
}


// HelloWorld implementation
@implementation HelloWorld

+(id) scene {
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorld *layer = [HelloWorld node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "init" you need to initialize your instance
-(id) init {
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self = [super init] )) {
		
		[self schedule:@selector(update:) interval:(1.f/60.f)];
		self.isTouchEnabled = YES;
		
		N = 128;
		dt = 0.1f;
		diff = 0.0f;
		visc = 0.0f;
		force = 5.0f;
		source = 100.0f;
		

        /*
		N = 128;
		dt = 0.25f;
		diff = 0.00000001f;
		visc = 0.45f;
		force = 1.0f;
		source = 15.0f;
         */
		
		
		
		dvel = 1;
		
		CGSize winSize = [[CCDirector sharedDirector] winSize];
		win_x = winSize.width;
		win_y = winSize.height;
		
		if ( !allocate_data () ) {
			[self release]; return nil;
		}
		clear_data ();		
	}
	return self;
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc {
	// in case you have something to dealloc, do it in this method
	// in this particular example nothing needs to be released.
	// cocos2d will automatically release all the children (Label)
	free_data();
	
	// don't forget to call "super dealloc"
	[super dealloc];
}

// touches //
- (void) registerWithTouchDispatcher
{
	[[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

- (BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
	
	CGPoint location = [touch locationInView: [touch view]];
	
	omx = mx = location.x;
	omy = my = location.y;
	
	/*
	int i, j;
	
	i = (int)((       mx /(float)win_x)*N+1);
	j = (int)(((win_y-my)/(float)win_y)*N+1);
	
	if ( i<1 || i>N || j<1 || j>N ) return NO;
	
	
	u_prev[IX(i,j)] = force * (mx-omx);
	v_prev[IX(i,j)] = force * (omy-my);
	
	dens_prev[IX(i,j)] = source;
	 
	
	omx = mx;
	omy = my;
	 */
	
	return YES;
}
- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
	CGPoint location = [touch locationInView: [touch view]];
	
	mx = location.x;
	my = location.y;
	
	int i, j;
	
	i = (int)((       mx /(float)win_x)*N+1);
	j = (int)(((win_y-my)/(float)win_y)*N+1);
	
	if ( i<1 || i>N || j<1 || j>N ) return;
	
	
	u_prev[IX(i,j)] = force * (mx-omx);
	v_prev[IX(i,j)] = force * (omy-my);
	
	dens_prev[IX(i,j)] = source;
	
	omx = mx;
	omy = my;
}
- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
//	clear_data ();
}
- (void)ccTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event {
	
}

// draw //
- (void)draw {
	
	if(dvel) 
        draw_velocity();
    else
        draw_density();
}

// update //
- (void)update:(ccTime)deltaTime {
	
	vel_step ( N, u, v, u_prev, v_prev, visc, dt );
	dens_step ( N, dens, dens_prev, u, v, diff, dt );
	
}
@end
