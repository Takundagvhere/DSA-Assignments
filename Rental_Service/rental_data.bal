// In-memory stores, date helpers and seed data for the rental system.

import ballerina/time;

// ---- Stores ----------------------------------------------------------

map<Property> propertyDb = {};
map<User> userDb = {};
map<Booking> bookingDb = {};

// The temporary "booking cart" the brief describes: requests that
map<CartEntry> cartDb = {};

public type CartEntry record {|
    string cartId;
    string guestId;
    string propertyId;
    string checkInDate;
    string checkOutDate;
    int nights;
    float estimatedCost;
|};

// ---- ID generation ---------------------------------------------------

int propertyCounter = 0;
int bookingCounter = 0;
int cartCounter = 0;

function nextPropertyId() returns string {
    propertyCounter += 1;
    return string `PROP-${propertyCounter}`;
}

function nextBookingId() returns string {
    bookingCounter += 1;
    return string `BOOK-${bookingCounter}`;
}

function nextCartId() returns string {
    cartCounter += 1;
    return string `CART-${cartCounter}`;
}

// ---- Date helpers ----------------------------------------------------

const int SECONDS_PER_DAY = 86400;

// Parses "YYYY-MM-DD" into a UTC timestamp at midnight.
function parseDate(string isoDate) returns time:Utc|error {
    time:Utc|error result = time:utcFromString(isoDate + "T00:00:00.00Z");
    if result is error {
        return error("Invalid date format: '" + isoDate + "'. Expected YYYY-MM-DD.");
    }
    return result;
}

// Number of nights between two dates.
function nightsBetween(string checkIn, string checkOut) returns int|error {
    time:Utc inUtc = check parseDate(checkIn);
    time:Utc outUtc = check parseDate(checkOut);
    decimal seconds = time:utcDiffSeconds(outUtc, inUtc);
    if seconds <= 0d {
        return error("Check-out date must be after check-in date");
    }
    return <int>(seconds / <decimal>SECONDS_PER_DAY);
}

// True if [inA, outA) overlaps [inB, outB).
function datesOverlap(string inA, string outA, string inB, string outB) returns boolean {
    return inA < outB && inB < outA;
}

// An empty Property, for responses where nothing was found.
function emptyProperty() returns Property {
    return {
        property_id: "",
        host_id: "",
        name: "",
        location: "",
        region: "",
        property_type: APARTMENT,
        price_per_night: 0.0,
        status: UNAVAILABLE,
        max_guests: 0
    };
}

function emptyBooking() returns Booking {
    return {
        booking_id: "",
        property_id: "",
        guest_id: "",
        check_in_date: "",
        check_out_date: "",
        number_of_nights: 0,
        total_cost: 0.0,
        confirmed: false
    };
}

// ---- Seed data -------------------------------------------------------

function seedRentalData() {
    propertyDb["PROP-1"] = {
        property_id: "PROP-1",
        host_id: "HOST-1",
        name: "City View Apartment",
        location: "Windhoek",
        region: "Khomas",
        property_type: APARTMENT,
        price_per_night: 850.0,
        status: AVAILABLE,
        max_guests: 4
    };

    propertyDb["PROP-2"] = {
        property_id: "PROP-2",
        host_id: "HOST-1",
        name: "Coastal Guest House",
        location: "Swakopmund",
        region: "Erongo",
        property_type: GUESTHOUSE,
        price_per_night: 1200.0,
        status: AVAILABLE,
        max_guests: 6
    };

    propertyDb["PROP-3"] = {
        property_id: "PROP-3",
        host_id: "HOST-2",
        name: "Etosha Safari Lodge",
        location: "Okaukuejo",
        region: "Oshikoto",
        property_type: LODGE,
        price_per_night: 2400.0,
        status: AVAILABLE,
        max_guests: 2
    };

    propertyDb["PROP-4"] = {
        property_id: "PROP-4",
        host_id: "HOST-2",
        name: "Central Townhouse",
        location: "Windhoek",
        region: "Khomas",
        property_type: HOUSE,
        price_per_night: 1500.0,
        status: UNDER_RENOVATION,
        max_guests: 8
    };

    propertyCounter = 4;

    userDb["HOST-1"] = {user_id: "HOST-1", name: "Maria Nangolo", email: "maria@example.na", role: HOST};
    userDb["HOST-2"] = {user_id: "HOST-2", name: "Johannes Amutenya", email: "johannes@example.na", role: HOST};
    userDb["GUEST-1"] = {user_id: "GUEST-1", name: "Selma Iipinge", email: "selma@example.na", role: GUEST};
}
