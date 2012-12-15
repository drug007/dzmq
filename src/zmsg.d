module zmsg;

/*  =========================================================================
    zmsg - working with multipart messages

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
    The zmsg class provides methods to send and receive multipart messages
    across 0MQ sockets. This class provides a list-like container interface,
    with methods to work with the overall container. ZMsg messages are
    composed of zero or more ZFrame frames.
@discuss
@end
*/

import dzmq;
import std.container;

//  Structure of our class

class ZMsg {
    DList!ZFrame frames;   //  List of frames
    size_t _content_size;    //  Total content size

	//  --------------------------------------------------------------------------
	//  Constructor
	
	this ()
	{
        frames = DList!ZFrame ();
        _content_size = 0;
	}
	
	private void 
	close () {
		frames.clear();
		_content_size = 0;
	}
	
	//  --------------------------------------------------------------------------
	//  Destructor
	
	~this ()
	{   
	    close();
	}




	//  --------------------------------------------------------------------------
	//  Receive message from socket, returns ZMsg object or NULL if the recv
	//  was interrupted. Does a blocking recv, if you want to not block then use
	//  the zloop class or zmq_poll to check for socket input before receiving.
	
	void recv (Zocket zocket)
	{
	    assert (zocket);
	    close();
	    while (1) {
	        auto frame = ZFrame.recvFrame (zocket);
	        if (frame is null) {
	            close ();
	            break;              //  Interrupted or terminated
	        }
	        scope(failure) {
	            close();
	        }
	        addZFrame (frame);
	        if (!frame.more)
	            break;              //  Last message frame
	    }
	}


	//  --------------------------------------------------------------------------
	//  Send message to socket, destroy after sending. If the message has no
	//  frames, sends nothing but destroys the message anyhow.
	
	void
	send (Zocket zocket)
	{
//	    assert (zocket);
//	    ZMsg *self = *self_p;
//	
//	    int rc = 0;
//	    if (self) {
//	        ZFrame *frame = cast(ZFrame *) zlist_pop (self.frames);
//	        while (frame) {
//	            rc = zframe_send (&frame, zocket,
//	                              zlist_size (self.frames)? ZFRAME_MORE: 0);
//	            if (rc != 0)
//	                break;
//	            frame = cast(ZFrame *) zlist_pop (self.frames);
//	        }
//	        zmsg_destroy (self_p);
//	    }
//	    return rc;
		
		auto r = frames[];
		while (!r.empty) {
        	auto current = r.back;
        	r.popBack();
            if (!current.send(zocket, r.empty? 0 : ZFRAME_MORE))
                break;
        }
        close();
	}
	
	
	//  --------------------------------------------------------------------------
	//  Return size of message, i.e. number of frames (0 or more).
	
	size_t
	size ()
	{
	    return walkLength (frames[]);
	}
	
	
	//  --------------------------------------------------------------------------
	//  Return size of content of message, i.e. sum of sizes of frames (0 or more).
	
