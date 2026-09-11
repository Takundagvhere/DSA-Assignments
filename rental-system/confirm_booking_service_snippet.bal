// Reference for wiring confirmBooking into the generated gRPC service
// (from `bal grpc --input rental.proto`). Paste the remote function
// below into the service object alongside addProperty, bookProperty, etc.

// service "RentalService" on grpcListener {
//
//     remote function confirmBooking(ConfirmBookingRequest req) returns BookingConfirmation|error {
//         Booking|error result = confirmBooking(req.guestId, req.bookingId);
//
//         if result is error {
//             // gRPC has no HTTP-style status codes — surface failure via
//             // the response payload (success=false + message) rather
//             // than throwing, so the client gets a clean confirmation
//             // object either way. Swap this for a grpc:Error status
//             // code if your team prefers status-based error handling.
//             return {
//                 success: false,
//                 bookingId: req.bookingId,
//                 propertyId: "",
//                 totalCost: 0d,
//                 status: "FAILED",
//                 message: result.message()
//             };
//         }
//
//         return {
//             success: true,
//             bookingId: result.bookingId,
//             propertyId: result.propertyId,
//             totalCost: result.totalCost,
//             status: result.status,
//             message: "Booking confirmed: " + result.bookingId +
//                       " (" + result.checkIn + " to " + result.checkOut + ")"
//         };
//     }
// }
