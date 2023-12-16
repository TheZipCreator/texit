/**
	The main texit module.
*/
module texit;

public import std.datetime.systime, std.getopt, std.file, bindbc.sdl;
public import std.string : toStringz;
public import std.conv : to;

// things bindbc-sdl is missing
extern(C) {
	struct SDL_FRect {
		float x, y, w, h;
	}
	int SDL_RenderFillRectF(SDL_Renderer* renderer, const(SDL_FRect*) rect);
	int SDL_RenderCopyF(SDL_Renderer* renderer, SDL_Texture* texture, const(SDL_Rect*) srcrect, const(SDL_FRect*) dstrect);
}

/// A single tile in the world
struct Tile {
	float[3] bg = [0, 0, 0];	 /// bg color
	float[3] fg = [1, 1, 1];	 /// fg color
	char ch = ' '; /// character to draw

	bool opEquals(Tile t) {
		return bg == t.bg && fg == t.fg && ch == t.ch;
	}
}



/// Ease a value given an easing from https://easings.net/ and also easeLinear (which returns the given value)
pure nothrow float ease(string easing)(float x) {
	import std.math.trigonometry : sin, cos;
	import std.math.algebraic		: sqrt;
	import std.math.constants		: PI;
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
			: 1-((-2*x+2)^^5)/2;
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
	float x = 0, y = 0, z = 0;
}

/// Simple point struct
struct Point {
	int x = 0, y = 0;
}

/// Simple color struct
struct Color {
	float r = 0, g = 0, b = 0, a = 0;

	SDL_Color toSDL() {
		return SDL_Color(cast(ubyte)(r*255), cast(ubyte)(g*255), cast(ubyte)(b*255), cast(ubyte)(a*255));
	}
}

Vector translation; /// How much to translate the screen by
float zoom = 1;		 /// How much to zoom in/out
	
/// An exception with SDL
class SDLException : Exception {
	this(string msg) {
		super(msg);
	}
}

