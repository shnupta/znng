# znng
A wrapper around [nng](https://github.com/nanomsg/nng) in zig.

notes for me:
- zig build -Dtarget=arm-linux-gnueabihf -Dcpu=arm1176jz_s
  - works on raspberry pi zero w
  - would rather use musl based on reading but does not compile

TODO:
- include nng as a dependency in the build using zon package manager to pull it
- also make sure that if znng is included using zon then it sets up and builds correctly
- should I build the static nng lib first and then the znng, or just one single znng lib?
- build step to build demos
- step to build nng tests?
- support all nng cmake variables, do the transports and protocols first
- zig wrapper around function calls for ease of use?
- then later on maybe make a nice wrapper library to make setting up simple servers easier?
