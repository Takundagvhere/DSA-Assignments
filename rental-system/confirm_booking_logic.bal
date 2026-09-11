// confirm_booking business logic.
//
// Steps:
//   1. Pull the pending request out of the guest's temporary cart.
//   2. Re-verify the property exists and is still available for the
//      requested dates — no overlap with any already-CONFIRMED
//      booking for that property. Re-checking against confirmed
//      bookings (not trusting the earlier book_property check) is
//      what prevents two guests racing to confirm the same dates.
//   3. Calculate total cost = price per night * number of nights.
//   4. Persist the confirmed booking and clear the guest's cart entry.

import ballerina/time;

const int SECONDS_PER_DAY = 86400;

// Parses "YYYY-MM-DD" into a time:Utc at midnight UTC.
isolated function parseDate(string isoDate) returns time:Utc|error {
    time:Utc|error result = time:utcFromString(isoDate + "T00:00:00.00Z");
    if result is error {
        return error("Invalid date format: '" + isoDate + "'. Expected YYYY-MM-DD.",
                errorCode = "VALIDATION_ERROR");
    }
    return result;
}

// True if [inA, outA) overlaps [inB, outB) — standard half-open interval
// overlap check, so a checkout on day X and a new check-in on day X do
// NOT count as a clash (back-to-back bookings are allowed).
isolated function datesOverlap(time:Utc inA, time:Utc outA, time:Utc inB, time:Utc outB) returns boolean {
    decimal aStartsBeforeBEnds = time:utcDiffSeconds(outB, inA);
    decimal bStartsBeforeAEnds = time:utcDiffSeconds(outA, inB);
    return aStartsBeforeBEnds > 0d && bStartsBeforeAEnds > 0d;
}

// The main confirm_booking operation.
public isolated function confirmBooking(string guestId, string bookingId) returns Booking|error {
    lock {
        // Pull the request from the cart.
        if !bookingCart.hasKey(bookingId) {
            return error("No pending booking request '" + bookingId + "' found in cart for guest '" + guestId + "'",
                    errorCode = "CART_NOT_FOUND");
        }
        BookingRequest req = bookingCart.get(bookingId).clone();

        if req.guestId != guestId {
            return error("Booking request '" + bookingId + "' does not belong to guest '" + guestId + "'",
                    errorCode = "VALIDATION_ERROR");
        }

        // Property must still exist and be an active listing.
        if !properties.hasKey(req.propertyId) {
            return error("Property '" + req.propertyId + "' not found", errorCode = "PROPERTY_NOT_FOUND");
        }
        Property prop = properties.get(req.propertyId).clone();
        if prop.status == "INACTIVE" {
            return error("Property '" + req.propertyId + "' is no longer listed", errorCode = "PROPERTY_UNAVAILABLE");
        }

        time:Utc checkInUtc = check parseDate(req.checkIn);
        time:Utc checkOutUtc = check parseDate(req.checkOut);

        if time:utcDiffSeconds(checkOutUtc, checkInUtc) <= 0d {
            return error("Check-out date must be after check-in date", errorCode = "VALIDATION_ERROR");
        }

        // Re-verify no overlap against every CONFIRMED booking for this
        // property (source of truth — the cart entry alone isn't enough
        // since another guest may have confirmed in the meantime).
        foreach Booking existing in confirmedBookings {
            if existing.propertyId == req.propertyId {
                time:Utc exIn = check parseDate(existing.checkIn);
                time:Utc exOut = check parseDate(existing.checkOut);
                if datesOverlap(checkInUtc, checkOutUtc, exIn, exOut) {
                    return error(
                            "Property '" + req.propertyId + "' is already booked for overlapping dates (" +
                            existing.checkIn + " to " + existing.checkOut + ")",
                            errorCode = "DATE_OVERLAP");
                }
            }
        }

        // Cost calculation.
        int nights = <int>(time:utcDiffSeconds(checkOutUtc, checkInUtc) / <decimal>SECONDS_PER_DAY);
        decimal totalCost = prop.pricePerNight * <decimal>nights;

        // Persist + clear cart.
        Booking confirmed = {
            bookingId: req.bookingId,
            propertyId: req.propertyId,
            guestId: guestId,
            checkIn: req.checkIn,
            checkOut: req.checkOut,
            totalCost: totalCost,
            status: "CONFIRMED"
        };
        confirmedBookings.add(confirmed);
        _ = bookingCart.remove(bookingId);

        return confirmed.clone();
    }
}
