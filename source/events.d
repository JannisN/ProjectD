module events;

struct StaticSender(Receivers...) {
    void send(Event)(Event event) {

    }
}

//ArrayType: zb vector, oder int[] etc.
struct ArrayReceiver(ArrayType, T) {
    void receive(Event)(Event event) {

    }
}

struct LayerEvent(Event) {
    bool handled = false;
    Event event;
}

struct LayerReceiver(Receivers...) {
    void receive(Event)(Event event) {

    }
}

struct ArrayLayerReceiver(ArrayType, T) {
    void receive(Event)(Event event) {

    }
}