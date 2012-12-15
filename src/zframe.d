module zframe;

/*  =========================================================================
    zframe - working with single message frames

    -------------------------------------------------------------------------
    Copyright (c) 1991-2012 iMatix Corporation <www.imatix.com>
    Copyright other contributors as noted in the AUTHORS file.

    This file is part of CZMQ, the high-level C binding for 0MQ:
    http://czmq.zeromq.org.

    This is free software; you can redistribute it and/or modify it under
    the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation; either version 3 of the License, or (at
    your option) any later version.

    This software is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this program. If not, see
    <http://www.gnu.org/licenses/>.
    =========================================================================
*/

/*
@header
    The zframe class provides methods to send and receive single message
    frames across 0MQ sockets. A 'frame' corresponds to one zmq_msg_t. When
    you read a frame from a socket, the zframe_more() method indicates if the
    frame is part of an unfinished multipart message. The zframe_send method
    normally destroys the frame, but with the ZFRAME_REUSE flag, you can send
    the same frame many times. Frames are binary, and this class has no
    special support for text data.
@discuss
@end
*/

import dzmq;
import std.string;
import std.conv;

immutable ZFRAME_MORE     = 1;
immutable ZFRAME_REUSE    = 2;
immutable ZFRAME_DONTWAIT = 4;

//  Structure of our class
class ZFrame {
    zmq_msg_t _zmsg;             //  zmq_msg_t blob for frame
    bool _more;                   //  More flag, from last read
    int _zero_copy;              //  zero-copy flag
    
    private void
    init(const ubyte[] initializator){
    	zmq_msg_init_size (&_zmsg, initializator.length);
	    data[0..$] = initializator; 
    }
    
    private void
    init(){
    	zmq_msg_init (&_zmsg); 
    }
    
    //  --------------------------------------------------------------------------
	//  Constructor; if data is not empty copies data into frame else just initializes
	// 	frame.
	
	this (const ubyte[] data)
	{
	    if (!data.empty) {
	        init(data);
	    }
	    else
	        init();
	}
	
	this (string data)
	{
		this(cast(ubyte[]) data);
	}

	//////  --------------------------------------------------------------------------
	//////  Constructor; Allows zero-copy semantics.
	//////  Zero-copy frame is initialised if data != NULL, size > 0, free_fn != 0
	//////  'arg' is a void pointer that is passed to free_fn as second argument
	////
	////ZFrame *
	////zframe_new_zero_copy (void *data, size_t size, zframe_free_fn *free_fn, void *arg)
	////{
	////    ZFrame
	////        *self;
	////
	////    self = (ZFrame *) zmalloc (sizeof (ZFrame));
	////    if (!self)
	////        return NULL;
	////
	////    if (size) {
	////        if (data && free_fn) {
	////            zmq_msg_init_data (&self.zmsg, data, size, free_fn, arg);
	////            self.zero_copy = 1;
	////        }
	////        else
	////            zmq_msg_init_size (&self.zmsg, size);
	////    }
	////    else
	////        zmq_msg_init (&self.zmsg);
	////
	////    return self;
	////}
	
	//  --------------------------------------------------------------------------
	//  Finalizer?
	private void
	close ()
	{
	    zmq_msg_close (&_zmsg);
	}
	
	//  --------------------------------------------------------------------------
	//  Destructor
	~this () {
		close();
	}
	
	
	
	//  --------------------------------------------------------------------------
	//  Receive frame from socket, returns true or false if the recv
	//  was interrupted. Does a blocking recv, if you want to not block then use
	//  zframe_recv_nowait().
	
	bool
	recv (void *zocket)
	{
	    assert (zocket);
	    close();
	    zmq_msg_init (&_zmsg);
        if (zmq_recvmsg (zocket, &_zmsg, 0) < 0) {
            close ();
            return false;            //  Interrupted or terminated
        }
        _more = (zsocket_rcvmore (zocket) != 0);
	    return true;
	}
	
	/// \todo transfer this to ZSocket class/structure
	//  --------------------------------------------------------------------------
	//  Receive frame from socket, returns ZFrame object or NULL if the recv
	//  was interrupted. Does a blocking recv, if you want to not block then use
	//  zframe_recv_nowait().
	
