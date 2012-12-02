module zctx;

import std.container;

/*
@header
    The zctx class wraps 0MQ contexts. It manages open sockets in the context
    and automatically closes these before terminating the context. It provides
    a simple way to set the linger timeout on sockets, and configure contexts
    for number of I/O threads. Sets-up signal (interrupt) handling for the
    process.

    The zctx class has these main features:

    * Tracks all open sockets and automatically closes them before calling
    zmq_term(). This avoids an infinite wait on open sockets.

    * Automatically configures sockets with a ZMQ_LINGER timeout you can
    define, and which defaults to zero. The default behavior of zctx is
    therefore like 0MQ/2.0, immediate termination with loss of any pending
    messages. You can set any linger timeout you like by calling the
    zctx_set_linger() method.

    * Moves the iothreads configuration to a separate method, so that default
    usage is 1 I/O thread. Lets you configure this value.

    * Sets up signal (SIGINT and SIGTERM) handling so that blocking calls
    such as zmq_recv() and zmq_poll() will return when the user presses
    Ctrl-C.

@discuss
@end
*/

import dzmq;

//  ---------------------------------------------------------------------
//  Signal handling
//

//  This is a global variable accessible to CZMQ application code
__gshared int zctx_interrupted = 0;
version(linux) {// todo should it be Posix?
	static extern(C) void s_signal_handler (int signal_value)
	{
	    zctx_interrupted = 1;
    }
}

class ZMQContext {
private:	
    void* _context;              //  Our 0MQ context
    SList!Zocket _sockets;       //  Sockets held by this thread
    bool _main;                  //  TRUE if we're the main thread
    int _iothreads;              //  Number of IO threads, default 1
    int _linger;                 //  Linger timeout, default 0

public:
	//  --------------------------------------------------------------------------
	//  Constructor
	
	this (int threads)
	{
	    _iothreads = threads;
	    _main = true;
	
		// todo temporary
		version(linux) {// todo should it be Posix?
			import core.sys.posix.signal;
		    //  Install signal handler for SIGINT and SIGTERM
		    sigaction_t action;
		    action.sa_handler = &s_signal_handler;
		    action.sa_flags = 0;
		    sigemptyset (&action.sa_mask);
		    sigaction (SIGINT, &action, null);
		    sigaction (SIGTERM, &action, null);
		}
	}
	
	void finalize() {
		while (!_sockets.empty)
            zctx__socket_destroy (_sockets.front);
        if (_main && _context)
            zmq_term (_context);
	}
	
	//  --------------------------------------------------------------------------
	//  Destructor
	~this ()
	{
	   finalize();
	}
	
	
	//  --------------------------------------------------------------------------
	//  Create new shadow context, returns context object. Returns null if there
	//  wasn't sufficient memory available.
	
	auto
	shadow (ZMQContext ctx)
	{
	    //  Shares same 0MQ context but has its own list of sockets so that
	    //  we create, use, and destroy sockets only within a single thread.
	    auto self = new ZMQContext(1);
	    
	    self._context = ctx.zctxUnderlying();
	    self._sockets = SList!(Zocket)();
	
	    return self;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Configure number of I/O threads in context, only has effect if called
	//  before creating first socket. Default I/O threads is 1, sufficient for
	//  all except very high volume applications.
	
	@property void
	ioThreads (int iothreads)
	{
	    _iothreads = iothreads;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Configure linger timeout in msecs. Call this before destroying sockets or
	//  context. Default is no linger, i.e. any pending messages or connects will
	//  be lost.
	
	@property void
	linger (int linger)
	{
	    _linger = linger;
	}
	
	@property auto
	linger ()
	{
	    return _linger;
	}
	
	//  --------------------------------------------------------------------------
	//  Return low-level 0MQ context object
	
	void *
	zctxUnderlying ()
	{
	    return _context;
	}
	
	//  --------------------------------------------------------------------------
	//  Create a new socket within current context.
	//  Use this to get automatic management of the socket at shutdown.
	//  Note: SUB sockets do not automatically subscribe to everything; you
	//  must set filters explicitly.

	Zocket
	createSocket (int type)
	{
	    return zctx__socket_new (type);
	}
	
private:	
	//  --------------------------------------------------------------------------
	//  Create socket within this context, for CZMQ use only
	
	Zocket
	zctx__socket_new (int type)
	{
	    //  Initialize context now if necessary
	    if (!_context)
	        _context = zmq_init (_iothreads);
	    if (!_context)
	        return null;
	
	    //  Create and register socket
	    Zocket zocket = zmq_socket (_context, type);
	    if (!zocket)
	        return null;
	
	    _sockets.insertFront(zocket);
	    
	    return zocket;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Destroy socket within this context, for CZMQ use only
	
	void
	zctx__socket_destroy (Zocket zocket)
	{
	    assert (zocket);
	    zsocket_set_linger (zocket, linger);
	    zmq_close (zocket);
	    // remove zocket from list
	    auto range = find(_sockets[], zocket);
	    _sockets.linearRemove(take(range, 1));
	}
	
}	

unittest {
	import std.stdio;
	
    writef (" * zctx: ");

    //  @selftest
    //  Create and destroy a context without using it
    auto ctx = new ZMQContext (1);
    ctx.finalize();

    //  Create a context with many busy sockets, destroy it
    ctx = new ZMQContext (1);
    ctx.ioThreads (1);
    ctx.linger = 5;       //  5 msecs
    auto s1 = ctx.createSocket (ZMQ_PAIR);
    auto s2 = ctx.createSocket (ZMQ_XREQ);
    auto s3 = ctx.createSocket (ZMQ_REQ);
    auto s4 = ctx.createSocket (ZMQ_REP);
    auto s5 = ctx.createSocket (ZMQ_PUB);
    auto s6 = ctx.createSocket (ZMQ_SUB);
    zsocket_connect (s1, "tcp://127.0.0.1:5555");
    zsocket_connect (s2, "tcp://127.0.0.1:5555");
    zsocket_connect (s3, "tcp://127.0.0.1:5555");
    zsocket_connect (s4, "tcp://127.0.0.1:5555");
    zsocket_connect (s5, "tcp://127.0.0.1:5555");
    zsocket_connect (s6, "tcp://127.0.0.1:5555");
    assert (ctx.zctxUnderlying ());

    //  Everything should be cleanly closed now
    ctx.finalize ();
    //  @end

    writef ("OK\n");
}

