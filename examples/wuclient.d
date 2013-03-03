//
//  Weather update client
//  Connects SUB socket to tcp://localhost:5556
//  Collects weather updates and finds avg temp in zipcode
//
import zhelpers;
import std.stdio;
import std.conv;
import std.array;

int main (string[] args)
{
    void *context = zmq_ctx_new ();

    //  Socket to talk to server
    writeln ("Collecting updates from weather server…");
    void *subscriber = zmq_socket (context, ZMQ_SUB);
    int rc = zmq_connect (subscriber, "tcp://localhost:5556");
    assert (rc == 0);

    //  Subscribe to zipcode, default is NYC, 10001
    string filter = (args.length > 1)? args [1]: "10001 ";
    rc = zmq_setsockopt (subscriber, ZMQ_SUBSCRIBE, filter.ptr, filter.length);
    assert (rc == 0);

    //  Process 100 updates
    int update_nbr;
    long total_temp = 0;
    for (update_nbr = 0; update_nbr < 10; update_nbr++) {
        auto str = s_recv (subscriber);
        auto tokens = split(str);
        auto zipcode = to!int(tokens[0]);
        auto temperature = to!int(tokens[1]);
        auto relhumidity = to!int(tokens[2]);
        total_temp += temperature;
    }
    writefln ("Average temperature for zipcode '%s' was %s",
        filter, cast(int) (total_temp / update_nbr));

    zmq_close (subscriber);
    zmq_ctx_destroy (context);
    return 0;
}
