/**
  A few example programs using texit. Just rename this file to app.d and build with one of the follwing versions to see them
  $(LIST
    * HelloWorld
    * RandomCharacters
    * ScrollingZooming
  )
*/
module texit.app_;

import texit;

version(HelloWorld) {
  // Texit will automatically add a main to your program
  //           charmap file,         char size,  scale, world width, world height, screen width, screen height, title
  mixin Texit!("qbicfeet_10x10.png",  10,        2,     64,          32,           64,           32,            "Hello World");

  void setup() {
    // create a new "event", events have a start and end time both in seconds.
    // TextEvent draws text to the screen at the start and removes it at the end
    // using infinity here tells it to never disappear
    //                  start, end,            location,    string
    queue(new TextEvent(0,     float.infinity, Point(0, 0), "Hello, World!"));
  }
}

version(RandomCharacters) {
  mixin Texit!("qbicfeet_10x10.png", 10, 2, 64, 32, 64, 32, "Random Characters");

  void setup() {
    import std.random;
    float[3] randColor() {
      return [uniform01, uniform01, uniform01];
    }
    // loop over all characters in the world
    for(int i = 0; i < WORLD_WIDTH; i++) {
      for(int j = 0; j < WORLD_HEIGHT; j++) {
        // add a textevent for each of them
        float start = uniform01*2;
        float end = start+2+uniform01*2;
        // textevent has another constructor, allowing you to specify foreground and background colors
        // colors are represented as a float[3]
        // these text events have a non-infinity end time, so they'll disappear a bit after they appear
        queue(new TextEvent(start, end, Point(i, j), randColor, randColor, ""~cast(char)uniform(0, 255)));
      }
    }
  }
}

version(ScrollingZooming) {
  mixin Texit!("qbicfeet_10x10.png", 10, 2, 128, 64, 64, 32, "Scrolling & Zooming");

  void setup() {
    import std.random;
    // colors are represented by float[3]
    float[3] randColor() {
      return [uniform01, uniform01, uniform01];
    }
    // random string the size of WORLD_WIDTH
    string randString() {
      string s = "";
      for(int i = 0; i < WORLD_WIDTH; i++) {
        char c = cast(char)uniform(0, 255);
        s ~= c == '\n' ? ' ' : c;
      }
      return s;
    }
    Vector start = Vector(0, 0); 
    translation = start; // set initial translation without an event
    // create rows
    for(int i = 0; i < WORLD_HEIGHT; i++)
      queue(new TextEvent(0, float.infinity, Point(0, i), randColor, randColor, randString));
    // start translating & zooming at time 1
    queue(new TranslationEvent(1, 10, start, Vector(WIDTH*1.5, HEIGHT*1.5, 0), easing!"easeOutBack"));
    queue(new ZoomEvent(1, 10, 1, 4, easing!"easeInOutCubic"));
  }
}