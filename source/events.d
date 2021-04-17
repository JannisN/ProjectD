module events;

struct Sender(Receivers...) {
    Receivers* receivers;
    this(Receivers* receivers) {
        static foreach (i; 0..Receivers.length) {
            this.receivers[i] = receivers[i];
        }
    }
    void send(Event)(Event event) {
        static foreach (r; receivers) {
            static if (__traits(compiles, r.receive(event)))
                r.receive(event);
        }
    }
}

// man kann dies auch als runtime polymorphism benutzen. dazu einfach ein interface für einen receiver erstellen und dann zb.
// vector!Interface als ArrayType benutzen
// so ähnlich kann man dann auch runtime events erstellen

// ArrayType: zb vector<bla>, oder int[] etc.
// ArrayType kann entweder ein pointer auf ein array/vector(vector<bla>*) sein oder nicht
struct ArrayReceiver(ArrayType) {
    ArrayType receivers;
    alias arrayType this;
    this(ArrayType arrayType) {
        this.arrayType = arrayType;
    }
    void receive(Event)(Event event) {
        foreach (r; receivers) {
            r.receive(event);
        }
    }
}

struct LayerEvent(Event) {
    bool handled = false;
    Event event;
}

// receive funktionen müssen ein (ref LayerEvent event) haben
struct LayerReceiver(Receivers...) {
    Receivers* receivers;
    this(Receivers* receivers) {
        static foreach (i; 0..Receivers.length) {
            this.receivers[i] = receivers[i];
        }
    }
    void receive(Event)(LayerEvent!Event event) {
        static foreach (r; receivers) {
            static if (__traits(compiles, r.receive(event))) {
                if (event.handled == false)
                    r.receive(event);
                else
                    return;
            }
        }
    }
}

struct ArrayLayerReceiver(ArrayType) {
    ArrayType receivers;
    alias arrayType this;
    this(ArrayType arrayType) {
        this.arrayType = arrayType;
    }
    void receive(Event)(LayerEvent!Event event) {
        foreach (r; receivers) {
            if (event.handled == false)
                r.receive(event);
            else
                break;
        }
    }
}