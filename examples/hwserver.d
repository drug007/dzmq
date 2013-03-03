//
//  Hello World server
//  Binds REP socket to tcp://*:5555
//  Expects "Hello" from client, replies with "World"
//
import zmq;
import std.stdio;
import core.thread;

int main ()
{
    void *context = zmq_ctx_new ();

    //  Socket to talk to clients
    void *responder = zmq_socket (context, ZMQ_REP);
    zmq_bind (responder, "tcp://*:5555");

    while (1) {
        //  Wait for next request from client
        zmq_msg_t request;
        zmq_msg_init (&request);
        zmq_msg_recv (&request, responder, 0);
        writeln("Received Hello");
        zmq_msg_close (&request);

        //  Do some 'work'
        Thread.sleep (dur!"msecs"(1));

        //  Send reply back to client
        zmq_msg_t reply;
        zmq_msg_init_size (&reply, 5);
        (cast(char*) zmq_msg_data(&reply))[0..5] = "World";
        zmq_msg_send (&reply, responder, 0);
        zmq_msg_close (&reply);
    }
    //  We never get here but if we did, this would be how we end
    zmq_close (responder);
    zmq_ctx_destroy (context);
    return 0;
}
