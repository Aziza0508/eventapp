import Foundation

// MARK: - MockEventFactory
// All mock objects mirror the backend domain types 1:1.
// Fields, types, and JSON keys are verified against API_Mapping.md.
// Context: Kazakhstan IT/STEM education platform.

enum MockEventFactory {

    // MARK: - Date Helper

    static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso) ?? Date()
    }

    // MARK: - Mock Organizers (User with role = .organizer)

    static let organizer1 = User(
        id: 101,
        email: "asel@nurone.kz",
        fullName: "Asel Nurmagambetova",
        role: .organizer,
        approved: true,
        blocked: false,
        phone: "+77011234567",
        city: "Almaty",
        school: nil,
        grade: nil,
        bio: "STEM education advocate and robotics coach",
        avatarURL: nil,
        interests: ["Robotics", "STEM Education"],
        privacy: PrivacySettings(visibleToOrganizers: true, visibleToSchool: true),
        createdAt: nil
    )

    static let organizer2 = User(
        id: 102,
        email: "timur@stem.kz",
        fullName: "Timur Bekseitov",
        role: .organizer,
        approved: true,
        blocked: false,
        phone: "+77029876543",
        city: "Astana",
        school: nil,
        grade: nil,
        bio: "Programming contest organizer",
        avatarURL: nil,
        interests: ["Programming", "AI/ML"],
        privacy: PrivacySettings(visibleToOrganizers: true, visibleToSchool: true),
        createdAt: nil
    )

    static let organizer3 = User(
        id: 103,
        email: "zarina@techkz.org",
        fullName: "Zarina Kasymova",
        role: .organizer,
        approved: true,
        blocked: false,
        phone: nil,
        city: "Shymkent",
        school: nil,
        grade: nil,
        bio: nil,
        avatarURL: nil,
        interests: ["Science", "Robotics"],
        privacy: PrivacySettings(visibleToOrganizers: true, visibleToSchool: true),
        createdAt: nil
    )

    // MARK: - Upcoming Events (14 total: 10 upcoming + 4 past)

    // 1. Flagship offline competition — Almaty, limited capacity, full description
    static let event1 = Event(
        id: 1,
        title: "Kazakhstan Robotics Championship 2026",
        description: """
        The premier annual robotics competition for students in grades 7–11 across Kazakhstan.

        **Competition Tracks:**
        • VEX IQ — for grades 7–9
        • VEX V5 — for grades 10–11
        • Open Innovation — original robot design challenge

        **What's Included:**
        All registered teams receive access to practice arenas 24 hours before competition day, \
        mentorship sessions with Nazarbayev University engineering faculty, and certificates of \
        participation signed by the Ministry of Education.

        **Prizes:**
        🥇 1st place: 500 000 KZT + trophy + recommendation letter
        🥈 2nd place: 300 000 KZT + trophy
        🥉 3rd place: 150 000 KZT + trophy

        Teams from Almaty, Astana, Shymkent, and Karaganda participated last year. \
        Registration closes two weeks before the event — apply early!
        """,
        category: "Robotics",
        tags: ["STEM", "Robotics", "Competition"],
        format: .offline,
        city: "Almaty",
        address: "Almaty Arena, Abay Ave 44",
        latitude: 43.238949,
        longitude: 76.945465,
        organizerContact: "asel@nurone.kz",
        additionalInfo: "Teams must register at least 2 weeks before the event.",
        dateStart: date("2026-04-10T09:00:00Z"),
        dateEnd: date("2026-04-10T18:00:00Z"),
        regDeadline: date("2026-03-27T23:59:00Z"),
        capacity: 50,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-1",
        organizerID: 101,
        organizer: organizer1,
        createdAt: date("2025-12-15T08:00:00Z")
    )

    // 2. Online Python + AI workshop — unlimited capacity, no city
    static let event2 = Event(
        id: 2,
        title: "Python & Artificial Intelligence Workshop",
        description: """
        A hands-on online workshop designed for students with basic programming knowledge \
        who want to explore machine learning and AI.

        **Topics Covered:**
        • Python refresher: lists, dicts, functions, comprehensions
        • NumPy & Pandas for data manipulation
        • Introduction to scikit-learn: classification and regression
        • Building your first neural network with TensorFlow/Keras
        • Mini-project: image classifier for Kazakh handwritten digits

        **Requirements:**
        Bring a laptop with Python 3.10+ installed. Basic Python knowledge required \
        (loops, functions). Google Colab will be used for GPU-accelerated exercises.

        All sessions are recorded and shared with registered participants within 48 hours.
        """,
        category: "Programming",
        tags: ["Python", "AI", "Machine Learning"],
        format: .online,
        city: nil,
        address: nil,
        latitude: nil,
        longitude: nil,
        organizerContact: "timur@stem.kz",
        additionalInfo: nil,
        dateStart: date("2026-03-22T14:00:00Z"),
        dateEnd: date("2026-03-22T18:00:00Z"),
        regDeadline: nil,
        capacity: 0,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-2",
        organizerID: 102,
        organizer: organizer2,
        createdAt: date("2026-01-10T09:00:00Z")
    )

    // 3. Math Olympiad Qualifier — Astana, limited spots, near deadline
    static let event3 = Event(
        id: 3,
        title: "International Math Olympiad Qualifier 2026",
        description: """
        Official national qualifying round for the International Mathematical Olympiad (IMO). \
        Students who place in the top 6 will represent Kazakhstan at IMO 2026 in Zagreb, Croatia.

        **Format:**
        Two rounds of 3 problems each. Time limit: 4.5 hours per round. Problems span algebra, \
        geometry, number theory, and combinatorics at IMO difficulty level.

        **Eligibility:**
        Open to students born on or after July 5, 2007. No upper age limit for high-school students.

        **Venue:**
        Nazarbayev Intellectual School, Astana. Travel and accommodation support available \
        for participants from other cities (apply during registration).
        """,
        category: "Mathematics",
        tags: ["Mathematics", "Olympiad", "Competition"],
        format: .offline,
        city: "Astana",
        address: "Nazarbayev Intellectual School, Mangilik El Ave 53/1",
        latitude: nil,
        longitude: nil,
        organizerContact: "timur@stem.kz",
        additionalInfo: "Travel support available for out-of-city participants.",
        dateStart: date("2026-03-15T09:00:00Z"),
        dateEnd: date("2026-03-16T16:00:00Z"),
        regDeadline: date("2026-03-01T23:59:00Z"),
        capacity: 30,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-3",
        organizerID: 102,
        organizer: organizer2,
        createdAt: date("2026-01-05T07:00:00Z")
    )

    // 4. Online bootcamp — very long description, unlimited capacity
    static let event4 = Event(
        id: 4,
        title: "Full-Stack Web Development Bootcamp",
        description: """
        A 6-week intensive online bootcamp taking you from zero to a deployed web application. \
        Perfect for students in grades 9–12 or university freshmen.

        **Week 1 — HTML & CSS Fundamentals**
        Semantic HTML5, CSS Grid, Flexbox, responsive design, and accessibility best practices.

        **Week 2 — JavaScript Essentials**
        Variables, functions, closures, async/await, Fetch API, and DOM manipulation.

        **Week 3 — React Basics**
        Components, props, state, hooks (useState, useEffect), and routing with React Router.

        **Week 4 — Backend with Node.js & Express**
        REST APIs, middleware, JSON Web Tokens, and connecting to a PostgreSQL database.

        **Week 5 — Databases & Deployment**
        SQL fundamentals, CRUD operations, Supabase, and deploying to Vercel + Railway.

        **Week 6 — Capstone Project**
        Build and present a full-stack event management app (yes, like this one!) with your team.

        **Tools Used:** VSCode, GitHub, Figma, Postman, Docker (intro).

        **Certificate:** All graduates who submit a capstone project receive a signed completion \
        certificate from NurOne Academy, recognized by top Kazakh universities.

        **Scholarship:** 50 seats are subsidized by the Digital Kazakhstan Fund — apply during \
        registration to be considered. Priority given to students from rural areas.
        """,
        category: "Programming",
        tags: ["Web Development", "Full-Stack", "Bootcamp"],
        format: .online,
        city: nil,
        address: nil,
        latitude: nil,
        longitude: nil,
        organizerContact: "asel@nurone.kz",
        additionalInfo: nil,
        dateStart: date("2026-05-01T10:00:00Z"),
        dateEnd: date("2026-06-12T17:00:00Z"),
        regDeadline: date("2026-04-25T23:59:00Z"),
        capacity: 0,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-4",
        organizerID: 101,
        organizer: organizer1,
        createdAt: date("2026-02-01T10:00:00Z")
    )

    // 5. Science Fair — Shymkent, large capacity, organizer3
    static let event5 = Event(
        id: 5,
        title: "Kazakhstan Science Fair 2026",
        description: """
        The largest student science exhibition in South Kazakhstan, hosted annually in Shymkent. \
        Students present original research projects to a panel of university professors and \
        industry professionals.

        **Nomination Categories:**
        • Biology & Medicine
        • Chemistry & Materials
        • Physics & Engineering
        • Computer Science & AI
        • Environmental Science
        • Social Sciences

        **Who Can Participate:**
        Individual students or teams of up to 3, grades 8–12. \
        Each project must include a written abstract (500–1000 words) and a poster (A0 format).

        **Awards:**
        Top projects in each category receive trophies, certificates, and an invitation to \
        present at the National Young Scientists Forum in Almaty in September.
        """,
        category: "Science",
        tags: ["Science", "Research", "Exhibition"],
        format: .offline,
        city: "Shymkent",
        address: "Shymkent Palace of Schoolchildren, Tauke Khan Ave 12",
        latitude: nil,
        longitude: nil,
        organizerContact: "zarina@techkz.org",
        additionalInfo: nil,
        dateStart: date("2026-04-20T09:00:00Z"),
        dateEnd: date("2026-04-21T17:00:00Z"),
        regDeadline: nil,
        capacity: 100,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-5",
        organizerID: 103,
        organizer: organizer3,
        createdAt: date("2025-11-20T12:00:00Z")
    )

    // 6. AI & ML Hackathon — hybrid, Almaty, has dateEnd
    static let event6 = Event(
        id: 6,
        title: "AI & Machine Learning Hackathon",
        description: """
        A 24-hour hybrid hackathon where teams compete to build the most impactful AI solution \
        for a social or environmental challenge in Kazakhstan.

        **Format:**
        Online participants work remotely and present via video; in-person teams work from the \
        Astana Hub coworking space in Almaty. Both tracks are judged by the same panel.

        **Challenge Theme (revealed 30 minutes before start):**
        Previous themes included: "Predicting air quality in Almaty using satellite data" and \
        "Automated assessment of student math solutions."

        **Team Size:** 2–4 members. Individual participation is also allowed.

        **Tools:** Any language, any framework. Cloud credits (Google Cloud $200 per team) \
        provided to all registered teams.

        **Prizes:**
        🥇 Grand Prize: 1 000 000 KZT + incubation slot at Astana Hub
        🥈 Runner-up: 500 000 KZT
        🥉 Best Student Team: 200 000 KZT
        """,
        category: "AI/ML",
        tags: ["AI", "Machine Learning", "Hackathon"],
        format: .hybrid,
        city: "Almaty",
        address: "Astana Hub Almaty, Al-Farabi Ave 77/7",
        latitude: nil,
        longitude: nil,
        organizerContact: "asel@nurone.kz",
        additionalInfo: "Google Cloud $200 credits provided per team.",
        dateStart: date("2026-04-15T10:00:00Z"),
        dateEnd: date("2026-04-16T10:00:00Z"),
        regDeadline: date("2026-04-10T23:59:00Z"),
        capacity: 60,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-6",
        organizerID: 101,
        organizer: organizer1,
        createdAt: date("2026-01-30T15:00:00Z")
    )

    // 7. Beginner robotics — Karaganda, small capacity (almost full edge case)
    static let event7 = Event(
        id: 7,
        title: "Robotics for Beginners",
        description: """
        A one-day introductory workshop for students with zero robotics experience. \
        All equipment (LEGO Mindstorms EV3 kits) is provided.

        **Program:**
        Morning: Building your first robot chassis and understanding actuators and sensors.
        Afternoon: Programming your robot to complete a simple maze using block-based coding.
        Evening: Mini-competition — fastest robot wins a small prize.

        **Who Should Attend:**
        Students in grades 5–8 who are curious about robots but have no prior experience. \
        No programming background required.

        **Location:**
        IT-Park Karaganda, Micro-district 21, building 3, 3rd floor.

        Lunch and snacks provided. Parents are welcome to observe the afternoon session.
        """,
        category: "Robotics",
        tags: ["Robotics", "Beginners", "LEGO"],
        format: .offline,
        city: "Karaganda",
        address: "IT-Park Karaganda, Micro-district 21, building 3",
        latitude: nil,
        longitude: nil,
        organizerContact: "zarina@techkz.org",
        additionalInfo: "Lunch and snacks provided. Parents welcome.",
        dateStart: date("2026-03-22T09:00:00Z"),
        dateEnd: date("2026-03-22T18:00:00Z"),
        regDeadline: nil,
        capacity: 20,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-7",
        organizerID: 103,
        organizer: organizer3,
        createdAt: date("2026-02-01T08:00:00Z")
    )

    // 8. Cybersecurity — online, moderate capacity
    static let event8 = Event(
        id: 8,
        title: "Cybersecurity Essentials for Students",
        description: """
        An online bootcamp covering the fundamentals of cybersecurity, from networking basics \
        to ethical hacking techniques. Taught by practicing security engineers at Kaspi Bank.

        **Modules:**
        1. How the internet works: DNS, HTTP, TCP/IP, TLS
        2. Common attack vectors: phishing, SQL injection, XSS, CSRF
        3. Defensive tools: firewalls, WAF, rate limiting, input validation
        4. Linux command line for security professionals
        5. Introduction to CTF (Capture the Flag) competitions

        **Final Project:**
        Participants join a 2-hour live CTF event in the final session. \
        Top 3 scorers receive a voucher for an industry-recognized certification exam.

        All sessions are held via Zoom. Recordings available for 30 days post-event.
        """,
        category: "Programming",
        tags: ["Cybersecurity", "Networking", "CTF"],
        format: .online,
        city: nil,
        address: nil,
        latitude: nil,
        longitude: nil,
        organizerContact: "timur@stem.kz",
        additionalInfo: nil,
        dateStart: date("2026-05-10T11:00:00Z"),
        dateEnd: date("2026-05-10T17:00:00Z"),
        regDeadline: nil,
        capacity: 40,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-8",
        organizerID: 102,
        organizer: organizer2,
        createdAt: date("2026-02-15T11:00:00Z")
    )

    // 9. 3D Printing — offline, Almaty, small capacity, has dateEnd
    static let event9 = Event(
        id: 9,
        title: "3D Printing & Engineering Design Workshop",
        description: """
        Learn to design objects using Tinkercad and print them on professional FDM printers \
        at the FabLab Almaty makerspace.

        **Schedule:**
        • Session 1 (09:00–12:00): Introduction to CAD with Tinkercad. Design a keychain with your name.
        • Session 2 (13:00–16:00): Advanced features — joins, holes, supports. \
          Design and print a phone stand or gear mechanism.

        **Take Home:**
        Every participant takes home their printed objects and a beginner's guide to 3D modeling.

        **Requirements:**
        Bring a laptop. No prior experience needed. Ages 12 and up.
        """,
        category: "STEM",
        tags: ["3D Printing", "Engineering", "CAD"],
        format: .offline,
        city: "Almaty",
        address: "FabLab Almaty, Rozybakiev St 263",
        latitude: nil,
        longitude: nil,
        organizerContact: "asel@nurone.kz",
        additionalInfo: nil,
        dateStart: date("2026-04-05T09:00:00Z"),
        dateEnd: date("2026-04-05T16:00:00Z"),
        regDeadline: nil,
        capacity: 25,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-9",
        organizerID: 101,
        organizer: organizer1,
        createdAt: date("2026-02-10T09:00:00Z")
    )

    // 10. National coding competition — huge capacity, Astana, paid entry
    static let event10 = Event(
        id: 10,
        title: "National Coding Competition «CodeKZ 2026»",
        description: """
        The annual all-Kazakhstan competitive programming championship, open to students \
        in grades 8–12. Winners qualify for the International Olympiad in Informatics (IOI).

        **Rounds:**
        • Online qualification round (at home) — 3 hours, 5 problems
        • Regional final (in-person, 7 cities) — 5 hours, 6 problems
        • National grand final (Astana) — 5 hours, 6 problems

        **Problem Difficulty:**
        Problems range from CF Div. 2 C-level to IOI hard. The top 30 students advance \
        to the national final regardless of city.

        **Supported Languages:** C++17, Java 17, Python 3.12, Kotlin.

        **National Final Prizes:**
        🥇 1st: 2 000 000 KZT + guaranteed admission to NUAI CS program
        🥈 2nd: 1 000 000 KZT
        🥉 3rd: 500 000 KZT
        Ranks 4–10: 100 000 KZT each

        Registration closes April 30. No entry fee.
        """,
        category: "Programming",
        tags: ["Competitive Programming", "Olympiad", "IOI"],
        format: .offline,
        city: "Astana",
        address: "EXPO Congress Center, Mangilik El Ave 1",
        latitude: nil,
        longitude: nil,
        organizerContact: "timur@stem.kz",
        additionalInfo: nil,
        dateStart: date("2026-06-01T09:00:00Z"),
        dateEnd: date("2026-06-01T17:00:00Z"),
        regDeadline: date("2026-04-30T23:59:00Z"),
        capacity: 200,
        isFree: false,
        price: 5000,
        posterURL: nil,
        checkinToken: "mock-token-event-10",
        organizerID: 102,
        organizer: organizer2,
        createdAt: date("2026-01-15T08:00:00Z")
    )

    // 11. Past: Winter Robotics Camp (for MyEvents "Past" segment)
    static let event11 = Event(
        id: 11,
        title: "Winter Robotics Camp 2025",
        description: """
        A 3-day winter robotics camp held at the Teknoplex Innovation Center in Almaty. \
        Students built autonomous robots for warehouse simulation tasks and competed on \
        a custom-built arena.

        **Outcome:** 28 of 30 participants rated the camp 5/5. \
        6 teams advanced to the Regional Robotics League spring qualifier.
        """,
        category: "Robotics",
        tags: ["Robotics", "Camp", "Autonomous"],
        format: .offline,
        city: "Almaty",
        address: "Teknoplex Innovation Center, Seifullin Ave 510",
        latitude: nil,
        longitude: nil,
        organizerContact: "asel@nurone.kz",
        additionalInfo: nil,
        dateStart: date("2025-11-15T09:00:00Z"),
        dateEnd: date("2025-11-17T17:00:00Z"),
        regDeadline: nil,
        capacity: 30,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-11",
        organizerID: 101,
        organizer: organizer1,
        createdAt: date("2025-10-01T10:00:00Z")
    )

    // 12. Past: Python Workshop Dec 2025
    static let event12 = Event(
        id: 12,
        title: "Python Workshop: Data Structures & Algorithms",
        description: """
        A focused online workshop on data structures and algorithms in Python, \
        covering arrays, linked lists, trees, graphs, dynamic programming, and \
        greedy algorithms using LeetCode-style problems.
        """,
        category: "Programming",
        tags: ["Python", "Algorithms", "Data Structures"],
        format: .online,
        city: nil,
        address: nil,
        latitude: nil,
        longitude: nil,
        organizerContact: "timur@stem.kz",
        additionalInfo: nil,
        dateStart: date("2025-12-01T14:00:00Z"),
        dateEnd: date("2025-12-01T18:00:00Z"),
        regDeadline: nil,
        capacity: 0,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-12",
        organizerID: 102,
        organizer: organizer2,
        createdAt: date("2025-11-01T09:00:00Z")
    )

    // 13. Past: Physics Olympiad
    static let event13 = Event(
        id: 13,
        title: "Physics Olympiad Preparation Seminar",
        description: """
        A 2-day preparation seminar for Kazakhstan Physics Olympiad participants, \
        covering mechanics, thermodynamics, electromagnetism, and optics at competition level. \
        Led by Dr. Askar Seitkali (KazNU Physics Faculty).
        """,
        category: "Science",
        tags: ["Physics", "Olympiad", "Seminar"],
        format: .offline,
        city: "Almaty",
        address: "KazNU Physics Faculty, Al-Farabi Ave 71",
        latitude: nil,
        longitude: nil,
        organizerContact: "zarina@techkz.org",
        additionalInfo: nil,
        dateStart: date("2026-01-20T09:00:00Z"),
        dateEnd: date("2026-01-21T16:00:00Z"),
        regDeadline: nil,
        capacity: 15,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-13",
        organizerID: 103,
        organizer: organizer3,
        createdAt: date("2025-12-10T11:00:00Z")
    )

    // 14. Past: Green Tech Contest
    static let event14 = Event(
        id: 14,
        title: "Green Innovation Tech Contest",
        description: """
        A competition for student teams to present technology-based solutions for \
        environmental challenges in Kazakhstan: air quality, water management, \
        renewable energy, and waste reduction.

        Held in Astana with 14 teams from 6 cities. Top 3 projects received grants \
        from the Kazakh Green Fund to develop prototypes.
        """,
        category: "STEM",
        tags: ["Green Tech", "Environment", "Innovation"],
        format: .offline,
        city: "Astana",
        address: "Astana Hub, Mangilik El Ave 55/19",
        latitude: nil,
        longitude: nil,
        organizerContact: "timur@stem.kz",
        additionalInfo: nil,
        dateStart: date("2026-02-10T09:00:00Z"),
        dateEnd: date("2026-02-10T17:00:00Z"),
        regDeadline: nil,
        capacity: 80,
        isFree: true,
        price: 0,
        posterURL: nil,
        checkinToken: "mock-token-event-14",
        organizerID: 102,
        organizer: organizer2,
        createdAt: date("2025-12-05T08:00:00Z")
    )

    // MARK: - All Events (array — order = featured first, then upcoming, then past)

    static let allEvents: [Event] = [
        event1, event2, event3, event4, event5, event6,
        event7, event8, event9, event10,
        event11, event12, event13, event14
    ]

    // MARK: - Mock Current User

    static let currentUser = User(
        id: 1,
        email: "student@example.kz",
        fullName: "Aisha Bekova",
        role: .student,
        approved: true,
        blocked: false,
        phone: "+77051112233",
        city: "Almaty",
        school: "School No. 42",
        grade: 11,
        bio: "Passionate about robotics and competitive programming",
        avatarURL: nil,
        interests: ["Robotics", "Programming", "Mathematics"],
        privacy: PrivacySettings(visibleToOrganizers: true, visibleToSchool: false),
        createdAt: nil
    )

    // MARK: - Mock Registrations (for MyEventsView)

    static let myRegistrations: [Registration] = [
        // Upcoming — pending
        Registration(
            id: 201,
            userID: 1,
            eventID: 1,
            status: .pending,
            checkedInAt: nil,
            event: event1,
            user: currentUser,
            createdAt: date("2026-02-20T10:00:00Z")
        ),
        // Upcoming — approved
        Registration(
            id: 202,
            userID: 1,
            eventID: 3,
            status: .approved,
            checkedInAt: nil,
            event: event3,
            user: currentUser,
            createdAt: date("2026-01-25T14:00:00Z")
        ),
        // Upcoming — pending (online event)
        Registration(
            id: 203,
            userID: 1,
            eventID: 2,
            status: .pending,
            checkedInAt: nil,
            event: event2,
            user: currentUser,
            createdAt: date("2026-02-15T09:00:00Z")
        ),
        // Past — approved
        Registration(
            id: 204,
            userID: 1,
            eventID: 11,
            status: .approved,
            checkedInAt: nil,
            event: event11,
            user: currentUser,
            createdAt: date("2025-11-01T08:00:00Z")
        ),
        // Past — rejected
        Registration(
            id: 205,
            userID: 1,
            eventID: 12,
            status: .rejected,
            checkedInAt: nil,
            event: event12,
            user: currentUser,
            createdAt: date("2025-11-20T12:00:00Z")
        ),
        // Past — approved
        Registration(
            id: 206,
            userID: 1,
            eventID: 13,
            status: .approved,
            checkedInAt: nil,
            event: event13,
            user: currentUser,
            createdAt: date("2026-01-05T16:00:00Z")
        )
    ]
}
