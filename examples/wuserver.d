//
//  Weather update server
//  Binds PUB socket to tcp://*:5556
//  Publishes random weather updates
//
import zhelpers;
import std.stdio;
import std.conv;

int main ()
{
    //  Prepare our context and publisher
    void *context = zmq_ctx_new ();
    void *publisher = zmq_socket (context, ZMQ_PUB);
    int rc = zmq_bind (publisher, "tcp://*:5556");
    assert (rc == 0);
    rc = zmq_bind (publisher, "ipc://weather.ipc");
    assert (rc == 0);

    //  Initialize random number generator
    //srandom ((unsigned) time (NULL));
    while (1) {
        //  Get values that will fool the boss
        int zipcode, temperature, relhumidity;
        zipcode     = uniform (0, 100002);
        temperature = uniform (-80, 135);
        relhumidity = uniform (10, 60);

        //  Send message to all subscribers
        string update;
        //xsformat (update, "%05d %d %d", zipcode, temperature, relhumidity);
	update = to!string(zipcode) ~ " " ~ to!string(temperature) ~ " " ~ to!string(relhumidity);
	s_send (publisher, update);
    }
    zmq_close (publisher);
    zmq_ctx_destroy (context);
    return 0;
}