/// Any other exception caused by texit
class TexitException : Exception {
	this(string msg) {
		super(msg);
	}
}

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
	alias WW = WORLD_WIDTH;
	enum WORLD_HEIGHT = worldHeight;
	alias WH = WORLD_HEIGHT;
	/// The window
	Window window;
	Tile[worldHeight][worldWidth] world; /// The world
	bool[charSize][charSize][256] chars; /// Bitmap of each character
	SysTime start; /// When the program was started
	float offset = 0; /// Offset to start at
	float endTime = float.infinity; /// Time to end at
	ulong frameCount; /// Current frame count.
	Entity[string] entities; /// Entities, indexed by ID
	/// Music being played
	Mix_Music* music = null;

	/// The window class
	class Window {
		SDL_Renderer* rend;
		SDL_Window* win;

		~this() {
			SDL_DestroyRenderer(rend);
			SDL_DestroyWindow(win);
		}
	}
	
	/// An image, backed by an SDL surface
	class Image {
		SDL_Texture* texture; /// A texture backing this image
		SDL_Surface* surface; /// The surface backing this image

		/// Creates from an SDL surface. Note that you should only handle the texture thru this class after creating it (since the texture is deleted when the GC frees the instance)
		this(SDL_Surface *surf) {
			surface = surf;
			texture = SDL_CreateTextureFromSurface(window.rend, surf);
		}

		/// Loads an image from a file
		static Image load(string file) {
			SDL_Surface* loaded = IMG_Load(file.toStringz);
			if(loaded == null)
				throw new SDLException("Could not load image file '"~file~"': "~SDL_GetError().to!string);
			scope(exit)
				SDL_FreeSurface(loaded);
			SDL_Surface* converted = SDL_ConvertSurfaceFormat(loaded, SDL_PIXELFORMAT_RGBA8888, 0);
			return new Image(converted);
		}
	
		/// Gets width
		@property int width() {
			return surface.w;
		}
		/// Gets height
		@property int height() {
			return surface.h;
		}
		/// Gets the pixels of this image
		@property Color[] pixels() {
			import std.algorithm, std.range, std.array;
			return (cast(ubyte*)surface.pixels)[0..surface.w*surface.h*4].chunks(4).map!(c => Color(c[1]/255f, c[2]/255f, c[3]/255f, c[0]/255f)).array;
		}

		/// Frees the texture
		~this() {
			SDL_FreeSurface(surface);
			SDL_DestroyTexture(texture);
		}
	}
	/// Represents single thing that can happen on the screen
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
				world[p.pos.x][p.pos.y] = Tile([0, 0, 0], [0, 0, 0], ' ');
			// foreach(p; changedTiles)
			//	 world[p.pos.x][p.pos.y] = p.prev;
		}
	}

	Event[] events; /// List of events queued

	/// Queues an event
	void queue(T...)(T evts) {
		static foreach(e; evts) {
			static assert(is(typeof(e) : Event), "Only events can be queued!");
			if(offset >= e.end) {
				e.disable();
				return;
			}
			if(offset >= e.start) {
				e.enable();
				e.triggered = true;
			}
			events ~= e;
		}
	}

	/// Plays OGG audio
	void audio(string path) {
		if(doRender)
			return; // don't play audio if we're rendering
		if(music != null)
			return; // audio already playing
		music = Mix_LoadMUS(path.toStringz);
		if(music == null)
			throw new SDLException("Could not load audio: "~SDL_GetError().to!string);
		if(Mix_PlayMusic(music, 1) < 0)
			throw new SDLException("Could not play music: "~SDL_GetError().to!string);
		Mix_SetMusicPosition(offset);
	}

	/// Puts text onto the screen
	void puts(bool hasEvent)(Event e, int x, int y, float[3] bg, float[3] fg, string text, bool replace) {
		int sx = x;
		foreach(char c; text) {
			switch(c) {
				case '\n':
					y++;
					x = sx;
					break;
				case '\r':
					break; // grrr windows
				default:
					if(x < 0 || y < 0 || x >= worldWidth || y >= worldHeight)
						continue;
					static if(hasEvent) {
						if(replace || world[x][y].ch == ' ')
							e.changeTile(Point(x, y), Tile(bg, fg, c));
					} else {
						if(replace || world[x][y].ch == ' ')
							world[x][y] = Tile(bg, fg, c);
					}
					x++;
					break;
			}
		}
	}

	/// Puts text with an event
	void puts(Event e, int x, int y, float[3] bg, float[3] fg, string text, bool replace) {
		puts!true(e, x, y, bg, fg, text, replace);
	}

	/// Puts text without an event
	void puts(int x, int y, float[3] bg, float[3] fg, string text, bool replace) {
		puts!false(null, x, y, bg, fg, text, replace);
	}

	/// Simple event to place text onto the screen at a given time
	class TextEvent : Event {
		string text;
		float[3] fg = [1, 1, 1];
		float[3] bg = [0, 0, 0];
		Point pos;
		bool replace;
		this(float start, float end, Point pos, float[3] fg, float[3] bg, string text, bool replace = true) {
			super(start, end);
			this.text = text;
			this.fg = fg;
			this.bg = bg;
			this.pos = pos;
			this.replace = replace;
		}

		this(float start, float end, Point pos, float[3] fg, string text, bool replace = true) {
			super(start, end);
			this.text = text;
			this.fg = fg;
			this.pos = pos;
			this.replace = replace;
		}

		this(float start, float end, Point pos, string text, bool replace = true) {
			super(start, end);
			this.pos = pos;
			this.text = text;
			this.replace = replace;
		}

		override void enable() {
			puts(this, pos.x, pos.y, bg, fg, text, replace);
		}

		override void disable() {
			undoChanges();
		}
	}

	/// Types text onto the screen. Doesn't play well with easings that go backwards (easeBack, easeBounce)
	class TypeTextEvent : TextEvent {
		Easing ease;					/// Easing to use when typing the text. Default: `easeLinear`
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
			puts(this, pos.x, pos.y, bg, fg, text[0..idx], replace);
		}
	}

	/// Flashing text.
	class FlashingTextEvent : TextEvent {
		float flashPeriod = 0.5; /// Period of flashing (in seconds)
		float[3] fg2; /// Second foreground color
		float[3] bg2; /// Second background color
		this(float start, float end, Point pos, float[3] fg, float[3] bg, float[3] fg2, float[3] bg2, string text, float flashPeriod = 0.5) {
			super(start, end, pos, fg, bg, text);
			this.fg2 = fg2;
			this.bg2 = bg2;
			this.flashPeriod = flashPeriod;
		}

		override void time(float rel, float abs) {
			float dif = abs-start;
			if(dif%(flashPeriod*2) < flashPeriod)
				puts(pos.x, pos.y, bg, fg, text, replace);
			else
				puts(pos.x, pos.y, bg2, fg2, text, replace);
		}
	}

	/// Creates a box using the +, -, and | characters
	class BoxEvent : Event {
		Point tl; /// Top left
		Point br; /// Bottom right
		float[3] fg = [1, 1, 1]; /// Foreground color
		float[3] bg = [0, 0, 0]; /// Background color
		this(float start, float end, Point topleft, Point bottomright, float[3] fg, float[3] bg) {
			super(start, end);
			this.tl = topleft;
			this.br = bottomright;
			this.fg = fg;
			this.bg = bg;
		}

		this(float start, float end, Point topleft, Point bottomright, float[3] fg) {
			super(start, end);
			this.tl = topleft;
			this.br = bottomright;
			this.fg = fg;
			this.bg = bg;
		}

		override void enable() {
			string rep(string s, int n) {
				import std.array : appender;
				auto ap = appender!string;
				for(int i = 0; i < n; i++)
					ap ~= s;
				return ap[];
			}
			import std.stdio;
			puts(this, tl.x+1, tl.y, bg, fg, rep("-", br.x-tl.x-1), true);
			puts(this, tl.x+1, br.y, bg, fg, rep("-", br.x-tl.x-1), true);
			puts(this, tl.x, tl.y+1, bg, fg, rep("|\n", br.y-tl.y-1), true);
			puts(this, br.x, tl.y+1, bg, fg, rep("|\n", br.y-tl.y-1), true);
			puts(this, tl.x, tl.y, bg, fg, "+", true);
			puts(this, tl.x, br.y, bg, fg, "+", true);
			puts(this, br.x, tl.y, bg, fg, "+", true);
			puts(this, br.x, br.y, bg, fg, "+", true);
		}

		override void disable() {
			undoChanges();
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

		static Vector prevDest; /// The last constructed TranslationEvent's destination

		this(float start, float end, Vector origin, Vector dest, Easing e = easing!"easeLinear") {
			super(start, end);
			ease = e;
			this.origin = origin;
			this.dest = dest;
			prevDest = dest;
		}

		/// Origin is assumed to be `prevDest`
		this(float start, float end, Vector dest, Easing e = easing!"easeLinear") {
			super(start, end);
			ease = e;
			this.origin = prevDest;
			this.dest = dest;
			prevDest = dest;
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
		}
	}

	/// Changes zoom level by one value to another over an amount of time
	class ZoomEvent : Event {
		Easing ease;
		float first;
		float second;

		static float prevSecond; /// Second of the last constructed ZoomEvent

		/// 
		this(float start, float end, float first, float second, Easing e = easing!"easeLinear") {
			super(start, end);
			this.first = first;
			this.second = second;
			prevSecond = second;
			ease = e;
		}
		
		/// First is assumed to be prevSecond
		this(float start, float end, float second, Easing e = easing!"easeLinear") {
			super(start, end);
			this.first = prevSecond;
			this.second = second;
			prevSecond = second;
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
	
	/// Anything that isn't text
	abstract class Entity {
		string id; /// Unique ID of this entity
		Vector pos, size; /// Position and size of the entity
		bool visible = false; /// Whether this entity is visible right now or not

		/// Generates an ID (they look like entity-0, entity-1, entity-2, entity-3, etc)
		static string generateID() {
			static uint last = 0;
			return "entity-"~((last++).to!string);
		}
		
		///
		this(Vector pos, Vector size, string id = generateID()) {
			this.pos = pos;
			this.size = size;
			this.id = id;
			if(id in entities)
				throw new TexitException("There already exists an entity with ID '"~id~"'.");
			entities[id] = this;
		}

		/// Shows the entity
		void show() {
			visible = true;
		}
		
		/// Hides the entity
		void hide() {
			visible = false;
		}
		
		/// Call this to render the entity
		final void render() {
			if(!visible)
				return;
			const float sc = (scale*2)/zoom; // SDL2's pixel I think is twice as small as openGL's, so that's why the 2 is here
			const float css = charSize*sc;
			const float tx = css*(zoom*width/4-translation.x), ty = css*sc*(zoom*height/4-translation.y);
			Vector spos = Vector(pos.x*css+tx, pos.y*css+ty);
			Vector ssize = Vector(size.x*css, size.y*css);
			render(spos, ssize);
		}
		/// Rendering code (this is what should be overriden)
		void render(Vector spos, Vector ssize) {}
	}

	/// An image entity
	class ImageEntity : Entity {
		Image img; /// The image
		
		private final Vector getSize() {
			return Vector(img.width/(charSize*scale*2), img.height/(charSize*scale*2));
		}

		this(Vector pos, Image img) {
			this.img = img;
			super(pos, getSize());
		}

		this(Vector pos, string id, Image img) {
			this.img = img;
			super(pos, getSize(), id);
		}
		
		this(Vector pos, string filename) {
			this.img = Image.load(filename);
			super(pos, getSize());
		}

		this(Vector pos, string id, string filename) {
			this.img = Image.load(filename);
			super(pos, getSize(), id);
		}
		
		this(Vector pos, Vector size, Image img) {
			this.img = img;
			super(pos, size);
		}

		this(Vector pos, Vector size, string id, Image img) {
			this.img = img;
			super(pos, size, id);
		}
		
		this(Vector pos, Vector size, string filename) {
			this.img = Image.load(filename);
			super(pos, size);
		}

		this(Vector pos, Vector size, string id, string filename) {
			this.img = Image.load(filename);
			super(pos, size, id);
		}

		override void render(Vector spos, Vector ssize) {
			SDL_FRect dest = SDL_FRect(spos.x, spos.y, ssize.x, ssize.y);
			SDL_RenderCopyF(window.rend, img.texture, null, &dest);
		}
	}
	/// Event that creates an entity
	class EntityEvent : Event {
		Entity entity;

		this(float start, float end, Entity e) {
			super(start, end);
			entity = e;
		}

		override void enable() {
			entity.show();
		}

		override void disable() {
			entity.hide();
		}
	}
	/// Event that changes an entity's position
	class EntityTranslationEvent : Event {
		Easing ease;
		string id;
		Vector origin, dest;

		Entity entity() {
			return entities[id];
		}

		this(float start, float end, string id, Vector origin, Vector dest, Easing e = easing!"easeLinear") {
			super(start, end);
			this.id = id;
			this.origin = origin;
			this.dest = dest;
			this.ease = e;
		}

		override void enable() {
			entity.pos = origin;
		}

		override void disable() {
			entity.pos = dest;
		}

		override void time(float rel, float abs) {
			float eased = ease(rel);
			entity.pos.x = mapBetween(eased, 0, 1, origin.x, dest.x);
			entity.pos.y = mapBetween(eased, 0, 1, origin.y, dest.y);
		}
	}
	
	/// Event that changes an entity's size
	class EntityResizeEvent : Event {
		Easing ease;
		string id;
		Vector origin, dest;

		Entity entity() {
			return entities[id];
		}

		this(float start, float end, string id, Vector origin, Vector dest, Easing e = easing!"easeLinear") {
			super(start, end);
			this.id = id;
			this.origin = origin;
			this.dest = dest;
			this.ease = e;
		}

		override void enable() {
			entity.size = origin;
		}

		override void disable() {
			entity.size = dest;
		}

		override void time(float rel, float abs) {
			float eased = ease(rel);
			entity.size.x = mapBetween(eased, 0, 1, origin.x, dest.x);
			entity.size.y = mapBetween(eased, 0, 1, origin.y, dest.y);
		}
	}

	bool doRender; /// Whether to render to an image sequence
		
	/// Returns a charmap given a directory and a char size
	bool[charSize][charSize][256] loadCharmap(string path) {
		Image charmap = Image.load(path);
		int w = charmap.width, h = charmap.height;
		if(w != charSize*16 && h != charSize*16)
			throw new Exception("Charmap is incorrectly sized! Should be "~(16*charSize).to!string~"×"~(16*charSize).to!string~", but got "~w.to!string~"×"~h.to!string~".");
		Color[] pixels = charmap.pixels;
		bool[charSize][charSize][256] chars;
		// probably could be more efficient but eh
		for(int i = 0; i < 16; i++) {
			for(int j = 0; j < 16; j++) {
				for(int k = 0; k < charSize; k++) {
					for(int l = 0; l < charSize; l++) {
						import std.stdio;
						chars[j*16+i][k][l] = pixels[(j*charSize*w+i*charSize+l*w+k)].r != 0;
					}
				}
			}
		}
		return chars;
	}

	void main(string[] args) {
		{
			auto opt = getopt(args,
				"i|imagesequence", "Render to an image sequence, outputted to the directory ./images.", &doRender
			);
			if(opt.helpWanted) {
				defaultGetoptPrinter("Options:", opt.options);
				return;
			}
		}
		if(doRender) {
			if("images".exists)
				rmdirRecurse("images");
			mkdir("images");
		}
		// init SDL and stuff
		if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0)
			throw new SDLException("Could not load SDL: "~SDL_GetError().to!string);
		if(Mix_Init(MIX_INIT_OGG) < 0)
			throw new SDLException("Could not load SDL_mixer: "~SDL_GetError().to!string);
		if(Mix_OpenAudio(44100, AUDIO_S16SYS, 2, 512))
			throw new SDLException("Could not open audio: "~SDL_GetError().to!string);
		window = new Window;
		if(SDL_CreateWindowAndRenderer(cast(int)(width*charSize*scale), cast(int)(height*charSize*scale), SDL_WINDOW_SHOWN, &window.win, &window.rend) < 0)
			throw new SDLException("Could not create window or renderer: "~SDL_GetError().to!string);
		SDL_SetWindowTitle(window.win, title.toStringz);
		scope(exit)
			if(music != null)
				Mix_FreeMusic(music);
		// for convenience; the window is always going to be cleaned up after this function ends so it should be fine to do this
		SDL_Renderer* rend = window.rend;
		// init translation
		translation = Vector(width/4, height/4);
		// load charmap
		chars = loadCharmap(charmap);
		// set time
		start = Clock.currTime;
		// run start
		static if(__traits(compiles, setup()))
			setup();
		// surface to save frames to (null if not used)
		SDL_Surface* frameSurface;
		if(doRender)
			frameSurface = SDL_CreateRGBSurface(0, cast(int)(width*charSize*scale), cast(int)(height*charSize*scale), 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000);
		scope(exit)
			if(doRender)
				SDL_FreeSurface(frameSurface);
		// main loop
		outer: while(true) {
			// handle sdl events
			SDL_Event e;
			while(SDL_PollEvent(&e)) {
				switch(e.type) {
					case SDL_QUIT:
						break outer;
					default:
						break;
				}
			}
			// update other things
			auto dif = Clock.currTime-start;
			float time;
			if(!doRender)
				time = ((dif.total!"msecs")/1000f)+offset;
			else
				time = (1/30f)*frameCount;
			if(time > endTime)
				break outer;
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
			// render world
			const float sc = (scale*2)/zoom; // SDL2's pixel I think is twice as small as openGL's, so that's why the 2 is here
			const float css = charSize*sc;
			SDL_SetRenderDrawColor(rend, 0, 0, 0, 0);
			SDL_RenderClear(rend);
			// render entities first
			foreach(_, ent; entities)
				ent.render();
			const float tx = charSize*sc*(zoom*width/4-translation.x), ty = charSize*sc*(zoom*height/4-translation.y);
			for(int i = 0; i < worldWidth; i++) {
				for(int j = 0; j < worldHeight; j++) {
					auto tile = world[i][j];
					float x = i*css;
					float y = j*css;
					auto r = SDL_FRect(x+tx, y+ty, css, css);
					SDL_SetRenderDrawColor(rend, cast(ubyte)(tile.bg[0]*255), cast(ubyte)(tile.bg[1]*255), cast(ubyte)(tile.bg[2]*255), 255);
					// only render background color if it's not black
					if(tile.bg[0] != 0 || tile.bg[1] != 0 || tile.bg[2] != 0)
						SDL_RenderFillRectF(rend, &r);
					if(tile.ch == ' ')
						continue;
					auto ch = chars[tile.ch];
					SDL_SetRenderDrawColor(rend, cast(ubyte)(tile.fg[0]*255), cast(ubyte)(tile.fg[1]*255), cast(ubyte)(tile.fg[2]*255), 255);
					for(int k = 0; k < charSize; k++) {
						for(int l = 0; l < charSize; l++) {
							if(!ch[k][l])
								continue;
							r = SDL_FRect(x+k*sc+tx, y+l*sc+ty, sc, sc);
							SDL_RenderFillRectF(rend, &r);
						}
					}
				}
			}
			// create image if necessary
			if(doRender) {
				import std.format;
				SDL_RenderReadPixels(window.rend, null, SDL_PIXELFORMAT_ARGB8888, frameSurface.pixels, frameSurface.pitch);
				IMG_SavePNG(frameSurface, "./images/%08d.png".format(frameCount).toStringz);
			}
			frameCount++;
			SDL_RenderPresent(rend);
		}
		destroy(window);
		SDL_Quit();
	}
}