	static ZFrame
	recvFrame (void *zocket)
	{
	    assert (zocket);
	    auto self = new ZFrame(cast(ubyte[]) null);
        if (!self.recv (zocket)) {
            self.close ();
            return null;            //  Interrupted or terminated
        }
        return self;
	}
	
	//////  --------------------------------------------------------------------------
	//////  Receive a new frame off the socket. Returns newly allocated frame, or
	//////  NULL if there was no input waiting, or if the read was interrupted.
	////
	////ZFrame *
	////zframe_recv_nowait (void *zocket)
	////{
	////    assert (zocket);
	////    ZFrame *self = zframe_new (NULL, 0);
	////    if (self) {
	////        if (zmq_recvmsg (zocket, &self.zmsg, ZMQ_DONTWAIT) < 0) {
	////            zframe_destroy (&self);
	////            return NULL;            //  Interrupted or terminated
	////        }
	////        self.more = zsocket_rcvmore (zocket);
	////    }
	////    return self;
	////}
	
	
	//  --------------------------------------------------------------------------
	//  Send frame to socket, destroy after sending unless ZFRAME_REUSE is
	//  set or the attempt to send the message errors out. Returns true on success
	//  and false else.
	
	bool
	send (void *zocket, int flags)
	{
	    assert (zocket);
	    
        int snd_flags = (flags & ZFRAME_MORE)? ZMQ_SNDMORE: 0;
        snd_flags |= (flags & ZFRAME_DONTWAIT)? ZMQ_DONTWAIT: 0;
        if (flags & ZFRAME_REUSE) {
            zmq_msg_t copy;
            zmq_msg_init (&copy);
            if (zmq_msg_copy (&copy, &_zmsg))
                return false;
            if (zmq_sendmsg (zocket, &copy, snd_flags) == -1)
                return false;
            zmq_msg_close (&copy);
        }
        else {
            if (zmq_sendmsg (zocket, &_zmsg, snd_flags) == -1)
                return false;
            close();
        }
	        
	    return true;
	}
	
	//  --------------------------------------------------------------------------
	//  Return size of frame.
	
	size_t
	size ()
	{
	    return zmq_msg_size (&_zmsg);
	}
	
	
	//  --------------------------------------------------------------------------
	//  Return frame data.
	
	@property ubyte[]
	data ()
	{
	    return (cast(ubyte*) zmq_msg_data (&_zmsg))[0..size];
	}
	
	
	//  --------------------------------------------------------------------------
	//  Create a new frame that duplicates an existing frame
	
	ZFrame
	dup ()
	{
	    return new ZFrame (data);
	}
	
	
	//  --------------------------------------------------------------------------
	//  Return frame data encoded as printable hex string, useful for 0MQ UUIDs.
	
