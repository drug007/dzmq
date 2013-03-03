module zhelpers;

/*  =====================================================================
    zhelpers.h

    Helper header file for example applications.
    =====================================================================
*/

//  Include a bunch of headers that we will need in the examples

public import zmq;

public import std.random;
public import std.string;
import std.uuid;
import core.thread;
import std.stdio;
import std.ascii;
import std.datetime;

alias long int64_t;

//  Version checking, and patch up missing constants to match 2.1
static assert(ZMQ_VERSION_MAJOR == 3, "Please upgrade to ZeroMQ/3.2 for these examples");


//  Receive 0MQ string from socket and convert into C string
//  Caller must free returned string. Returns NULL if the context
//  is being terminated.
string
s_recv (void *socket) {
    zmq_msg_t message;
    zmq_msg_init (&message);
    int size = zmq_msg_recv (&message, socket, 0);
    if (size == -1)
        return null;
    string str;
    str.length = size;
    //memcpy (string, zmq_msg_data (&message), size);
    str = (cast(char*) zmq_msg_data (&message))[0..size].idup;
    zmq_msg_close (&message);
    return str;
}

//  Convert C string to 0MQ string and send to socket
static int
s_send (void *socket, string str) {
    zmq_msg_t message;
    zmq_msg_init_size (&message, str.length);
    //memcpy (zmq_msg_data (&message), str, str.length);
    (cast(char*) zmq_msg_data (&message))[0..str.length] = str.dup;
    int size = zmq_msg_send (&message, socket, 0);
    zmq_msg_close (&message);
    return size;
}

//  Sends string as 0MQ string, as multipart non-terminal
static int
s_sendmore (void *socket, char[] str) {
    zmq_msg_t message;
    zmq_msg_init_size (&message, str.length);
    //memcpy (zmq_msg_data (&message), string, str.length);
    (cast(char*) zmq_msg_data (&message))[0..str.length] = str.dup;
    int size = zmq_msg_send (&message, socket, ZMQ_SNDMORE);
    zmq_msg_close (&message);
    return size;
}

//  Receives all message parts from socket, prints neatly
//
static void
s_dump (void *socket)
{
    writeln ("----------------------------------------");
    while (1) {
        //  Process all parts of the message
        zmq_msg_t message;
        zmq_msg_init (&message);
        int size = zmq_msg_recv (&message, socket, 0);

        //  Dump the message as text or binary
        char *data = cast(char*) zmq_msg_data (&message);
        int is_text = 1;
        int char_nbr;
        for (char_nbr = 0; char_nbr < size; char_nbr++)
            if (!isAlpha(data [char_nbr]))
                is_text = 0;

        printf ("[%03d] ", size);
        for (char_nbr = 0; char_nbr < size; char_nbr++) {
            if (is_text)
                write ("%s", data [char_nbr]);
            else
                write ("%02X", cast(ubyte) data [char_nbr]);
        }
        writeln;

        int64_t more;           //  Multipart detection
        more = 0;
        size_t more_size = more.sizeof;
        zmq_getsockopt (socket, ZMQ_RCVMORE, &more, &more_size);
        zmq_msg_close (&message);
        if (!more)
            break;      //  Last message part
    }
}

//  Set simple random printable identity on socket
//
static void
s_set_id (void *socket)
{
    char identity [10];
    xsformat (identity, "%04X-%04X", uniform (0, 0x10000), uniform (0, 0x10000));
    zmq_setsockopt (socket, ZMQ_IDENTITY, identity.ptr, identity.length);
}


//  Sleep for a number of milliseconds
static void
s_sleep (int msecs)
{
    Thread.sleep(dur!"msecs"(msecs));
}

//  Return current system clock as milliseconds
static int64_t
s_clock ()
{
    version(Windows) {
        SYSTEMTIME st;
        GetSystemTime (&st);
        return cast(int64_t) st.wSecond * 1000 + st.wMilliseconds;
    } else {
        import core.sys.posix.sys.time;
        timeval tv;
        gettimeofday (&tv, null);
        return cast(int64_t) (tv.tv_sec * 1000 + tv.tv_usec / 1000);
    }
}

////  Print formatted string to stdout, prefixed by date/time and
////  terminated with a newline.
//
//static void
//s_console (const char *format, ...)
//{
//    time_t curtime = time (NULL);
//    struct tm *loctime = localtime (&curtime);
//    char *formatted = malloc (20);
//    strftime (formatted, 20, "%y-%m-%d %H:%M:%S ", loctime);
//    printf ("%s", formatted);
//    free (formatted);
//
//    va_list argptr;
//    va_start (argptr, format);
//    vprintf (format, argptr);
//    va_end (argptr);
//    printf ("\n");
//}
