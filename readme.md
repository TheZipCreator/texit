# Texit
Texit is a simple library for text animation, building on `arsd.simpledisplay` and `arsd.simpleaudio`.

See `source/texit/app.d` for some examples.

Videos made with Texit:
* [Do you need a VPN?](https://www.youtube.com/watch?v=fqLNxcWKSDQ)
* [tiduna,xalAn | A submission to Agma Schwa's Cursed Conlang Circus](https://www.youtube.com/watch?v=ADIleIaMdZ4)

## Known bugs
On some systems, you may get errors about forward references. This, I believe is a compiler bug. If you directly copy everything under source/* to your project instead of using texit as a dub dependency, it will compile fine, so do that if you run into this. Note that you will need to add `arsd-official:simpledisplay` and `arsd-official:png` as dependencies, and you will need to add `asound` as a library if on Linux.
