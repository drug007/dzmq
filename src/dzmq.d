module dzmq;

public import zmq;

public import std.container;
public import std.algorithm;
public import std.range;

public import zctx;
//public import zloop;
public import zsocket;
public import zsockopt;
public import zstr;
public import zframe;
//public import zmsg;


alias long int64_t;


static if (ZMQ_VERSION_MAJOR == 3)
	immutable enum { ZMQ_POLL_MSEC = 1 }           //  zmq_poll is msec
else {
	static assert(false, "Unsupported version of 0MQ!");
}	
