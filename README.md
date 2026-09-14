# DSA612S Assignment 1
## Distributed Library System & Rental Accommodation System

Namibia University of Science and Technology
Faculty of Computing and Informatics — Department of Software Engineering

---

## Group Members

DSA612S 

Group Names:

1.Alonzo Brown - 217069851 (Team Leader)

2.Takunda Vhere - 224041576

3.Frans Mbwangela - 223123005

4.Justin Pohamba - 215071441

5.Israel Haimbili - 222058447

6.Ruth Hiluwa - 225128225


Tool used:

Github

---

## Prerequisites

- Ballerina Swan Lake 2201.13.x — verify with `bal version`
- Java 17+ (bundled with the Ballerina distribution)

> Both services listen on port **9090**, so only one may run at a time.

---

## Question 1 — Library & Resource Management (REST)

A RESTful API for tracking books, electronic resources and physical spaces
across multiple campuses, with a command-line client.

### Run the server

    cd asset_service
    bal run

Starts on `http://localhost:9090/library` and seeds seven assets across
three institutions.

### Run the client

In a second terminal:

    cd asset_client
    bal run

### Quick check

    curl http://localhost:9090/library/assets

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/assets` | Create an asset |
| GET | `/assets` | List all assets |
| GET | `/assets/{assetTag}` | Retrieve one asset |
| PUT | `/assets/{assetTag}` | Update an asset |
| DELETE | `/assets/{assetTag}` | Remove an asset |
| GET | `/assets/institution/{name}` | Filter by institution |
| GET | `/assets/site/{site}` | Filter by campus |
| GET | `/assets/overdue` | Items past their due date |
| GET | `/assets/{assetTag}/availability?checkDate=` | Availability on a date |
| PUT | `/assets/{assetTag}/status` | Change status |
| POST | `/assets/{assetTag}/schedules` | Add a schedule |
| DELETE | `/assets/{assetTag}/schedules/{scheduleId}` | Remove a schedule |
| GET | `/institutions` | List institutions |
| POST | `/institutions` | Register an institution |
| DELETE | `/institutions/{code}` | Remove an institution |
| POST/GET/DELETE | `/assets/{assetTag}/components...` | Manage components |
| POST/PUT | `/assets/{assetTag}/workorders...` | Manage work orders |
| POST/DELETE | `/assets/{assetTag}/workorders/{orderId}/tasks...` | Manage sub-tasks |

---

## Question 2 — Rental Accommodation System (gRPC)

A gRPC service for property listings and bookings, with a command-line client
that invokes every remote function.

### Run the server

    cd rental_service
    bal run

Starts on port 9090 and seeds four properties.

### Run the client

In a second terminal:

    cd rental_client
    bal run

Menu option **9** runs an automated demo covering all operations, including
a refused overlapping booking and an accepted back-to-back booking.

### Operations

| RPC | Type | Purpose |
|---|---|---|
| `add_property` | Simple | Host registers a listing; server assigns the ID |
| `create_users` | Client streaming | Many users streamed up, one confirmation back |
| `update_property` | Simple | Host updates price, status or capacity |
| `remove_property` | Simple | Host deletes a listing; returns remaining ones in that region |
| `list_available_properties` | Server streaming | Properties streamed back one at a time |
| `search_property` | Simple | Look up by ID |
| `book_property` | Simple | Validate dates and add to the booking cart |
| `confirm_booking` | Simple | Re-check availability, calculate cost, finalise |

### Regenerating from the contract

`rental.proto` is the single source of truth. To regenerate after changing it,
from the repository root:

    bal grpc --input rental_service/rental.proto --mode service --output rental_service
    bal grpc --input rental_service/rental.proto --mode client --output rental_client

> `rental_pb.bal` is generated. Never edit it, and note that regenerating
> overwrites the service implementation file.

---

## Project structure

| Path | Contents |
|---|---|
| `asset_service/types.bal` | Shared records and enums |
| `asset_service/data.bal` | Table store and seed data |
| `asset_service/service.bal` | REST endpoints |
| `asset_service/components_logic.bal` | Component business rules |
| `asset_service/workorders_logic.bal` | Work order business rules |
| `asset_service/error_handling.bal` | Error code to HTTP status mapping |
| `asset_client/model.bal` | Client-side payload shapes |
| `asset_client/main.bal` | Menu client |
| `rental_service/rental.proto` | Protocol Buffer contract |
| `rental_service/rental_data.bal` | Stores, date helpers, seed data |
| `rental_service/rentalservice_service.bal` | gRPC implementation |
| `rental_client/main.bal` | Menu client |
| `*/rental_pb.bal` | Generated — do not edit |

---

## Design notes

**Storage.** Question 1 uses `table<Asset> key(assetTag)`, which enforces the
unique-identifier requirement at the type level rather than by convention.
Question 2 uses maps, because generated protobuf records cannot supply the
`readonly` key field a table requires. Both are in-memory and reset on restart,
as the specification permits.

**Dates.** Stored as ISO 8601 strings. That format sorts alphabetically in the
same order it sorts chronologically, so the overdue check is a string comparison
rather than date arithmetic.

**Concurrency.** Remote and resource methods are deliberately not `isolated`, so
Ballerina serialises access to the shared stores. Combined with `lock` blocks
around mutations, no two requests can interleave a read and a write.

**Booking.** `book_property` only places a request in a temporary cart;
`confirm_booking` re-verifies against confirmed bookings before committing,
because availability can change between browsing and confirming. Overlap uses
half-open intervals, so a check-in on the day of another guest's check-out is
permitted.
