/**
  The main texit module.
*/
module texit;

public import std.datetime.systime, arsd.simpledisplay, arsd.simpleaudio, arsd.vorbis;
import arsd.png;

/// A single tile in the world
struct Tile {
  float[3] bg = [0, 0, 0];   /// bg color
  float[3] fg = [1, 1, 1];   /// fg color
  char ch = ' '; /// character to draw

  bool opEquals(Tile t) {
    return bg == t.bg && fg == t.fg && ch == t.ch;
  }
}

private Image crop(Image img, int x, int y, int w, int h) {
  Image ret = new Image(w, h);
  for(int i = 0; i < w; i++)
    for(int j = 0; j < h; j++)
      ret.setPixel(i, j, img.getPixel(x+i, y+j));
  return ret;
}

/// Returns a charmap given a directory and a char size
bool[charSize][charSize][256] loadCharmap(int charSize)(string dir) {
  Image charmap = Image.fromMemoryImage(dir.readPng);
  bool[charSize][charSize][256] chars;
  for(int i = 0; i < 16; i++) {
    for(int j = 0; j < 16; j++) {
      Image tmp = charmap.crop(i*charSize, j*charSize, charSize, charSize);
      for(int k = 0; k < tmp.width; k++) {
        for(int l = 0; l < tmp.height; l++) {
          chars[j*16+i][k][l] = tmp.getPixel(k, l).r != 0;
        }
      }
      destroy(tmp);
    }
  }
  destroy(charmap);
  return chars;
}

/// Ease a value given an easing from https://easings.net/ and also easeLinear (which returns the given value)
pure nothrow float ease(string easing)(float x) {
  import std.math.trigonometry : sin, cos;
  import std.math.algebraic    : sqrt;
  enum float c1 = 1.70158;
  enum float c2 = c1*1.525;
  enum float c3 = c1+1;
  enum float n1 = 7.5625;
  enum float d1 = 2.75;
  static if(easing == "easeLinear")
    return x;
  else static if(easing == "easeInSine")
    return 1-cos((x*PI)/2);
  else static if(easing == "easeOutSine")
    return sin((x*PI)/2);
  else static if(easing == "easeInOutSine")
    return -(cos(PI*x)-1)/2;
  else static if(easing == "easeInCubic")
    return x^^3;
  else static if(easing == "easeOutCubic")
    return 1-(1-x)^^3;
  else static if(easing == "easeInOutCubic")
    return x < 0.5 
      ? 4*x^^3
      : 1-((-2*x+2)^^3)/2;
  else static if(easing == "easeInQuint")
    return x^^5;
  else static if(easing == "easeOutQuint")
    return 1-(1-x)^^5;
  else static if(easing == "easeInOutQuint")
    return x < 0.5 
      ? 16*x^^5
      : (1-(-2*x+2)^^5)/2;
  else static if(easing == "easeInCirc")
    return 1-sqrt(1-x^^2);
  else static if(easing == "easeOutCirc")
    return sqrt(1-(x-1)^^2);
  else static if(easing == "easeInOutCirc")
    return x < 0.5
      ? (1-sqrt(1-(2*x)^^2))/2
      : (sqrt(1-(-2*x+1)^^2)+1)/2;
  else static if(easing == "easeInQuad")
    return x^^2;
  else static if(easing == "easeOutQuad")
    return 1-(1-x)^^2;
  else static if(easing == "easeInOutQuad")
    return x < 0.5
      ? 2*x^^2
      : 1-((-2*x+2)^^2)/2;
  else static if(easing == "easeInQuart")
    return x^^4;
  else static if(easing == "easeOutQuart")
    return 1-(1-x)^^4;
  else static if(easing == "easeInOutQuart")
    return x < 0.5
      ? 8*x^^4
      : 1-((-2*x+2)^^4)/2;
  else static if(easing == "easeInExpo")
    return x == 0
      ? 0
      : 2^^(10*x-10);
  else static if(easing == "easeOutExpo")
    return x == 1
      ? 1
      : 1-2^^(-10*x);
  else static if(easing == "easeInOutExpo")
    return x == 0
      ? 0
      : x == 1
        ? 1
        : x < 0.5
          ? 2^^(20*x-10)/2
          : (2-2^^(-20*x+10))/2;
  else static if(easing == "easeInBack")
    return (c3*x^^3)-(c1*x^^2);
  else static if(easing == "easeOutBack")
    return 1+c3*(x-1)^^3+c1*(x-1)^^2;
  else static if(easing == "easeInOutBack")
    return x < 0.5
      ? ((2*x)^^2*((c2+1)*2*x-c2))/2
      : ((2*x-2)^^2*((c2+1)*(x*2-2)+c2)+2)/2;
  else static if(easing == "easeInBounce")
    return 1-ease!"easeOutBounce"(1-x);
  else static if(easing == "easeOutBounce") {
    if(x < 1/d1)
      return n1*x^^2;
    else if(x < 2/d1)
      return n1*(x -= 1.5/d1)*x+0.75;
    else if(x < 2.5/d1)
      return n1*(x -= 2.25/d1)*x+0.9375;
    else
      return n1*(x-=2.625/d1)*x+0.984375;
  }
  else static if(easing == "easeInOutBounce")
    return x < 0.5
      ? (1-ease!"easeOutBounce"(1-2*x)/2)
      : (1+ease!"easeOutBounce"(2*x-1))/2;
  else
    static assert(false, "Unknown easing "~easing);
}

