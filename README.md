# SDL Continuous Resize

SDL is a great library that provides a cross-platform API for windowing and
event handling. Since the architectures of the platforms on which it runs are
vastly different, sometimes it has to offer a common denominator that may not
be as flexible as the API provided by the host platform.

One of these situations is related to the window resize event: from the moment a
resize operation begins until it finishes, the thread running event handling is
blocked. Since in some operating systems (macOS, for instance) event handling
has to run on the main thread (or, at least, it is recommended), single-threaded
applications will have issues: rendering will not happen until the resize is
complete, causing the content to be stretched.

SDL provides `SDL_AddEventWatch`, which receives a callback that is invoked as
soon as an event is received, providing the first step in overcoming the issue.
The problem is this function may be called in a separate thread and, since
rendering APIs are not necessarily thread-safe, crashes are easy to generate.

The solution presented in this example:

- Uses the main thread to receive events, to make sure that SDL's PumpEvents is
  called (in this case, by waitEvent). Otherwise, the `SDL_AddEventWatch` will
  never be called because the event queue will not be populated.
- Invokes `SDL_AddEventWatch` to set up a callback that receives events immediately.
- Uses a TChan for sending events from the main thread and the SDL_AddEventWatch
  callback.
- Creates a rendering thread that listens for events on a TChan (instead of the
  standard of waiting directly for `waitEvent`/`pollEvents`).

A few notes:

- `forkOS` is used instead of `forkIO`, to ensure the rendering thread always
  runs on the same OS thread. Using forkOS also means the application needs to
  be compiled with the `-threaded` flag.
- The rendering thread needs to call `SDL_GL_MakeCurrent`, otherwise, it will
  crash.
- You can use `ghcid` to test changes without recompiling.
- On Windows, you need to create two OpenGL contexts, as mentioned in
  https://skryabiin.wordpress.com/2015/04/25/hello-world/. The second context we
  create will be marked as current in the main thread, while the first context
  will be the one we keep for the rendering thread. If you don't create the
  second context, the application will crash. If you create a second context in
  macOS, the window will flicker on window resize.
