// In-memory data store and startup seed data.

import ballerina/time;

// assetTag is the unique key, enforced by the table type itself.
public table<Asset> key(assetTag) assetDb = table [];

public table<Institution> key(code) institutionDb = table [];

// Today's date as "YYYY-MM-DD"; leading zeros keep the string ordering correct.
public function todayString() returns string {
    time:Civil now = time:utcToCivil(time:utcNow());
    string mm = now.month < 10 ? string `0${now.month}` : now.month.toString();
    string dd = now.day < 10 ? string `0${now.day}` : now.day.toString();
    return string `${now.year}-${mm}-${dd}`;
}

// Loads sample resources across three institutions so every endpoint returns something.
public function seedData() {

    assetDb.put({
        assetTag: "NUST-LIB-3DP-001",
        name: "Pro-Series 3D Printer",
        description: "High-precision laboratory printer for prototype development.",
        category: ELECTRONIC_RESOURCE,
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Innovation Lab",
        status: AVAILABLE,
        dateAcquired: "2024-03-10",
        components: [
            {
                compId: "C101",
                name: "High-Torque Stepper Motor",
                description: "Main motor for X-axis movement."
            }
        ],
        schedules: [
            {
                scheduleId: "SCH-882",
                'type: MAINTENANCE,
                dueDate: "2025-11-01",   // deliberately in the past so the overdue endpoint has a result
                description: "Quarterly calibration and nozzle cleaning."
            }
        ],
        workOrders: []
    });

    assetDb.put({
        assetTag: "NUST-LIB-LAP-014",
        name: "Dell Latitude 5540",
        description: "Student loaner laptop.",
        category: ELECTRONIC_RESOURCE,
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Library",
        status: LOANED_OUT,
        dateAcquired: "2025-01-20",
        components: [],
        schedules: [],
        workOrders: []
    });

    assetDb.put({
        assetTag: "NUST-LIB-ROOM-002",
        name: "Group Study Room B",
        description: "Six-seat bookable meeting room with display screen.",
        category: PHYSICAL_SPACE,
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Library",
        status: AVAILABLE,
        dateAcquired: "2023-06-01",
        components: [],
        schedules: [
            {
                scheduleId: "SCH-901",
                'type: BOOKING,
                dueDate: "2026-10-15",
                description: "Reserved for postgraduate seminar."
            }
        ],
        workOrders: []
    });

    assetDb.put({
        assetTag: "NUST-LIB-BK-1042",
        name: "Distributed Systems: Principles and Paradigms",
        description: "Tanenbaum and Van Steen. Reference copy, library use only.",
        category: BOOK,
        institution: "Namibia University of Science and Technology",
        site: "Main Campus - Library",
        status: AVAILABLE,
        dateAcquired: "2021-02-14",
        components: [],
        schedules: [],
        workOrders: []
    });

    assetDb.put({
        assetTag: "NUST-LIB-TC-208",
        name: "HP t640 Thin Client",
        description: "Lab workstation terminal.",
        category: ELECTRONIC_RESOURCE,
        institution: "Namibia University of Science and Technology",
        site: "Northern Campus - Computer Lab 2",
        status: AVAILABLE,
        dateAcquired: "2024-08-05",
        components: [],
        schedules: [],
        workOrders: []
    });

    assetDb.put({
        assetTag: "UNAM-LIB-PRN-007",
        name: "Canon ImageRunner",
        description: "Shared departmental printer.",
        category: ELECTRONIC_RESOURCE,
        institution: "University of Namibia",
        site: "Main Campus - Resource Centre",
        status: UNDER_MAINTENANCE,
        dateAcquired: "2022-09-15",
        components: [],
        schedules: [],
        workOrders: [
            {
                orderId: "WO-554",
                status: OPEN,
                description: "Paper feed jam - recurring",
                tasks: [
                    {taskId: "T1", description: "Inspect feed rollers.", completed: false}
                ]
            }
        ]
    });

    assetDb.put({
        assetTag: "IUM-LAB-005",
        name: "Networking Lab A",
        description: "Twenty-seat lab with Cisco rack equipment.",
        category: PHYSICAL_SPACE,
        institution: "International University of Management",
        site: "Dorado Campus - Block C",
        status: OCCUPIED,
        dateAcquired: "2022-01-30",
        components: [],
        schedules: [
            {
                scheduleId: "SCH-915",
                'type: BOOKING,
                dueDate: "2026-09-05",
                description: "CCNA practical session."
            }
        ],
        workOrders: []
    });

    institutionDb.put({
        code: "NUST",
        name: "Namibia University of Science and Technology",
        sites: [
            "Main Campus - Innovation Lab",
            "Main Campus - Library",
            "Northern Campus - Computer Lab 2"
        ]
    });

    institutionDb.put({
        code: "UNAM",
        name: "University of Namibia",
        sites: ["Main Campus - Resource Centre"]
    });

    institutionDb.put({
        code: "IUM",
        name: "International University of Management",
        sites: ["Dorado Campus - Block C"]
    });
}
