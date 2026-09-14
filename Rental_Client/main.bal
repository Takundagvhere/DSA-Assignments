// Command-line gRPC client; invokes all eight remote functions including both streaming types.

import ballerina/io;

configurable string serverUrl = "http://localhost:9090";

final RentalServiceClient rentalClient = check new (serverUrl);

public function main() returns error? {
    io:println("\n  Connected to " + serverUrl);

    while true {
        printMenu();
        string choice = io:readln("  Choose an option: ");

        error? result = ();

        match choice.trim() {
            "1" => { result = listProperties(); }
            "2" => { result = searchProperty(); }
            "3" => { result = addProperty(); }
            "4" => { result = updateProperty(); }
            "5" => { result = removeProperty(); }
            "6" => { result = registerUsers(); }
            "7" => { result = bookProperty(); }
            "8" => { result = confirmBooking(); }
            "9" => { result = runDemo(); }
            "0" => {
                io:println("\n  Goodbye.\n");
                return;
            }
            _ => {
                io:println("\n  !! Invalid option.");
            }
        }

        if result is error {
            io:println("\n  !! " + result.message());
        }
    }
}

function printMenu() {
    io:println("\n===================================================");
    io:println("   RENTAL ACCOMMODATION SYSTEM");
    io:println("   Ministry of Tourism");
    io:println("===================================================");
    io:println("   GUEST");
    io:println("     1. Browse available properties   (streaming)");
    io:println("     2. Search for a property by ID");
    io:println("     7. Book a property               (to cart)");
    io:println("     8. Confirm a booking");
    io:println("   HOST");
    io:println("     3. Add a property");
    io:println("     4. Update a property");
    io:println("     5. Remove a property");
    io:println("     6. Register users                (streaming)");
    io:println("   ---");
    io:println("     9. Run full demo");
    io:println("     0. Exit");
    io:println("===================================================");
}

// ---- 1. SERVER STREAMING ---------------------------------------------

function listProperties() returns error? {
    io:println("\n  Leave blank / zero for no filter.");
    string location = io:readln("  Location: ").trim();
    float minPrice = toFloat(io:readln("  Minimum price per night: "));
    float maxPrice = toFloat(io:readln("  Maximum price per night: "));

    io:println("\n--- AVAILABLE PROPERTIES ------------------------------");
    io:println("  (streamed from the server one at a time)\n");

    var propStream = check rentalClient->list_available_properties({
        location: location,
        min_price: minPrice,
        max_price: maxPrice
    });

    int count = 0;
    check propStream.forEach(function(Property p) {
        count += 1;
        io:println("  " + pad(p.property_id, 10) + pad(p.name, 30) +
                pad(p.location, 14) + pad(p.property_type, 12) +
                "N$" + p.price_per_night.toString() + "/night");
    });

    if count == 0 {
        io:println("  No properties match those filters.");
    } else {
        io:println("\n  " + count.toString() + " property(ies) streamed.");
    }
}

// ---- 2. SEARCH -------------------------------------------------------

function searchProperty() returns error? {
    string id = io:readln("\n  Property ID (e.g. PROP-1): ").trim();

    SearchPropertyResponse response = check rentalClient->search_property({property_id: id});

    io:println("\n--- SEARCH RESULT -------------------------------------");
    io:println("  " + response.message);

    if response.available {
        Property p = response.property;
        io:println("");
        io:println("  Name        : " + p.name);
        io:println("  Host        : " + p.host_id);
        io:println("  Location    : " + p.location + ", " + p.region);
        io:println("  Type        : " + p.property_type);
        io:println("  Price       : N$" + p.price_per_night.toString() + " per night");
        io:println("  Max guests  : " + p.max_guests.toString());
        io:println("  Status      : " + p.status);
    }
}

// ---- 3. ADD (Host) ---------------------------------------------------

function addProperty() returns error? {
    io:println("\n--- NEW LISTING ---------------------------------------");

    string hostId = io:readln("  Your host ID (e.g. HOST-1): ").trim();
    string name = io:readln("  Property name: ").trim();
    string location = io:readln("  Town / city: ").trim();
    string region = io:readln("  Region: ").trim();

    io:println("  Type: 1) Apartment  2) House  3) Guesthouse  4) Lodge  5) Campsite");
    PropertyType propType = toPropertyType(io:readln("  Choose 1-5: ").trim());

    float price = toFloat(io:readln("  Price per night (N$): "));
    int guests = toInt(io:readln("  Maximum guests: "));

    AddPropertyResponse response = check rentalClient->add_property({
        host_id: hostId,
        name: name,
        location: location,
        region: region,
        property_type: propType,
        price_per_night: price,
        max_guests: guests
    });

    io:println("\n  " + response.message);
    if response.success {
        io:println("  The server assigned the ID: " + response.property_id);
    }
}