	size_t
	contentSize ()
	{
	    return _content_size;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Push frame to the front of the message, i.e. before all other frames.
	//  Message takes ownership of frame, will destroy it when message is sent.
	//  Returns nothing on success, throw exception on error.
	
	void
	pushZFrame (ZFrame frame)
	{
	    assert (frame !is null);
	    frames.insertBack (frame);
	    _content_size += frame.size;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Remove first frame from message, if any. Returns frame, or NULL. Caller
	//  now owns frame and must destroy it when finished with it.
	
	ZFrame 
	popZFrame ()
	{
		if (frames.empty)
			return null;
			
	    auto frame = frames.back();
	    _content_size -= frame.size ();
	    return frame;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Add frame to the end of the message, i.e. after all other frames.
	//  Message takes ownership of frame, will destroy it when message is sent.
	//  Returns 0 on success
	
	void addZFrame (ZFrame frame)
	{
	    assert (frame);
	    _content_size += frame.size;
	    frames.insertFront(frame);
	}
	
	
	//////  --------------------------------------------------------------------------
	//////  Push block of memory to front of message, as a new frame.
	//////  Returns 0 on success, -1 on error.
	////
	////int
	////zmsg_pushmem (ZMsg *self, const void *src, size_t size)
	////{
	////    assert (self);
	////    ZFrame *frame = zframe_new (src, size);
	////    if (frame) {
	////        self->content_size += size;
	////        return zlist_push (self->frames, frame);
	////    }
	////    else
	////        return -1;
	////}
	
	
	//  --------------------------------------------------------------------------
	//  Add block of memory to the end of the message, as a new frame.
	
	void
	addMem (const ubyte[] src)
	{
	    auto frame = new ZFrame (src);
	    addZFrame(frame);
	}
	
	void
	addMem (const string src)
	{
	    addMem (cast(ubyte[]) src);
	}
	
	// todo make template
	void
	addMem (uint src)
		//if (is(typeof(T) == ulong))
	{
		addMem ( (cast(ubyte*) &src)[0..uint.sizeof] );
	}
	
	void
	addMem (ulong src)
		//if (is(typeof(T) == ulong))
	{
		addMem ( (cast(ubyte*) &src)[0..ulong.sizeof] );
	}
	
	
	//////  --------------------------------------------------------------------------
	//////  Push string as new frame to front of message
	////
	////int
	////zmsg_pushstr (ZMsg *self, const char *format, ...)
	////{
	////    assert (self);
	////    assert (format);
	////
	////    //  Format string into buffer
	////    va_list argptr;
	////    va_start (argptr, format);
	////    int size = 255 + 1;
	////    char *string = (char *) malloc (size);
	////    if (!string) {
	////        va_end (argptr);
	////        return -1;
	////    }
	////    int required = vsnprintf (string, size, format, argptr);
	////    if (required >= size) {
	////        size = required + 1;
	////        string = (char *) realloc (string, size);
	////        if (!string) {
	////            va_end (argptr);
	////            return -1;
	////        }
	////        size = vsnprintf (string, size, format, argptr);
	////    }
	////    else
	////        size = required;
	////
	////    va_end (argptr);
	////
	////    self->content_size += size;
	////    zlist_push (self->frames, zframe_new (string, size));
	////    free (string);
	////    return 0;
	////}
	////
	////
	//////  --------------------------------------------------------------------------
	//////  Push string as new frame to end of message
	////
	////int
	////zmsg_addstr (ZMsg *self, const char *format, ...)
	////{
	////    assert (self);
	////    assert (format);
	////    //  Format string into buffer
	////    va_list argptr;
	////    va_start (argptr, format);
	////    int size = 255 + 1;
	////    char *string = (char *) malloc (size);
	////    if (!string) {
	////        va_end (argptr);
	////        return -1;
	////    }
	////    int required = vsnprintf (string, size, format, argptr);
	////    if (required >= size) {
	////        size = required + 1;
	////        string = (char *) realloc (string, size);
	////        if (!string) {
	////            va_end (argptr);
	////            return -1;
	////        }
	////        size = vsnprintf (string, size, format, argptr);
	////    }
	////    else
	////        size = required;
	////
	////    va_end (argptr);
	////
	////    self->content_size += size;
	////    zlist_append (self->frames, zframe_new (string, size));
	////    free (string);
	////    return 0;
	////}
	////
	////
	//////  --------------------------------------------------------------------------
	//////  Pop frame off front of message, return as fresh string
	////
	////char *
	////zmsg_popstr (ZMsg *self)
	////{
	////    assert (self);
	////    ZFrame *frame = (ZFrame *) zlist_pop (self->frames);
	////    char *string = NULL;
	////    if (frame) {
	////        self->content_size -= zframe_size (frame);
	////        string = zframe_strdup (frame);
	////        zframe_destroy (&frame);
	////    }
	////    return string;
	////}
	//
	//
	////  --------------------------------------------------------------------------
	////  Push frame plus empty frame to front of message, before first frame.
	////  Message takes ownership of frame, will destroy it when message is sent.
	//
	//void
	//zmsg_wrap (ZMsg *self, ZFrame *frame)
	//{
	//    assert (self);
	//    assert (frame);
	//    if (zmsg_pushmem (self, "", 0) == 0)
	//        zmsg_push (self, frame);
	//}
	//
	//
	////  --------------------------------------------------------------------------
	////  Pop frame off front of message, caller now owns frame
	////  If next frame is empty, pops and destroys that empty frame.
	//
	//ZFrame *
	//zmsg_unwrap (ZMsg *self)
	//{
	//    assert (self);
	//    ZFrame *frame = zmsg_pop (self);
	//    ZFrame *empty = zmsg_first (self);
	//    if (zframe_size (empty) == 0) {
	//        empty = zmsg_pop (self);
	//        zframe_destroy (&empty);
	//    }
	//    return frame;
	//}
	//
	//
	//////  --------------------------------------------------------------------------
	//////  Remove specified frame from list, if present. Does not destroy frame.
	////
	////void
	////zmsg_remove (ZMsg *self, ZFrame *frame)
	////{
	////    assert (self);
	////    self->content_size -= zframe_size (frame);
	////    zlist_remove (self->frames, frame);
	////}
	
	
	//  --------------------------------------------------------------------------
	//  Set cursor to first frame in message. Returns frame, or NULL.
	
	@property ZFrame 
	firstZFrame ()
	{
	    //return (ZFrame *) zlist_first (self->frames);
	    if (frames.empty)
	    	return null;
	    return frames.back;
	}
	
	
	////  --------------------------------------------------------------------------
	////  Return the next frame. If there are no more frames, returns NULL. To move
	////  to the first frame call zmsg_first(). Advances the cursor.
	//
	//ZFrame *
	//zmsg_next (ZMsg *self)
	//{
	//    assert (self);
	//    return (ZFrame *) zlist_next (self->frames);
	//}
	
	
	//  --------------------------------------------------------------------------
	//  Return the last frame. If there are no frames, returns NULL.
	
	@property ZFrame
	lastZFrame ()
	{
	    //return cast(ZFrame *) zlist_last (self->frames);
	    if (frames.empty)
	    	return null;
	    return frames.front;
	}
	
	
	//////  --------------------------------------------------------------------------
	//////  Save message to an open file, return 0 if OK, else -1.
	////int
	////zmsg_save (ZMsg *self, FILE *file)
	////{
	////    assert (self);
	////    assert (file);
	////
	////    ZFrame *frame = zmsg_first (self);
	////    while (frame) {
	////        size_t frame_size = zframe_size (frame);
	////        if (fwrite (&frame_size, sizeof (frame_size), 1, file) != 1)
	////            return -1;
	////        if (fwrite (zframe_data (frame), frame_size, 1, file) != 1)
	////            return -1;
	////        frame = zmsg_next (self);
	////    }
	////    return 0;
	////}
	////
	////
	//////  --------------------------------------------------------------------------
	//////  Load/append an open file into message, create new message if
	//////  null message provided. Returns NULL if the message could not be
	//////  loaded.
	////
	////ZMsg *
	////zmsg_load (ZMsg *self, FILE *file)
	////{
	////    assert (file);
	////    if (!self)
	////        self = zmsg_new ();
	////    if (!self)
	////        return NULL;
	////
	////    while (TRUE) {
	////        size_t frame_size;
	////        size_t rc = fread (&frame_size, sizeof (frame_size), 1, file);
	////        if (rc == 1) {
	////            ZFrame *frame = zframe_new (NULL, frame_size);
	////            rc = fread (zframe_data (frame), frame_size, 1, file);
	////            if (frame_size > 0 && rc != 1)
	////                break;          //  Unable to read properly, quit
	////            zmsg_add (self, frame);
	////        }
	////        else
	////            break;              //  Unable to read properly, quit
	////    }
	////    return self;
	////}
	////
	////
	//////  --------------------------------------------------------------------------
	//////  Encode message to a new buffer, return buffer size
	////
	//////  Frame lengths are encoded as 1, 1+2, or 1+4 bytes
	//////  0..253 bytes        octet + data
	//////  254..64k-1 bytes    0xFE + 2octet + data
	//////  64k..4Gb-1 bytes    0xFF + 4octet + data
	////
	////#define ZMSG_SHORT_LEN      0xFE
	////#define ZMSG_LONG_LEN       0xFF
	////
	////size_t
	////zmsg_encode (ZMsg *self, byte **buffer)
	////{
	////    assert (self);
	////
	////    //  Calculate real size of buffer
	////    size_t buffer_size = 0;
	////    ZFrame *frame = zmsg_first (self);
	////    while (frame) {
	////        size_t frame_size = zframe_size (frame);
	////        if (frame_size < ZMSG_SHORT_LEN)
	////            buffer_size += frame_size + 1;
	////        else
	////        if (frame_size < 0x10000)
	////            buffer_size += frame_size + 3;
	////        else
	////            buffer_size += frame_size + 5;
	////        frame = zmsg_next (self);
	////    }
	////    *buffer = (byte *) malloc (buffer_size);
	////
	////    //  Encode message now
	////    byte *dest = *buffer;
	////    frame = zmsg_first (self);
	////    while (frame) {
	////        size_t frame_size = zframe_size (frame);
	////        if (frame_size < ZMSG_SHORT_LEN) {
	////            *dest++ = (byte) frame_size;
	////            memcpy (dest, zframe_data (frame), frame_size);
	////            dest += frame_size;
	////        }
	////        else
	////        if (frame_size < 0x10000) {
	////            *dest++ = ZMSG_SHORT_LEN;
	////            *dest++ = (frame_size >> 8) & 255;
	////            *dest++ =  frame_size       & 255;
	////            memcpy (dest, zframe_data (frame), frame_size);
	////            dest += frame_size;
	////        }
	////        else {
	////            *dest++ = ZMSG_LONG_LEN;
	////            *dest++ = (frame_size >> 24) & 255;
	////            *dest++ = (frame_size >> 16) & 255;
	////            *dest++ = (frame_size >>  8) & 255;
	////            *dest++ =  frame_size        & 255;
	////            memcpy (dest, zframe_data (frame), frame_size);
	////            dest += frame_size;
	////        }
	////        frame = zmsg_next (self);
	////    }
	////    assert ((dest - *buffer) == buffer_size);
	////    return buffer_size;
	////}
	////
	////
	//////  --------------------------------------------------------------------------
	//////  Decode a buffer into a new message, returns NULL if buffer is not
	//////  properly formatted or there is insufficient free memory.
	////
	////ZMsg *
	////zmsg_decode (byte *buffer, size_t buffer_size)
	////{
	////    ZMsg *self = zmsg_new ();
	////    if (!self)
	////        return NULL;
	////
	////    byte *source = buffer;
	////    byte *limit = buffer + buffer_size;
	////    while (source < limit) {
	////        size_t frame_size = *source++;
	////        if (frame_size == ZMSG_SHORT_LEN) {
	////            if (source > limit - 2) {
	////                zmsg_destroy (&self);
	////                break;
	////            }
	////            frame_size = (source [0] << 8) + source [1];
	////            source += 2;
	////        }
	////        else
	////        if (frame_size == ZMSG_LONG_LEN) {
	////            if (source > limit - 4) {
	////                zmsg_destroy (&self);
	////                break;
	////            }
	////            frame_size = (source [0] << 24)
	////                       + (source [1] << 16)
	////                       + (source [2] << 8)
	////                       +  source [3];
	////            source += 4;
	////        }
	////        if (source > limit - frame_size) {
	////            zmsg_destroy (&self);
	////            break;
	////        }
	////        ZFrame *frame = zframe_new (source, frame_size);
	////        if (frame) {
	////            if (zmsg_add (self, frame)) {
	////                zmsg_destroy (&self);
	////                break;
	////            }
	////            source += frame_size;
	////        }
	////        else {
	////            zmsg_destroy (&self);
	////            break;
	////        }
	////    }
	////    return self;
	////}
	
	
	//  --------------------------------------------------------------------------
	//  Create copy of message, as new message object
	
	ZMsg 
	dup ()
	{
	    auto frame = firstZFrame ();
	    if (frame is null)
	        return null;
	
	    auto copy = new ZMsg ();
	
	    scope(failure) {
	    	copy.close();
	    }
	    foreach(frm; frames)
	    	copy.addMem (frm.data);
	    
	    return copy;
	}
	
	
	//  --------------------------------------------------------------------------
	//  Dump message to stderr, for debugging and tracing
	//  Truncates to first 10 frames, for readability; this may be unfortunate
	//  when debugging larger and more complex messages. Perhaps a way to hide
	//  repeated lines instead?
	
	string
	dump ()
	{
	    string outtext;
	    outtext = "--------------------------------------\n";
	    
	    auto frame = firstZFrame ();
	    int frame_nbr = 0;
	    foreach (frm; frames) {
	        outtext ~= frm.toString ();
	    }
	    return outtext;
	}
	
	struct Range {
		
		private ZMsg.frames.Range _range;
		
		this (ZMsg zmsg) {
			_range = zmsg.frames[];
		}
		
		@property bool 
		empty () {
			return _range.empty;
		}
		
		void popFront () {
			_range.popFront ();
		}
		
		auto front () {
			return _range.front;
		}
	}
	
	Range opSlice () {
		return Range(this);
	}
		
};
	
unittest {
	// former selftest from czmq authors
	import std.stdio;
    bool rc = 0;
    
    auto ctx = new ZMQContext (1);

    void *output = ctx.createSocket (ZMQ_PAIR);
    assert (output);
    zsocket_bind (output, "inproc://zmsg.test");
    void *input = ctx.createSocket (ZMQ_PAIR);
    assert (input);
    zsocket_connect (input, "inproc://zmsg.test");

    //  Test send and receive of single-frame message
    auto zmsg = new ZMsg ();
    auto frame = new ZFrame ("Hello");
    zmsg.pushZFrame (frame);
    assert (zmsg.size == 1);
    assert (zmsg.contentSize == 5);
    zmsg.send (output);
//    assert (zmsg is null);

    zmsg.recv (input);
    assert (zmsg.size == 1);
    assert (zmsg.contentSize == 5);
    zmsg.close();

    //  Test send and receive of multi-frame message
    zmsg = new ZMsg ();
    zmsg.addMem ("Frame0");
    zmsg.addMem ("Frame1");
    zmsg.addMem ("Frame2");
    zmsg.addMem ("Frame3");
    zmsg.addMem ("Frame4");
    zmsg.addMem ("Frame5");
    zmsg.addMem ("Frame6");
    zmsg.addMem ("Frame7");
    zmsg.addMem ("Frame8");
    zmsg.addMem ("Frame9");
    
    auto copy = zmsg.dup ();
    //writeln(copy.size);
    //writeln(copy.contentSize);
    copy.send (output);
    zmsg.send (output);

    copy.recv (input);
    assert (copy !is null);
    assert (copy.size == 10);
    assert (copy.contentSize == 60);
    copy.close();

    zmsg.recv (input);
    assert (zmsg.size == 10);
    assert (zmsg.contentSize == 60);
    //version (verbose)
    //    writeln(zmsg.dump ());

////    //  Save to a file, read back
////    FILE *file = fopen ("zmsg.test", "w");
////    assert (file);
////    rc = zmsg_save (zmsg, file);
////    assert (rc == 0);
////    fclose (file);
////
////    file = fopen ("zmsg.test", "r");
////    rc = zmsg_save (zmsg, file);
////    assert (rc == -1);
////    fclose (file);
////    zmsg_destroy (&zmsg);
////
////    file = fopen ("zmsg.test", "r");
////    zmsg = zmsg_load (NULL, file);
////    assert (zmsg);
////    fclose (file);
////    remove ("zmsg.test");
////    assert (zmsg_size (zmsg) == 10);
////    assert (zmsg_content_size (zmsg) == 60);
////
////    //  Remove all frames except first and last
////    int frame_nbr;
////    for (frame_nbr = 0; frame_nbr < 8; frame_nbr++) {
////        zmsg_first (zmsg);
////        frame = zmsg_next (zmsg);
////        zmsg_remove (zmsg, frame);
////        zframe_destroy (&frame);
////    }
////    //  Test message frame manipulation
////    assert (zmsg_size (zmsg) == 2);
////    frame = zmsg_last (zmsg);
////    assert (zframe_streq (frame, "Frame9"));
////    assert (zmsg_content_size (zmsg) == 12);
////    frame = zframe_new ("Address", 7);
////    assert (frame);
////    zmsg_wrap (zmsg, frame);
////    assert (zmsg_size (zmsg) == 4);
////    rc = zmsg_addstr (zmsg, "Body");
////    assert (rc == 0);
////    assert (zmsg_size (zmsg) == 5);
////    frame = zmsg_unwrap (zmsg);
////    zframe_destroy (&frame);
////    assert (zmsg_size (zmsg) == 3);
////    char *body = zmsg_popstr (zmsg);
////    assert (streq (body, "Frame0"));
////    free (body);
////    zmsg_destroy (&zmsg);
////
////    //  Test encoding/decoding
////    zmsg = zmsg_new ();
////    assert (zmsg);
////    byte *blank = (byte *) zmalloc (100000);
////    assert (blank);
////    rc = zmsg_addmem (zmsg, blank, 0);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 1);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 253);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 254);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 255);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 256);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 65535);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 65536);
////    assert (rc == 0);
////    rc = zmsg_addmem (zmsg, blank, 65537);
////    assert (rc == 0);
////    free (blank);
////    assert (zmsg_size (zmsg) == 9);
////    byte *buffer;
////    size_t buffer_size = zmsg_encode (zmsg, &buffer);
////    zmsg_destroy (&zmsg);
////    zmsg = zmsg_decode (buffer, buffer_size);
////    assert (zmsg);
////    free (buffer);
////    zmsg_destroy (&zmsg);
////
    //  Now try methods on an empty message
    zmsg = new ZMsg ();
    assert (zmsg.size == 0);
    assert (zmsg.firstZFrame is null);
    assert (zmsg.lastZFrame is null);
    //assert (zmsg.nextZFrame is null);
    assert (zmsg.popZFrame is null);
    zmsg.close ();
    
    ctx.finalize ();

}

unittest {
	import std.stdio;
	// unittest from dzmq authors
	auto ctx = new ZMQContext (1);

    void *output = ctx.createSocket (ZMQ_PAIR);
    assert (output);
    zsocket_bind (output, "inproc://zmsg.test");
    void *input = ctx.createSocket (ZMQ_PAIR);
    assert (input);
    zsocket_connect (input, "inproc://zmsg.test");

    //  Test send and receive of single-frame message
    auto zmsg = new ZMsg ();
    zmsg.addMem ("Frame0");
    zmsg.addMem ("Frame1");
    zmsg.addMem ("Frame2");
    assert(zmsg.size == 3);
    assert(zmsg.contentSize == 18);
    auto frm = zmsg.popZFrame();
    assert(frm.equal (new ZFrame("Frame0")));
    
    auto range = zmsg[];
    assert (!range.empty);
    assert (range.front.equal (new ZFrame("Frame2")));
    range.popFront();
    assert (!range.empty);
    assert (range.front.equal (new ZFrame("Frame1")));
    range.popFront();
    assert (!range.empty);
    assert (range.front.equal (new ZFrame("Frame0")));
    range.popFront();
    assert (range.empty);
}
