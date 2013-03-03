//
//  Hello World client
//  Connects REQ socket to tcp://localhost:5555
//  Sends "Hello" to server, expects "World" back
//
import zmq;
import std.stdio;
import core.thread;

int main ()
{
    void *context = zmq_ctx_new ();

    //  Socket to talk to server
    writeln ("Connecting to hello world server…");
    void *requester = zmq_socket (context, ZMQ_REQ);
    zmq_connect (requester, "tcp://localhost:5555");

     int request_nbr;
     for (request_nbr = 0; request_nbr != 10; request_nbr++) {
         zmq_msg_t request;
         zmq_msg_init_size (&request, 5);
         //memcpy (zmq_msg_data (&request), "Hello", 5);
         (cast(char*) zmq_msg_data(&request))[0..5] = "Hello";
         write ("Sending Hello %d…\n", request_nbr);
         zmq_msg_send (&request, requester, 0);
         zmq_msg_close (&request);

         zmq_msg_t reply;
         zmq_msg_init (&reply);
         zmq_msg_recv (&reply, requester, 0);
         write ("Received World %d\n", request_nbr);
         zmq_msg_close (&reply);
     }
    Thread.sleep (dur!"msecs"(2));
    zmq_close (requester);
    zmq_ctx_destroy (context);
    return 0;
}