// ---- 4. UPDATE (Host) ------------------------------------------------

function updateProperty() returns error? {
    string id = io:readln("\n  Property ID to update: ").trim();
    string hostId = io:readln("  Your host ID: ").trim();
    float price = toFloat(io:readln("  New price per night (0 to keep current): "));

    io:println("  Status: 1) Available  2) Unavailable  3) Under renovation");
    PropertyStatus status = toPropertyStatus(io:readln("  Choose 1-3: ").trim());

    int guests = toInt(io:readln("  Max guests (0 to keep current): "));

    UpdatePropertyResponse response = check rentalClient->update_property({
        property_id: id,
        host_id: hostId,
        price_per_night: price,
        status: status,
        max_guests: guests
    });

    io:println("\n  " + response.message);
    if response.success {
        Property p = response.updated_property;
        io:println("  " + p.name + " | N$" + p.price_per_night.toString() +
                " | " + p.status);
    }
}

// ---- 5. REMOVE (Host) ------------------------------------------------

function removeProperty() returns error? {
    string id = io:readln("\n  Property ID to remove: ").trim();
    string hostId = io:readln("  Your host ID: ").trim();

    RemovePropertyResponse response = check rentalClient->remove_property({
        property_id: id,
        host_id: hostId
    });

    io:println("\n  " + response.message);

    if response.success {
        io:println("\n  Your remaining listings in that region:");
        if response.remaining_properties.length() == 0 {
            io:println("    (none)");
        }
        foreach Property p in response.remaining_properties {
            io:println("    " + p.property_id + " | " + p.name + " | " + p.location);
        }
    }
}

// ---- 6. CLIENT STREAMING ---------------------------------------------

function registerUsers() returns error? {
    io:println("\n--- REGISTER USERS ------------------------------------");
    io:println("  Users are streamed to the server one at a time.");
    io:println("  The server replies once, after the stream closes.");
    io:println("  Leave the ID blank to finish.\n");

    Create_usersStreamingClient streamingClient = check rentalClient->create_users();

    int sent = 0;
    while true {
        string userId = io:readln("  User ID (blank to finish): ").trim();
        if userId == "" {
            break;
        }
        string name = io:readln("    Name: ").trim();
        string email = io:readln("    Email: ").trim();
        string roleInput = io:readln("    Role (h = host, g = guest): ").trim();
        UserRole role = roleInput.toLowerAscii() == "h" ? HOST : GUEST;

        check streamingClient->sendUser({
            user_id: userId,
            name: name,
            email: email,
            role: role
        });
        sent += 1;
        io:println("    -> streamed (" + sent.toString() + " so far)");
    }

    // Closing the stream is what triggers the server's single reply.
    check streamingClient->complete();

    CreateUsersResponse? response = check streamingClient->receiveCreateUsersResponse();
    if response is CreateUsersResponse {
        io:println("\n  Server replied: " + response.message);
        io:println("  Users created: " + response.users_created.toString());
    }
}

// ---- 7. BOOK (to cart) -----------------------------------------------

function bookProperty() returns error? {
    string guestId = io:readln("\n  Your guest ID (e.g. GUEST-1): ").trim();
    string propertyId = io:readln("  Property ID: ").trim();
    string checkIn = io:readln("  Check-in date (YYYY-MM-DD): ").trim();
    string checkOut = io:readln("  Check-out date (YYYY-MM-DD): ").trim();

    BookPropertyResponse response = check rentalClient->book_property({
        guest_id: guestId,
        property_id: propertyId,
        check_in_date: checkIn,
        check_out_date: checkOut
    });

    io:println("\n  " + response.message);
    if response.success {
        io:println("  Nights   : " + response.number_of_nights.toString());
        io:println("  Estimate : N$" + response.estimated_cost.toString());
        io:println("\n  Nothing is reserved yet. Use option 8 with cart ID " +
                response.cart_id + " to confirm.");
    }
}

// ---- 8. CONFIRM ------------------------------------------------------

function confirmBooking() returns error? {
    string guestId = io:readln("\n  Your guest ID: ").trim();
    string cartId = io:readln("  Cart ID (e.g. CART-1): ").trim();

    ConfirmBookingResponse response = check rentalClient->confirm_booking({
        guest_id: guestId,
        cart_id: cartId
    });

    io:println("\n  " + response.message);

    if response.success {
        Booking b = response.booking;
        io:println("");
        io:println("  Booking ID  : " + b.booking_id);
        io:println("  Property    : " + b.property_id);
        io:println("  Dates       : " + b.check_in_date + " to " + b.check_out_date);
        io:println("  Nights      : " + b.number_of_nights.toString());
        io:println("  TOTAL       : N$" + b.total_cost.toString());
    }
}