alias Easing = pure float function(float);

/// Takes an easing and returns a function pointer to it
Easing easing(string s)() {
  return &(ease!s);
}

/// Simple vector struct
struct Vector {
  float x = 0;
  float y = 0;
  float z = 0;
}

Vector translation; /// How much to translate the screen by
float zoom = 1;     /// How much to zoom in/out

/// The main texit declaration
mixin template Texit(string charmap, 
    int charSize, float scale,
    int worldWidth, int worldHeight, 
    int width, int height, 
    string title) {
  // some constants so the user can access them
  enum WIDTH = width;
  enum HEIGHT = height;
  enum WORLD_WIDTH = worldWidth;
  enum WORLD_HEIGHT = worldHeight;
  SimpleWindow window;
  Tile[worldHeight][worldWidth] world; /// The world
  bool[charSize][charSize][256] chars; /// Bitmap of each character
  SysTime start; /// When the program was started
  AudioOutputThread* aot;
  float offset = 0; /// Offset to start at (NOTE: currently audio is not affected by this. You will need to cut it manually for now. Once arsd.simpleaudio adds seeking, this will no longer be neccesary.)

  /// Represents single thing that can appear or happen on the screen
  abstract class Event {
    float start; /// When the event should appear
    float end; /// When the event should disappear (set to Infinity if the event should always be active)
    bool triggered; /// Whether this event has been triggered or not yet
    struct TileChange {
      Point pos;
      Tile prev;
    }
    TileChange[] changedTiles; /// Tiles changed by this event
    this(float start, float end) {
      this.start = start;
      this.end = end;
    }

    /// Called when the event triggers
    void enable() {}

    /// Called on the last frame of the event
    void disable() {}

    /** Called every frame when the event is active. 
    
    `rel` is a value between 0 and 1, 0 being the first frame the event is visible, 1 being the last

    `abs` is the amount of seconds since enable() has been called.

    */
    void time(float rel, float abs) {}

    /// Changes the tile at (x, y) to the given tile
    void changeTile(Point p, Tile t) {
      Tile wt = world[p.x][p.y];
      if(t == wt)
        return; // no change needs to be done
      changedTiles ~= TileChange(p, wt);
      world[p.x][p.y] = t;
    }

    /// Undoes all changed tiles
    void undoChanges() {
      foreach(p; changedTiles)
        world[p.pos.x][p.pos.y] = p.prev;
    }
  }

  Event[] events; /// List of events queued

  /// Queues an event
  void queue(Event e) {
    events ~= e;
  }

  /// Plays OGG audio
  void audio(string path) {
    aot.playOgg(path);
  }

  /// Puts text onto the screen
  void puts(Event e, int x, int y, float[3] bg, float[3] fg, string text) {
    int sx = x;
    foreach(c; text) {
      if(x < 0 || y < 0 || x >= worldWidth || y >= worldHeight)
        continue;
      if(c == '\n') {
        y++;
        x = sx;
      } else {
        e.changeTile(Point(x, y), Tile(bg, fg, c));
        x++;
      }
    }
  }

  /// Simple event to place text onto the screen at a given time
  class TextEvent : Event {
    string text;
    float[3] fg = [1, 1, 1];
    float[3] bg = [0, 0, 0];
    Point pos;
    this(float start, float end, Point pos, float[3] fg, float[3] bg, string text) {
      super(start, end);
      this.text = text;
      this.fg = fg;
      this.bg = bg;
      this.pos = pos;
    }

    this(float start, float end, Point pos, string text) {
      super(start, end);
      this.pos = pos;
      this.text = text;
    }

    override void enable() {
      puts(this, pos.x, pos.y, bg, fg, text);
    }

    override void disable() {
      undoChanges();
    }
  }

  /// Types text onto the screen
  class TypeTextEvent : TextEvent {
    Easing ease;          /// Easing to use when typing the text. Default: `easeLinear`
    float typingTime = 1; /// Amount of time (seconds) to type the text
    this(float start, float end, Point pos, float[3] fg, float[3] bg, string text, Easing e = easing!"easeLinear", float typingTime = 0.5) {
      super(start, end, pos, fg, bg, text);
      ease = e;
      this.typingTime = typingTime;
    }

    this(float start, float end, Point pos, string text, Easing e = easing!"easeLinear", float typingTime = 0.5) {
      super(start, end, pos, text);
      ease = e;
      this.typingTime = typingTime;
    }

    override void enable() {}
    override void time(float rel, float abs) {
      float dif = abs-start;
      if(dif > typingTime)
        return;
      float t = ease(dif/typingTime);
      import std.math : ceil;
      int idx = cast(int)ceil(t*text.length);
      puts(this, pos.x, pos.y, bg, fg, text[0..idx]);
    }
  }

  float mapBetween(float x, float min0, float max0, float min1, float max1) {
    return (x-min0) / (max0-min0) * (max1-min1) + min1;
  }

  /// Translates the screen from an origin to a destination over an amount of time
  class TranslationEvent : Event {
    Easing ease;
    Vector origin;
    Vector dest;
    this(float start, float end, Vector origin, Vector dest, Easing e = easing!"easeLinear") {
      super(start, end);
      ease = e;
      this.origin = origin;
      this.dest = dest;
    }

    override void enable() {
      translation = origin;
    }

    override void disable() {
      translation = dest;
    }

    override void time(float rel, float abs) {
      float eased = ease(rel);
      translation.x = mapBetween(eased, 0, 1, origin.x, dest.x);
      translation.y = mapBetween(eased, 0, 1, origin.y, dest.y);
      translation.z = mapBetween(eased, 0, 1, origin.z, dest.z);
    }
  }

  /// Changes zoom level by one value to another over an amount of time
  class ZoomEvent : Event {
    Easing ease;
    float first;
    float second;
    this(float start, float end, float first, float second, Easing e = easing!"easeLinear") {
      super(start, end);
      this.first = first;
      this.second = second;
      ease = e;
    }

    override void enable() {
      zoom = first;
    }

    override void disable() {
      zoom = second;
    }

    override void time(float rel, float abs) {
      float eased = ease(rel);
      zoom = mapBetween(eased, 0, 1, first, second);
    }
  }

  void main() {
    // init audio thread
    AudioOutputThread aot_ = AudioOutputThread(true);
    aot = &aot_;
    // init translation
    translation = Vector(width/4, height/4);
    // init window
    window = new SimpleWindow(cast(int)(width*charSize*scale), cast(int)(height*charSize*scale), title, OpenGlOptions.yes, Resizability.automaticallyScaleIfPossible);
    window.redrawOpenGlScene = delegate() {
      glLoadIdentity();
      glOrtho(-width*charSize*(zoom/2), width*charSize*(zoom/2), height*charSize*(zoom/2), -height*charSize*(zoom/2), -1.0f, 1.0f);
      enum css = charSize*scale;
      glTranslatef(-translation.x*css, -translation.y*css, -translation.z*css);
      glBegin(GL_QUADS);
      // draw a giant black rectangle
      glColor3f(0, 0, 0);
      glVertex2f( -worldWidth*css,  -worldHeight*css);
      glVertex2f(2*worldWidth*css,  -worldHeight*css);
      glVertex2f(2*worldWidth*css, 2*worldHeight*css);
      glVertex2f( -worldWidth*css, 2*worldHeight*css);
      // render characters
      for(int i = 0; i < worldWidth; i++) {
        for(int j = 0; j < worldHeight; j++) {
          auto tile = world[i][j];
          auto ch = chars[tile.ch];
          float x = i*css;
          float y = j*css;
          glColor3f(tile.bg[0], tile.bg[1], tile.bg[2]);
          glVertex2f(x,     y);
          glVertex2f(x+css, y);
          glVertex2f(x+css, y+css);
          glVertex2f(x,     y+css);
          glColor3f(tile.fg[0], tile.fg[1], tile.fg[2]);
          if(tile.ch == ' ')
            continue; // no point to draw spaces, they're empty
          for(int k = 0; k < charSize; k++) {
            for(int l = 0; l < charSize; l++) {
              if(!ch[k][l])
                continue;
              float ks = k*scale;
              float ls = l*scale;
              glVertex2f(x+ks,       y+ls);
              glVertex2f(x+ks+scale, y+ls);
              glVertex2f(x+ks+scale, y+ls+scale);
              glVertex2f(x+ks,       y+ls+scale);
            }
          }
        }
      }
      glEnd();
      
    };
    // load charmap
    chars = loadCharmap!charSize(charmap);
    // set time
    start = Clock.currTime;
    // run start
    static if(__traits(compiles, setup()))
      setup();
    window.eventLoop(1, 
      delegate() {
        auto dif = Clock.currTime-start;
        float time = (dif.total!"msecs")/1000f;
        import std.stdio;
        foreach_reverse(i, evt; events) {
          if(time >= evt.start && time <= evt.end) {
            if(!evt.triggered) {
              evt.enable();
              evt.triggered = true;
            }
            float rel = (time-evt.start)/(evt.end-evt.start);
            evt.time(rel, time);
          }
          else if(time > evt.end) {
            evt.disable();
            import std.algorithm : remove;
            events = events.remove(i);
          }
        }
        static if(__traits(compiles, loop()))
          loop();
        window.redrawOpenGlSceneSoon();
      }
    );
  }
}