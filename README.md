# DSA612S Assignment 1
## Distributed Library System and Rental Accommodation System

Namibia University of Science and Technology
Faculty of Computing and Informatics
Department of Software Engineering

---

## Contents

1. Group members
2. About this project
3. Getting started
4. Question 1 — Library and Resource Management
5. Question 2 — Rental Accommodation System
6. Project layout
7. Design notes

---

## 1. Group members

1. Alonzo Brown — 217069851 — Team Leader / Hansteinel@gmail.com / 0817850767
2. Takunda Vhere — 224041576 / Takundagiftvhere@gmail.com / 0816751875
3. Frans Mbwangela — 223123005 / mrmbwangela@gmail.com / 0813457571
4. Justin Pohamba — 215071441 / jnpohamba@gmail.com / 0817688583
5. Israel Haimbili — 222058447 / Isyb15177@gmail.com / 0813823831
6. Ruth Hiluwa — 225128225 / rhiluwa@gmail.com / 0813805451

Version control: GitHub

---

## 2. About this project

Two separate systems live in this repository. They share a submission, not a codebase.

**Question 1** is a library and resource management API for the Ministry of Higher Education. It tracks books, laptops, thin clients, meeting rooms and labs across several universities. Built with REST.

**Question 2** is a rental accommodation platform for the Ministry of Tourism. Hosts list properties, guests search and book them. Built with gRPC.

Each has a server and a command-line client, so there are four Ballerina packages:

- `asset_service` — Question 1 server
- `asset_client` — Question 1 client
- `rental_service` — Question 2 server
- `rental_client` — Question 2 client

---

## 3. Getting started

### 3.1 What you need

Ballerina Swan Lake, version 2201.13.5 or later. Java 17 comes bundled with it, so you don't need to install that separately.

To check your installation, run "bal version" in a terminal.

### 3.2 One thing to watch

Both servers listen on port 9090, so they cannot run at the same time. Stop one before starting the other, or you'll get an "Address already in use" error.

---

## 4. Question 1 — Library and Resource Management

### 4.1 Starting the server

Open a terminal, change into the `asset_service` folder, and run "bal run".

You should see: *Library service started with 7 assets across 3 institutions.*

The API is then available at http://localhost:9090/library

### 4.2 Starting the client

Open a second terminal, change into the `asset_client` folder, and run "bal run".

### 4.3 Testing without the client

All GET endpoints work in an ordinary web browser. Try http://localhost:9090/library/assets to see everything the system is holding.

### 4.4 What the client does

The menu covers the five capabilities the brief asks for:

- Loaning an asset or booking a meeting room or lab
- A global view of every asset across the ministry
- A campus view, filtered by institution or site
- An overdue dashboard for staff
- A schedule manager for adding and removing servicing schedules

There are also options for registering new assets and inspecting a single asset in detail.

### 4.5 Endpoints

**Managing assets**

POST /assets creates one. GET /assets lists them all. GET, PUT and DELETE on /assets/{assetTag} retrieve, update or remove a single asset.

**Filtering and institutions**

GET /assets/institution/{name} narrows results to one university. GET /assets/site/{site} narrows to a single campus.

Institutions themselves are handled by GET /institutions to list them, POST /institutions to register one, and DELETE /institutions/{code} to remove one.

**Scheduling and maintenance**

GET /assets/overdue returns anything past its due date. GET /assets/{assetTag}/availability?checkDate=YYYY-MM-DD checks a specific day. PUT /assets/{assetTag}/status changes an asset's status. POST and DELETE on /assets/{assetTag}/schedules add or remove servicing schedules.

The overdue endpoint also accepts an optional ?currentDate=YYYY-MM-DD parameter, which checks against a date other than today. Useful for testing without changing your system clock.

**Components and repairs**

POST, GET and DELETE on /assets/{assetTag}/components manage the parts of a complex asset.

POST and PUT on /assets/{assetTag}/workorders open and update repair jobs, and POST and DELETE on /assets/{assetTag}/workorders/{orderId}/tasks handle the individual steps within a job.

---

## 5. Question 2 — Rental Accommodation System

### 5.1 Starting the server

Stop the Question 1 server first. Then change into the `rental_service` folder and run "bal run".

You should see: *Rental service started with 4 properties.*

### 5.2 Starting the client

In a second terminal, change into `rental_client` and run "bal run".

