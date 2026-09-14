// gRPC server implementing the eight operations defined in rental.proto.

import ballerina/grpc;
import ballerina/log;

listener grpc:Listener ep = new (9090);

@grpc:Descriptor {value: RENTAL_DESC}
service "RentalService" on ep {

    function init() {
        seedRentalData();
        log:printInfo("Rental service started with " +
                propertyDb.length().toString() + " properties.");
    }

    // Host operations - Role 2

    // Simple RPC. Host registers a listing; the SERVER generates the id.
    remote function add_property(AddPropertyRequest value)
            returns AddPropertyResponse|error {
        lock {
            if value.host_id.trim() == "" {
                return {property_id: "", success: false, message: "host_id is required"};
            }
            if value.name.trim() == "" {
                return {property_id: "", success: false, message: "Property name is required"};
            }
            if value.price_per_night <= 0.0 {
                return {property_id: "", success: false, message: "Price per night must be greater than zero"};
            }

            string newId = nextPropertyId();
            propertyDb[newId] = {
                property_id: newId,
                host_id: value.host_id,
                name: value.name,
                location: value.location,
                region: value.region,
                property_type: value.property_type,
                price_per_night: value.price_per_night,
                status: AVAILABLE,
                max_guests: value.max_guests
            };

            return {
                property_id: newId,
                success: true,
                message: "Property '" + value.name + "' registered as " + newId
            };
        }
    }

    // Simple RPC. Only the owning host may update the listing.
    remote function update_property(UpdatePropertyRequest value)
            returns UpdatePropertyResponse|error {
        lock {
            Property? existing = propertyDb[value.property_id];
            if existing is () {
                return {
                    success: false,
                    message: "Property not found: " + value.property_id,
                    updated_property: emptyProperty()
                };
            }
            if existing.host_id != value.host_id {
                return {
                    success: false,
                    message: "Host '" + value.host_id + "' does not own property " + value.property_id,
                    updated_property: emptyProperty()
                };
            }

            Property updated = existing.clone();
            if value.price_per_night > 0.0 {
                updated.price_per_night = value.price_per_night;
            }
            updated.status = value.status;
            if value.max_guests > 0 {
                updated.max_guests = value.max_guests;
            }
            propertyDb[value.property_id] = updated;

            return {
                success: true,
                message: "Property " + value.property_id + " updated",
                updated_property: updated.clone()
            };
        }
    }

    // Simple RPC. Returns the host's REMAINING properties in that region.
    remote function remove_property(RemovePropertyRequest value)
            returns RemovePropertyResponse|error {
        lock {
            Property? existing = propertyDb[value.property_id];
            if existing is () {
                return {
                    success: false,
                    message: "Property not found: " + value.property_id,
                    remaining_properties: []
                };
            }
            if existing.host_id != value.host_id {
                return {
                    success: false,
                    message: "Host '" + value.host_id + "' does not own property " + value.property_id,
                    remaining_properties: []
                };
            }

            string region = existing.region;
            _ = propertyDb.remove(value.property_id);

            Property[] remaining = [];
            foreach Property p in propertyDb {
                if p.host_id == value.host_id && p.region == region {
                    remaining.push(p);
                }
            }

            return {
                success: true,
                message: "Property " + value.property_id + " removed",
                remaining_properties: remaining.clone()
            };
        }
    }

    //  create_users - CLIENT STREAMING

    remote function create_users(stream<User, error?> clientStream)
            returns CreateUsersResponse|error {
        int created = 0;
        int skipped = 0;

        // nextEntry is () when the client closes the stream.
        record {|User value;|}|error? entry = clientStream.next();

        while entry is record {|User value;|} {
            User u = entry.value;
            lock {
                if u.user_id.trim() == "" || userDb.hasKey(u.user_id) {
                    skipped += 1;
                } else {
                    userDb[u.user_id] = u.clone();
                    created += 1;
                }
            }
            entry = clientStream.next();
        }

        if entry is error {
            return {
                users_created: created,
                success: false,
                message: "Stream failed after " + created.toString() + " users: " + entry.message()
            };
        }

        string msg = created.toString() + " user(s) registered";
        if skipped > 0 {
            msg = msg + ", " + skipped.toString() + " skipped (blank or duplicate id)";
        }
        return {users_created: created, success: true, message: msg};
    }

    // Guest browsing and search - Role 3

    // SERVER STREAMING. Properties are sent back one at a time.
    remote function list_available_properties(ListPropertiesRequest value)
            returns stream<Property, error?>|error {
        Property[] results = [];

        lock {
            foreach Property p in propertyDb {
                if p.status != AVAILABLE {
                    continue;
                }
                if value.location.trim() != "" && p.location != value.location {
                    continue;
                }
                if value.min_price > 0.0 && p.price_per_night < value.min_price {
                    continue;
                }
                if value.max_price > 0.0 && p.price_per_night > value.max_price {
                    continue;
                }
                results.push(p);
            }
            results = results.clone();
        }

        return results.toStream();
    }

    // Simple RPC. Returns full details, or a "Not Available" status.
    remote function search_property(SearchPropertyRequest value)
            returns SearchPropertyResponse|error {
        lock {
            Property? found = propertyDb[value.property_id];
            if found is () {
                return {
                    available: false,
                    message: "Not Available - no property with id " + value.property_id,
                    property: emptyProperty()
                };
            }
            if found.status != AVAILABLE {
                return {
                    available: false,
                    message: "Not Available - property is currently " + found.status,
                    property: found.clone()
                };
            }
            return {
                available: true,
                message: "Property found",
                property: found.clone()
            };
        }
    }

    //  book_property - adds to the temporary cart.

    remote function book_property(BookPropertyRequest value)
            returns BookPropertyResponse|error {
        lock {
            Property? prop = propertyDb[value.property_id];
            if prop is () {
                return {
                    success: false,
                    message: "Property not found: " + value.property_id,
                    cart_id: "",
                    number_of_nights: 0,
                    estimated_cost: 0.0
                };
            }
            if prop.status != AVAILABLE {
                return {
                    success: false,
                    message: "Property is currently " + prop.status,
                    cart_id: "",
                    number_of_nights: 0,
                    estimated_cost: 0.0
                };
            }

            // Basic validation: end date must be after start date.
            int|error nights = nightsBetween(value.check_in_date, value.check_out_date);
            if nights is error {
                return {
                    success: false,
                    message: nights.message(),
                    cart_id: "",
                    number_of_nights: 0,
                    estimated_cost: 0.0
                };
            }

            float estimate = prop.price_per_night * <float>nights;
            string cartId = nextCartId();

            cartDb[cartId] = {
                cartId: cartId,
                guestId: value.guest_id,
                propertyId: value.property_id,
                checkInDate: value.check_in_date,
                checkOutDate: value.check_out_date,
                nights: nights,
                estimatedCost: estimate
            };

            return {
                success: true,
                message: "Added to booking cart. Call confirm_booking with cart id " + cartId,
                cart_id: cartId,
                number_of_nights: nights,
                estimated_cost: estimate
            };
        }
    }

    // Booking confirmation with overlap re-check - Role 5

    remote function confirm_booking(ConfirmBookingRequest value)
            returns ConfirmBookingResponse|error {
        lock {
            CartEntry? entry = cartDb[value.cart_id];
            if entry is () {
                return {
                    success: false,
                    message: "No pending request '" + value.cart_id + "' in the cart",
                    booking: emptyBooking()
                };
            }
            if entry.guestId != value.guest_id {
                return {
                    success: false,
                    message: "Cart entry does not belong to guest " + value.guest_id,
                    booking: emptyBooking()
                };
            }

            Property? prop = propertyDb[entry.propertyId];
            if prop is () {
                return {
                    success: false,
                    message: "Property " + entry.propertyId + " is no longer listed",
                    booking: emptyBooking()
                };
            }

            // Re-check overlap against every confirmed booking for this
            foreach Booking existing in bookingDb {
                if existing.property_id == entry.propertyId && existing.confirmed {
                    if datesOverlap(entry.checkInDate, entry.checkOutDate,
                            existing.check_in_date, existing.check_out_date) {
                        return {
                            success: false,
                            message: "Property already booked for overlapping dates (" +
                                existing.check_in_date + " to " + existing.check_out_date + ")",
                            booking: emptyBooking()
                        };
                    }
                }
            }

            // Total cost = price per night x number of nights.
            float totalCost = prop.price_per_night * <float>entry.nights;
            string bookingId = nextBookingId();

            Booking confirmed = {
                booking_id: bookingId,
                property_id: entry.propertyId,
                guest_id: entry.guestId,
                check_in_date: entry.checkInDate,
                check_out_date: entry.checkOutDate,
                number_of_nights: entry.nights,
                total_cost: totalCost,
                confirmed: true
            };

            bookingDb[bookingId] = confirmed;
            _ = cartDb.remove(value.cart_id);

            return {
                success: true,
                message: "Booking " + bookingId + " confirmed for " +
                    entry.nights.toString() + " night(s). Total: N$" + totalCost.toString(),
                booking: confirmed.clone()
            };
        }
    }
}