	string
	strhex ()
	{
	    static const char
	        hex_char [] = "0123456789ABCDEF";
	
	    auto size = size;
	    auto data = data;
	    ubyte[] hex_str;
	    hex_str.length = (size * 2);
	
	    uint byte_nbr;
	    for (byte_nbr = 0; byte_nbr < size; byte_nbr++) {
	        hex_str [byte_nbr * 2 + 0] = hex_char [data [byte_nbr] >> 4];
	        hex_str [byte_nbr * 2 + 1] = hex_char [data [byte_nbr] & 15];
	    }
	    return cast(string) hex_str;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Return copy of frame data
	
	string
	strdup ()
	{
	    return cast(string) data.dup;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Return true if frame body is equal to array
	
	bool
	equal (const ubyte[] array)
	{
	    if (data[] == array[])
	        return true;
	    else
	        return false;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Return true if frame has MORE indicator equals to 1 or false if MORE indicator is 0),
	//  set when reading frame from socket
	
	@property bool
	more ()
	{
	    return _more;
	}
	
	////// --------------------------------------------------------------------------
	////// Return frame zero copy indicator (1 or 0)
	////
	////int
	////zframe_zero_copy (ZFrame *self)
	////{
	////    assert (self);
	////    return self.zero_copy;
	////}
	
	
	//  --------------------------------------------------------------------------
	//  Return TRUE if two frames have identical size and data
	
	bool
	equal (ZFrame other)
	{
	    if (data[] == other.data[])
	        return true;
	    else
	        return false;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Print contents of frame to stderr, prefix is ignored if null.
	
	string
	toString ()
	{
		auto length = size;
	
	    string outtext;
	    int is_bin = 0;
	    uint char_nbr;
	    for (char_nbr = 0; char_nbr < length; char_nbr++)
	        if (data [char_nbr] < 9 || data [char_nbr] > 127)
	            is_bin = 1;
	
	    outtext = format ("[%03d] ", length);
	    size_t max_length = is_bin? 35: 70;
	    string elipsis = "";
	    if (length > max_length) {
	        length = max_length;
	        elipsis = "...";
	    }
	    for (char_nbr = 0; char_nbr < length; char_nbr++) {
	        if (is_bin)
	            outtext ~= xformat( "%02X", cast(char) data [char_nbr]);
	        else
	            outtext ~= xformat ( "%c", cast(char) data [char_nbr]);
	    }
	    outtext ~= format ("%s\n", elipsis);
	    return outtext;
	}

	//  --------------------------------------------------------------------------
	//  Set new contents for frame
	
	void
	reset (const ubyte[] data)
	{
	    close();
	    init(data);
	}
	
	void
	reset (string data){
		reset(cast(ubyte[]) data);
	}
	
};

unittest {
	//  --------------------------------------------------------------------------
	
//	static void
//	s_test_free_cb (void[] data, void *arg)
//	{
//	    char[1024] cmp_buf;
//	
//	    cmp_buf[] = 'A';
//	
//	    assert ( data[] == cmp_buf[]);
//	}
	
	bool rc;

    auto ctx = new ZMQContext (1);

    void *output = ctx.createSocket (ZMQ_PAIR);
    assert (output);
    zsocket_bind (output, "inproc://zframe.test");
    void *input = ctx.createSocket (ZMQ_PAIR);
    assert (input);
    zsocket_connect (input, "inproc://zframe.test");

    //  Send five different frames, test ZFRAME_MORE
    int frame_nbr;
    for (frame_nbr = 0; frame_nbr < 5; frame_nbr++) {
        auto frame = new ZFrame ("Hello");
        rc = frame.send (output, ZFRAME_MORE);
        assert (rc);
    }
    //  Send same frame five times, test ZFRAME_REUSE
    auto frame = new ZFrame ("Hello");
    for (frame_nbr = 0; frame_nbr < 5; frame_nbr++) {
        rc = frame.send (output, ZFRAME_MORE + ZFRAME_REUSE);
        assert (rc);
    }
    
    auto copy = frame.dup ();
    assert (frame.equal (copy));
//    frame.close ();
//    assert (!frame.equal (copy));
    assert (copy.size == 5);
//    copy.close();
//    assert (!frame.equal (copy));

    //  Send END frame
    frame = new ZFrame ("NOT");
    frame.reset ("END");
    auto string = frame.strhex ();
    assert (string == "454E44");

    string = frame.strdup ();
    assert ( string == "END");
	
    rc = frame.send (output, 0);
    assert (rc);

    //  Read and count until we receive END
    frame_nbr = 0;
//    for (frame_nbr = 0;; frame_nbr++) {
//        ZFrame *frame = zframe_recv (input);
//        if (zframe_streq (frame, "END")) {
//            zframe_destroy (&frame);
//            break;
//        }
//        assert (zframe_more (frame));
//        zframe_destroy (&frame);
//    }
    
    //  Read and count until we receive END
    frame_nbr = 0;
    for (frame_nbr = 0;; frame_nbr++) {
    	auto frame2 = ZFrame.recvFrame (input);
        if (frame2.strdup == "END") {
            frame2.close ();
            break;
        }
        assert (frame2.more ());
        frame.close ();
    }
    assert (frame_nbr == 10);
//    frame = zframe_recv_nowait (input);
//    assert (frame == NULL);
//
//    // Test zero copy
//    char *buffer = cast(char *) malloc (1024);
//    int i;
//    for (i = 0; i < 1024; i++)
//        buffer [i] = 'A';
//
//    frame = zframe_new_zero_copy (buffer, 1024, s_test_free_cb, NULL);
//    ZFrame *frame_copy = zframe_dup (frame);
//
//    assert (zframe_zero_copy (frame) == 1);
//    assert (zframe_zero_copy (frame_copy) == 0);
//
//    zframe_destroy (&frame);
//    zframe_destroy (&frame_copy);

    ctx.finalize ();
}