// ---- 9. FULL DEMO ----------------------------------------------------

function runDemo() returns error? {
    io:println("\n########## AUTOMATED DEMO ##########");

    io:println("\n=== Browse everything (server streaming) ===");
    var allProps = check rentalClient->list_available_properties({
        location: "",
        min_price: 0.0,
        max_price: 0.0
    });
    check allProps.forEach(function(Property p) {
        io:println("  " + p.property_id + " | " + p.name + " | N$" +
                p.price_per_night.toString());
    });

    io:println("\n=== Filter: Windhoek, under N$1000 ===");
    var filtered = check rentalClient->list_available_properties({
        location: "Windhoek",
        min_price: 0.0,
        max_price: 1000.0
    });
    check filtered.forEach(function(Property p) {
        io:println("  " + p.name + " | N$" + p.price_per_night.toString());
    });

    io:println("\n=== Search for one that does not exist ===");
    SearchPropertyResponse missing =
        check rentalClient->search_property({property_id: "PROP-999"});
    io:println("  " + missing.message);

    io:println("\n=== Book PROP-2 for 5-8 October ===");
    BookPropertyResponse booked = check rentalClient->book_property({
        guest_id: "GUEST-1",
        property_id: "PROP-2",
        check_in_date: "2026-10-05",
        check_out_date: "2026-10-08"
    });
    io:println("  " + booked.message);
    io:println("  " + booked.number_of_nights.toString() + " nights, estimate N$" +
            booked.estimated_cost.toString());

    io:println("\n=== Confirm it ===");
    ConfirmBookingResponse confirmed = check rentalClient->confirm_booking({
        guest_id: "GUEST-1",
        cart_id: booked.cart_id
    });
    io:println("  " + confirmed.message);

    io:println("\n=== Now try OVERLAPPING dates: 6-9 October ===");
    BookPropertyResponse clash = check rentalClient->book_property({
        guest_id: "GUEST-1",
        property_id: "PROP-2",
        check_in_date: "2026-10-06",
        check_out_date: "2026-10-09"
    });
    ConfirmBookingResponse rejected = check rentalClient->confirm_booking({
        guest_id: "GUEST-1",
        cart_id: clash.cart_id
    });
    io:println("  EXPECTED REFUSAL: " + rejected.message);

    io:println("\n=== Now BACK-TO-BACK dates: 8-10 October ===");
    io:println("  (check-in on the day the last booking ends)");
    BookPropertyResponse backToBack = check rentalClient->book_property({
        guest_id: "GUEST-1",
        property_id: "PROP-2",
        check_in_date: "2026-10-08",
        check_out_date: "2026-10-10"
    });
    ConfirmBookingResponse allowed = check rentalClient->confirm_booking({
        guest_id: "GUEST-1",
        cart_id: backToBack.cart_id
    });
    io:println("  EXPECTED SUCCESS: " + allowed.message);

    io:println("\n=== Wrong host cannot update someone else's listing ===");
    UpdatePropertyResponse denied = check rentalClient->update_property({
        property_id: "PROP-1",
        host_id: "HOST-2",
        price_per_night: 1.0,
        status: AVAILABLE,
        max_guests: 1
    });
    io:println("  EXPECTED REFUSAL: " + denied.message);

    io:println("\n########## DEMO COMPLETE ##########");
}

// ---- Helpers ---------------------------------------------------------

function toFloat(string input) returns float {
    float|error parsed = float:fromString(input.trim());
    return parsed is float ? parsed : 0.0;
}

function toInt(string input) returns int {
    int|error parsed = int:fromString(input.trim());
    return parsed is int ? parsed : 0;
}

function toPropertyType(string choice) returns PropertyType {
    match choice {
        "2" => { return HOUSE; }
        "3" => { return GUESTHOUSE; }
        "4" => { return LODGE; }
        "5" => { return CAMPSITE; }
        _ => { return APARTMENT; }
    }
}

function toPropertyStatus(string choice) returns PropertyStatus {
    match choice {
        "2" => { return UNAVAILABLE; }
        "3" => { return UNDER_RENOVATION; }
        _ => { return AVAILABLE; }
    }
}

function pad(string text, int width) returns string {
    string result = text;
    while result.length() < width {
        result = result + " ";
    }
    return result + " ";
}
