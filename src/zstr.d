//module zstr;
//
///*  =========================================================================
//    zstr - sending and receiving strings
//
//    -------------------------------------------------------------------------
//    Copyright (c) 1991-2012 iMatix Corporation <www.imatix.com>
//    Copyright other contributors as noted in the AUTHORS file.
//
//    This file is part of CZMQ, the high-level C binding for 0MQ:
//    http://czmq.zeromq.org.
//
//    This is free software; you can redistribute it and/or modify it under
//    the terms of the GNU Lesser General Public License as published by
//    the Free Software Foundation; either version 3 of the License, or (at
//    your option) any later version.
//
//    This software is distributed in the hope that it will be useful, but
//    WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//    Lesser General Public License for more details.
//
//    You should have received a copy of the GNU Lesser General Public
//    License along with this program. If not, see
//    <http://www.gnu.org/licenses/>.
//    =========================================================================
//*/
//
///*
//@header
//    The zstr class provides utility functions for sending and receiving C
//    strings across 0MQ sockets. It sends strings without a terminating null,
//    and appends a null byte on received strings. This class is for simple
//    message sending.
//@discuss
//@end
//*/
import dzmq;
import std.conv;

//  --------------------------------------------------------------------------
//  Receive C string from socket. Caller must free returned string. Returns
//  NULL if the context is being terminated or the process was interrupted.

string
zstr_recv (void *zocket)
{
    assert (zocket);
    zmq_msg_t message;
    zmq_msg_init (&message);
    if (zmq_recvmsg (zocket, &message, 0) < 0)
        return null;
        
    size_t size = zmq_msg_size (&message);
    auto str = to!string(zmq_msg_data (&message)[0..size]);
    zmq_msg_close (&message);
    return str;
}


//////  --------------------------------------------------------------------------
//////  Receive C string from socket, if socket had input ready. Caller must
//////  free returned string. Returns NULL if there was no input waiting, or if
//////  the context was terminated. Use zctx_interrupted to exit any loop that
//////  relies on this method.
////
////char *
////zstr_recv_nowait (void *zocket)
////{
////    assert (zocket);
////    zmq_msg_t message;
////    zmq_msg_init (&message);
////    if (zmq_recvmsg (zocket, &message, ZMQ_DONTWAIT) < 0)
////        return NULL;
////
////    size_t size = zmq_msg_size (&message);
////    char *string = (char *) malloc (size + 1);
////    memcpy (string, zmq_msg_data (&message), size);
////    zmq_msg_close (&message);
////    string [size] = 0;
////    return string;
////}


//  --------------------------------------------------------------------------
//  Send D string to socket. Returns 0 if successful, -1 if there was an
//  error.

int
zstr_send (void *zocket, string str)
{
    assert (zocket);

    zmq_msg_t message;
    zmq_msg_init_size (&message, str.length);
    memcpy (zmq_msg_data (&message), str.ptr, str.length);
    int rc = zmq_sendmsg (zocket, &message, 0);
    zmq_msg_close (&message);
    return rc == -1? -1: 0;
}


//  --------------------------------------------------------------------------
//  Send a string to a socket in 0MQ string format, with MORE flag
int
zstr_sendm (void *zocket, string str)
{
    assert (zocket);

    zmq_msg_t message;
    zmq_msg_init_size (&message, str.length);
    memcpy (zmq_msg_data (&message), str.ptr, str.length);
    int rc = zmq_sendmsg (zocket, &message, ZMQ_SNDMORE);
    zmq_msg_close (&message);
    return rc == -1? -1: 0;
}

////static int
////s_zstr_sendf_impl (void *zocket, bool more, const char *format, va_list argptr)
////{
////    assert (zocket);
////
////    //  Format string into buffer
////    int size = 255 + 1;
////    char *string = (char *) malloc (size);
////    int required = vsnprintf (string, size, format, argptr);
////    if (required >= size) {
////        size = required + 1;
////        string = (char *) realloc (string, size);
////        vsnprintf (string, size, format, argptr);
////    }
////
////    //  Now send formatted string
////    int rc;
////    if (more)
////        rc = zstr_sendm (zocket, string);
////    else
////        rc = zstr_send (zocket, string);
////    free (string);
////    return rc;
////}
////
//////  --------------------------------------------------------------------------
//////  Send formatted C string to socket
////int
////zstr_sendf (void *zocket, const char *format, ...)
////{
////    assert (zocket);
////
////    va_list argptr;
////    va_start (argptr, format);
////
////    int rc = s_zstr_sendf_impl (zocket, FALSE, format, argptr);
////    va_end (argptr);
////
////    return rc;
////}
////
//////  --------------------------------------------------------------------------
//////  Send formatted C string to socket with MORE flag
////int
////zstr_sendfm (void *zocket, const char *format, ...)
////{
////    assert (zocket);
////
////    va_list argptr;
////    va_start (argptr, format);
////
////    int rc = s_zstr_sendf_impl (zocket, TRUE, format, argptr);
////    va_end (argptr);
////
////    return rc;
////}
////
//////  --------------------------------------------------------------------------
//////  Selftest
////
////int
////zstr_test (bool verbose)
////{
////    printf (" * zstr: ");
////
////    //  @selftest
////    ZMQContext *ctx = zctx_new ();
////    assert (ctx);
////
////    void *output = zsocket_new (ctx, ZMQ_PAIR);
////    assert (output);
////    zsocket_bind (output, "inproc://zstr.test");
////    void *input = zsocket_new (ctx, ZMQ_PAIR);
////    assert (input);
////    zsocket_connect (input, "inproc://zstr.test");
////
////    //  Send ten strings, five strings with MORE flag and then END
////    int string_nbr;
////    for (string_nbr = 0; string_nbr < 10; string_nbr++)
////        zstr_sendf (output, "this is string %d", string_nbr);
////    for (string_nbr = 0; string_nbr < 5; string_nbr++)
////        zstr_sendfm (output, "this is string %d", string_nbr);
////    zstr_send (output, "END");
////
////    //  Read and count until we receive END
////    string_nbr = 0;
////    for (string_nbr = 0;; string_nbr++) {
////        char *string = zstr_recv (input);
////        if (streq (string, "END")) {
////            free (string);
////            break;
////        }
////        free (string);
////    }
////    assert (string_nbr == 15);
////
////    zctx_destroy (&ctx);
////    //  @end
////
////    printf ("OK\n");
////    return 0;
////}