gRPC sends binary messages over HTTP/2, so unlike Question 1 this one cannot be tested in a browser. The client is the only way in. Menu option 9 runs every operation end to end if you just want to watch it work.

### 5.3 The eight operations

**Host operations**

`add_property` — a simple call. The host supplies the details and the server assigns the ID, rather than the host choosing one that might already exist.

`update_property` — a simple call for changing price, status or capacity. It checks that the host making the request owns the listing.

`remove_property` — a simple call that deletes a listing and returns the host's remaining properties in that region.

`create_users` — client streaming. The client sends many user profiles one after another, and the server replies once after the stream closes.

**Guest operations**

`list_available_properties` — server streaming. One request goes up and properties come back one at a time, optionally filtered by location or price range.

`search_property` — a simple lookup by ID. If the property is missing or unavailable it reports that rather than failing.

`book_property` — checks the dates make sense and places the request in a temporary cart. Nothing is reserved at this stage.

`confirm_booking` — the call that actually commits. It re-checks availability, calculates the total cost and finalises the booking.

### 5.4 Regenerating from the contract

`rental.proto` is the contract. Both the server skeleton and the client are generated from it, so a change to the proto means regenerating both.

From the repository root, run:

bal grpc --input rental_service/rental.proto --mode service --output rental_service

then:

bal grpc --input rental_service/rental.proto --mode client --output rental_client

Two warnings. Never edit `rental_pb.bal` by hand, because regeneration overwrites it. And regenerating the service wipes `rentalservice_service.bal`, so back up any implementation work first.

---

## 6. Project layout

### 6.1 asset_service

- `types.bal` — records and enums
- `data.bal` — the table store, the date helper and the seed data
- `service.bal` — all REST endpoints
- `components_logic.bal` — component business rules
- `workorders_logic.bal` — work order and task business rules
- `error_handling.bal` — turns internal error codes into HTTP statuses

### 6.2 asset_client

- `model.bal` — the shapes the client expects back from the server
- `main.bal` — the menu

### 6.3 rental_service

- `rental.proto` — the contract
- `rental_data.bal` — stores, date helpers and seed data
- `rentalservice_service.bal` — the eight operations
- `rental_pb.bal` — generated, do not edit

### 6.4 rental_client

- `main.bal` — the menu
- `rental_pb.bal` — generated, do not edit

---

## 7. Design notes

### 7.1 Where the data lives

Everything is held in memory and disappears when the server stops, which the brief allows.

Question 1 uses a Ballerina table keyed on assetTag. We chose that over a plain map because a table refuses to store two records under the same key, so the requirement that every asset carry a unique tag is handled by the language rather than by us remembering to check.

The key field must be marked readonly, because the table builds an index on it. If the value could change while the record sat in the table, the index would point at the wrong record and the asset would become unreachable.

Question 2 uses maps instead. A table key has to be readonly, and those records are generated from the proto file, so the modifier cannot be applied. Different tool, same job.

### 7.2 How dates are stored

Dates are stored as "YYYY-MM-DD" strings. Because the year comes first, comparing two of them alphabetically gives the same answer as comparing them chronologically, so the overdue check is a plain string comparison rather than date arithmetic.

The leading zeros matter. Without them "2026-9-5" would sort before "2026-10-15" and September would appear to come after October.

### 7.3 Concurrency

None of the service methods are marked isolated, and that is deliberate. It means Ballerina handles requests one at a time rather than in parallel, so two requests cannot interleave a read and a write on the shared store. Together with the lock blocks around the writes, this keeps the data consistent.

Marking them isolated would allow real parallelism, but would force the entire data layer to be isolated as well. We would rather be slow and correct.

### 7.4 Error handling

The logic functions know nothing about HTTP. They return errors carrying an internal code, and a single mapping layer translates those into status codes: missing things become 404, bad input and duplicates become 400, and state conflicts such as editing a closed work order become 409.

Every endpoint therefore fails in the same shape, which is what allows the client to handle errors in one place.

### 7.5 Why booking takes two steps

`book_property` does not reserve anything. It validates the dates and places the request in a cart. `confirm_booking` then re-checks against every confirmed booking before committing.

The reason is timing: another guest might book the same dates while the first is still deciding, so the earlier check cannot be trusted by the moment it matters.

The overlap check treats dates as half-open, meaning a guest can check in on the same day another checks out. Back-to-back bookings are normal, and blocking them would cost the host money.
