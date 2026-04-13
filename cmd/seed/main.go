// Command seed wipes the EventApp database and inserts a deterministic,
// realistic demo dataset. It is the entry point invoked by `make dev-seed`.
//
// What it produces:
//
//   - 1 admin, 4 organizers (3 approved, 1 pending), 4 students
//   - 18 events spanning Almaty / Astana / Shymkent, mixing categories
//     (Robotics, Programming, AI/ML, Hackathon, Workshop, Competition),
//     formats (online / offline / hybrid), and free / paid pricing
//   - Realistic registration coverage across every status the state
//     machine supports: pending, approved, rejected, waitlisted,
//     checked_in, completed, cancelled
//   - A handful of favorites and in-app notifications
//
// The seed is fully idempotent: it TRUNCATEs the relevant tables before
// inserting so re-running it is always safe.
package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"time"

	"eventapp/config"
	"eventapp/internal/domain"
	"eventapp/internal/infra/postgres"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func main() {
	cfg := config.Load()

	db, err := postgres.Connect(postgres.Config{
		Host:     cfg.DB.Host,
		Port:     cfg.DB.Port,
		User:     cfg.DB.User,
		Password: cfg.DB.Password,
		DBName:   cfg.DB.Name,
		SSLMode:  cfg.DB.SSLMode,
	})
	if err != nil {
		log.Fatalf("seed: connect db: %v", err)
	}

	password := getEnv("SEED_PASSWORD", "Password123!")
	adminEmail := getEnv("SEED_ADMIN_EMAIL", "admin@eventapp.local")

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("seed: bcrypt: %v", err)
	}
	pwHash := string(hash)

	if err := truncateAll(db); err != nil {
		log.Fatalf("seed: truncate: %v", err)
	}

	users := seedUsers(db, pwHash, adminEmail)
	events := seedEvents(db, users)
	seedRegistrations(db, users, events)
	seedFavorites(db, users, events)
	seedNotifications(db, users, events)

	log.Printf("[seed] done — %d users, %d events", len(users.all()), len(events))
	fmt.Println()
	fmt.Println("Login credentials (password for everyone:", password+")")
	fmt.Println("  admin:     ", users.admin.Email)
	for _, o := range users.organizers {
		fmt.Println("  organizer:", o.Email)
	}
	for _, s := range users.students {
		fmt.Println("  student:  ", s.Email)
	}
}

// ───────────────────────────────────── Users ─────────────────────────────────

type seededUsers struct {
	admin      *domain.User
	organizers []*domain.User // [0..2] approved, [3] pending
	students   []*domain.User
}

func (s seededUsers) all() []*domain.User {
	out := []*domain.User{s.admin}
	out = append(out, s.organizers...)
	out = append(out, s.students...)
	return out
}

func seedUsers(db *gorm.DB, pwHash, adminEmail string) seededUsers {
	admin := &domain.User{
		Email:        adminEmail,
		PasswordHash: pwHash,
		Role:         domain.RoleAdmin,
		Approved:     true,
		FullName:     "Diana Admin",
		City:         "Almaty",
	}

	organizers := []*domain.User{
		{
			Email: "alma@robotics.kz", PasswordHash: pwHash,
			Role: domain.RoleOrganizer, Approved: true,
			FullName: "Alma Sultanova", City: "Almaty",
			Bio: "Lead organizer at Almaty Robotics League. 8+ years running youth robotics tournaments.",
		},
		{
			Email: "olzhas@codelab.kz", PasswordHash: pwHash,
			Role: domain.RoleOrganizer, Approved: true,
			FullName: "Olzhas Bekov", City: "Astana",
			Bio: "Founder of CodeLab Astana. Hosts hackathons and weekend programming bootcamps for grades 7-12.",
		},
		{
			Email: "dana@iot.kz", PasswordHash: pwHash,
			Role: domain.RoleOrganizer, Approved: true,
			FullName: "Dana Kassymova", City: "Shymkent",
			Bio: "Coordinates the Shymkent IoT & AI club for school students.",
		},
		{
			Email: "yerlan@newschool.kz", PasswordHash: pwHash,
			Role: domain.RoleOrganizer, Approved: false, // intentionally pending
			FullName: "Yerlan Akhmet", City: "Almaty",
			Bio: "New organizer awaiting admin approval.",
		},
	}

	students := []*domain.User{
		{
			Email: "nurlan@school.kz", PasswordHash: pwHash,
			Role: domain.RoleStudent, Approved: true,
			FullName: "Nurlan Tolegen", City: "Almaty",
			School: "NIS Almaty", Grade: 11,
			Interests: []string{"robotics", "programming", "ai-ml"},
		},
		{
			Email: "aisha@school.kz", PasswordHash: pwHash,
			Role: domain.RoleStudent, Approved: true,
			FullName: "Aisha Mukhamed", City: "Almaty",
			School: "Lyceum #134", Grade: 10,
			Interests: []string{"programming", "design"},
		},
		{
			Email: "daniyar@school.kz", PasswordHash: pwHash,
			Role: domain.RoleStudent, Approved: true,
			FullName: "Daniyar Serik", City: "Astana",
			School: "Bilim-Innovation Lyceum", Grade: 12,
			Interests: []string{"hackathon", "ai-ml", "iot"},
		},
		{
			Email: "samal@school.kz", PasswordHash: pwHash,
			Role: domain.RoleStudent, Approved: true,
			FullName: "Samal Bek", City: "Shymkent",
			School: "School-Lyceum #45", Grade: 9,
			Interests: []string{"robotics", "iot"},
		},
	}

	mustCreate(db, admin)
	for _, o := range organizers {
		mustCreate(db, o)
	}
	for _, s := range students {
		mustCreate(db, s)
	}

	// User.Approved has `gorm:"default:true"`. On INSERT the bool zero-value
	// is replaced with the column default *and* GORM rehydrates the Go
	// struct to match — so checking `o.Approved` post-Create is useless.
	// Force the pending organizer back to false with raw SQL.
	pendingEmails := []string{}
	for _, o := range organizers {
		if o.Email == "yerlan@newschool.kz" { // intentionally-pending fixture
			pendingEmails = append(pendingEmails, o.Email)
		}
	}
	for _, email := range pendingEmails {
		if err := db.Exec("UPDATE users SET approved = false WHERE email = ?", email).Error; err != nil {
			log.Fatalf("seed: force pending on %s: %v", email, err)
		}
	}

	return seededUsers{admin: admin, organizers: organizers, students: students}
}

// ──────────────────────────────────── Events ─────────────────────────────────

type eventBlueprint struct {
	title       string
	description string
	category    string
	tags        []string
	format      domain.EventFormat
	city        string
	address     string
	contact     string
	additional  string
	startOffset time.Duration // relative to now
	durationHrs int
	regBefore   time.Duration // how long before start the deadline closes
	capacity    int
	isFree      bool
	price       float64
	organizer   int // index into users.organizers
}

func seedEvents(db *gorm.DB, users seededUsers) []*domain.Event {
	now := time.Now().UTC().Truncate(time.Hour)

	day := 24 * time.Hour
	bps := []eventBlueprint{
		// ─── Upcoming (12) ───────────────────────────────────────────────
		{
			title: "Almaty Robotics Open 2026", category: "Robotics",
			description: "Annual citywide LEGO Spike + VEX IQ tournament. Teams of 2-4 students from grades 5-11 compete in match-play and innovation tracks.",
			tags:        []string{"robotics", "competition", "lego"},
			format:      domain.FormatOffline, city: "Almaty",
			address: "Abay Ave 76, Palace of Schoolchildren", contact: "alma@robotics.kz",
			additional:  "Bring your own robot. On-site charging stations provided.",
			startOffset: 5 * day, durationHrs: 8, regBefore: 2 * day,
			capacity: 60, isFree: true, price: 0, organizer: 0,
		},
		{
			title: "Astana Hack Weekend: Civic Tech", category: "Hackathon",
			description: "48-hour hackathon focused on civic-tech ideas (transport, education, accessibility). Mentors from Tinkoff, Kaspi, and Astana Hub.",
			tags:        []string{"hackathon", "programming", "civic-tech"},
			format:      domain.FormatOffline, city: "Astana",
			address: "Astana Hub, Mangilik El 55/15", contact: "olzhas@codelab.kz",
			additional:  "Free meals and overnight stay supported. Bring your laptop.",
			startOffset: 9 * day, durationHrs: 48, regBefore: 3 * day,
			capacity: 80, isFree: true, price: 0, organizer: 1,
		},
		{
			title: "AI/ML Bootcamp for High Schoolers", category: "AI/ML",
			description: "Six-session weekend bootcamp covering linear models, neural nets, and prompt engineering. Hands-on with PyTorch + Hugging Face.",
			tags:        []string{"ai-ml", "workshop", "python"},
			format:      domain.FormatHybrid, city: "Almaty",
			address: "AlmaU, Rozybakiev 227", contact: "dana@iot.kz",
			additional:  "Recordings and Colab notebooks shared with participants.",
			startOffset: 12 * day, durationHrs: 24, regBefore: 4 * day,
			capacity: 40, isFree: false, price: 9000, organizer: 2,
		},
		{
			title: "Shymkent IoT Spring Camp", category: "IoT",
			description: "Five-day day-camp building ESP32 + sensor projects (smart greenhouse, air-quality monitor). Kits provided on loan.",
			tags:        []string{"iot", "esp32", "hardware"},
			format:      domain.FormatOffline, city: "Shymkent",
			address: "South Kazakhstan State University, Tauke Khan 5", contact: "dana@iot.kz",
			additional:  "Daily 10:00–16:00. Lunch included.",
			startOffset: 15 * day, durationHrs: 30, regBefore: 7 * day,
			capacity: 25, isFree: false, price: 12000, organizer: 2,
		},
		{
			title: "Intro to Competitive Programming", category: "Programming",
			description: "Online crash-course for students preparing for the republican informatics olympiad. Covers greedy, DP, graphs.",
			tags:        []string{"programming", "olympiad", "algorithms"},
			format:      domain.FormatOnline, city: "Online",
			address: "Zoom (link in confirmation email)", contact: "olzhas@codelab.kz",
			additional:  "Recordings published after each session.",
			startOffset: 3 * day, durationHrs: 2, regBefore: 12 * time.Hour,
			capacity: 0, isFree: true, price: 0, organizer: 1,
		},
		{
			title: "Almaty UX/UI for Students", category: "Design",
			description: "Two-day workshop on Figma, mobile UX patterns, and design critique. Output: a finished case study for your portfolio.",
			tags:        []string{"design", "figma", "workshop"},
			format:      domain.FormatOffline, city: "Almaty",
			address: "MOST Coworking, Tole Bi 286", contact: "alma@robotics.kz",
			additional:  "Laptop required. Figma free plan is fine.",
			startOffset: 17 * day, durationHrs: 12, regBefore: 5 * day,
			capacity: 30, isFree: false, price: 6000, organizer: 0,
		},
		{
			title: "Drone Programming Challenge", category: "Robotics",
			description: "Program a Tello EDU drone to complete an obstacle course. Python only. Top 3 teams advance to nationals.",
			tags:        []string{"robotics", "drones", "python"},
			format:      domain.FormatOffline, city: "Astana",
			address: "Nazarbayev University, Block C2", contact: "olzhas@codelab.kz",
			additional:  "Drones provided. Teams of 2.",
			startOffset: 21 * day, durationHrs: 6, regBefore: 7 * day,
			capacity: 20, isFree: true, price: 0, organizer: 1,
		},
		{
			title: "Cybersecurity 101 (Online)", category: "Programming",
			description: "Beginner-friendly intro to web security: OWASP Top 10, common exploits, and a live CTF mini-round.",
			tags:        []string{"security", "ctf", "online"},
			format:      domain.FormatOnline, city: "Online",
			address: "Google Meet", contact: "dana@iot.kz",
			additional:  "Open to grades 9-12.",
			startOffset: 8 * day, durationHrs: 3, regBefore: 2 * day,
			capacity: 0, isFree: true, price: 0, organizer: 2,
		},
		{
			title: "Almaty Math Olympiad Prep Camp", category: "Competition",
			description: "Intensive week with past-paper drills and theory sessions led by IMO medalists.",
			tags:        []string{"olympiad", "math", "competition"},
			format:      domain.FormatOffline, city: "Almaty",
			address: "RSPMSh, Pushkin 87", contact: "alma@robotics.kz",
			additional:  "By application — short selection problem set on registration.",
			startOffset: 25 * day, durationHrs: 35, regBefore: 10 * day,
			capacity: 35, isFree: false, price: 15000, organizer: 0,
		},
		{
			title: "Mobile App Workshop: SwiftUI", category: "Programming",
			description: "Build your first iOS app in a weekend. Covers SwiftUI fundamentals, MVVM, and shipping to TestFlight.",
			tags:        []string{"programming", "swift", "ios"},
			format:      domain.FormatHybrid, city: "Astana",
			address: "Astana Hub, Mangilik El 55/15 — and Zoom",
			contact:    "olzhas@codelab.kz",
			additional: "Mac required for in-person; online slots see code only.",
			startOffset: 11 * day, durationHrs: 14, regBefore: 4 * day,
			capacity: 24, isFree: false, price: 8000, organizer: 1,
		},
		{
			title: "FIRST LEGO League Qualifier", category: "Robotics",
			description: "Official FLL qualifier for South Kazakhstan region. Top 5 teams advance to nationals in February.",
			tags:        []string{"robotics", "fll", "competition"},
			format:      domain.FormatOffline, city: "Shymkent",
			address: "Shymkent Sports Palace", contact: "dana@iot.kz",
			additional:  "Pre-registered teams only.",
			startOffset: 30 * day, durationHrs: 8, regBefore: 14 * day,
			capacity: 50, isFree: true, price: 0, organizer: 2,
		},
		{
			title: "Open Day: Robotics & AI Labs", category: "Workshop",
			description: "Free open-house tour of three robotics labs and one AI research group. Q&A with university students.",
			tags:        []string{"workshop", "open-day", "robotics"},
			format:      domain.FormatOffline, city: "Almaty",
			address: "SDU University, Kaskelen", contact: "alma@robotics.kz",
			additional:  "Walk-ins welcome but registration speeds up entry.",
			startOffset: 2 * day, durationHrs: 4, regBefore: 12 * time.Hour,
			capacity: 100, isFree: true, price: 0, organizer: 0,
		},

		// ─── Past (4) — drives "completed" / past tab ─────────────────────
		{
			title: "Winter Code Jam 2026", category: "Hackathon",
			description: "Three-day hackathon held in January. Theme: education tech. 14 teams competed; 4 prototypes shipped.",
			tags:        []string{"hackathon", "edtech"},
			format:      domain.FormatOffline, city: "Astana",
			address: "Astana Hub", contact: "olzhas@codelab.kz",
			startOffset: -45 * day, durationHrs: 72, regBefore: -50 * day,
			capacity: 60, isFree: true, price: 0, organizer: 1,
		},
		{
			title: "Robotics Winter Cup (regional)", category: "Robotics",
			description: "Regional preliminary that selected the South Kazakhstan team for nationals.",
			tags:        []string{"robotics", "competition"},
			format:      domain.FormatOffline, city: "Shymkent",
			address: "Shymkent Sports Palace", contact: "dana@iot.kz",
			startOffset: -30 * day, durationHrs: 8, regBefore: -34 * day,
			capacity: 40, isFree: true, price: 0, organizer: 2,
		},
		{
			title: "ML Kazakh-Language NLP Mini-Workshop", category: "AI/ML",
			description: "Two-hour intro to Kazakh tokenization and small fine-tuning on a Llama-3.2-1B instance.",
			tags:        []string{"ai-ml", "nlp", "kazakh"},
			format:      domain.FormatOnline, city: "Online",
			address: "Zoom", contact: "dana@iot.kz",
			startOffset: -14 * day, durationHrs: 2, regBefore: -16 * day,
			capacity: 0, isFree: true, price: 0, organizer: 2,
		},
		{
			title: "Almaty Spring Code Olympiad", category: "Competition",
			description: "Citywide informatics olympiad for grades 8-11. 200+ participants this year.",
			tags:        []string{"olympiad", "programming"},
			format:      domain.FormatOffline, city: "Almaty",
			address: "KBTU, Tole Bi 59", contact: "alma@robotics.kz",
			startOffset: -7 * day, durationHrs: 5, regBefore: -10 * day,
			capacity: 200, isFree: true, price: 0, organizer: 0,
		},

		// ─── Imminent (2) — exercise reminders / "happening soon" ─────────
		{
			title: "Friday Algo Circle (online)", category: "Programming",
			description: "Weekly competitive-programming meetup. This Friday: dynamic programming problem set.",
			tags:        []string{"programming", "weekly", "online"},
			format:      domain.FormatOnline, city: "Online",
			address: "Discord", contact: "olzhas@codelab.kz",
			startOffset: 1 * day, durationHrs: 2, regBefore: 6 * time.Hour,
			capacity: 0, isFree: true, price: 0, organizer: 1,
		},
		{
			title: "Open Robotics Lab Tour (Almaty)", category: "Workshop",
			description: "Tomorrow only — guided tour of the Almaty Robotics League workshop. Limited to 25 students.",
			tags:        []string{"workshop", "tour"},
			format:      domain.FormatOffline, city: "Almaty",
			address: "Abay Ave 76", contact: "alma@robotics.kz",
			startOffset: 1*day + 8*time.Hour, durationHrs: 2, regBefore: 4 * time.Hour,
			capacity: 25, isFree: true, price: 0, organizer: 0,
		},
	}

	out := make([]*domain.Event, 0, len(bps))
	for _, b := range bps {
		start := now.Add(b.startOffset)
		end := start.Add(time.Duration(b.durationHrs) * time.Hour)
		deadline := start.Add(-b.regBefore)

		token := randHex32()
		ev := &domain.Event{
			Title:            b.title,
			Description:      b.description,
			Category:         b.category,
			Tags:             b.tags,
			Format:           b.format,
			City:             b.city,
			Address:          b.address,
			OrganizerContact: b.contact,
			AdditionalInfo:   b.additional,
			DateStart:        start,
			DateEnd:          &end,
			RegDeadline:      &deadline,
			Capacity:         b.capacity,
			IsFree:           b.isFree,
			Price:            b.price,
			CheckinToken:     token,
			OrganizerID:      users.organizers[b.organizer].ID,
		}
		mustCreate(db, ev)
		out = append(out, ev)
	}
	return out
}

// ───────────────────────────────── Registrations ─────────────────────────────

// seedRegistrations writes a deliberate spread across every status the
// registration state machine supports, so the iOS "My Events" tabs
// (upcoming / past) and organizer participants screens both have content.
func seedRegistrations(db *gorm.DB, users seededUsers, events []*domain.Event) {
	now := time.Now().UTC()
	type plan struct {
		studentIdx int
		eventIdx   int
		status     domain.RegStatus
		checkedIn  bool // sets checked_in_at when true
	}
	plans := []plan{
		// Nurlan (Almaty 11th grader) — heavy participant
		{0, 0, domain.StatusApproved, false},        // Almaty Robotics Open
		{0, 2, domain.StatusPending, false},         // AI/ML Bootcamp
		{0, 4, domain.StatusApproved, false},        // Intro CP (online)
		{0, 11, domain.StatusApproved, false},       // Open Day Robotics & AI
		{0, 12, domain.StatusCompleted, true},       // Past Winter Code Jam
		{0, 15, domain.StatusCompleted, true},       // Past Spring Code Olympiad
		{0, 16, domain.StatusApproved, false},       // Friday Algo Circle

		// Aisha (Almaty 10th grader) — design + programming
		{1, 5, domain.StatusApproved, false},        // UX/UI workshop
		{1, 9, domain.StatusWaitlisted, false},      // SwiftUI workshop
		{1, 11, domain.StatusApproved, false},       // Open Day
		{1, 17, domain.StatusPending, false},        // Tomorrow's Robotics Tour
		{1, 15, domain.StatusCompleted, true},       // Past Spring Olympiad
		{1, 0, domain.StatusCancelled, false},       // cancelled Robotics Open

		// Daniyar (Astana 12th grader) — hackathon hunter
		{2, 1, domain.StatusApproved, false},        // Astana Hack Weekend
		{2, 6, domain.StatusApproved, false},        // Drone Programming
		{2, 9, domain.StatusApproved, false},        // SwiftUI workshop
		{2, 7, domain.StatusApproved, false},        // Cybersecurity 101
		{2, 12, domain.StatusCompleted, true},       // Past Winter Code Jam
		{2, 16, domain.StatusApproved, false},       // Friday Algo Circle
		{2, 2, domain.StatusRejected, false},        // AI/ML Bootcamp — rejected (out of region)

		// Samal (Shymkent 9th grader) — IoT/robotics
		{3, 3, domain.StatusApproved, false},        // Shymkent IoT Spring Camp
		{3, 10, domain.StatusPending, false},        // FIRST LEGO Qualifier
		{3, 7, domain.StatusApproved, false},        // Cybersecurity 101
		{3, 13, domain.StatusCompleted, true},       // Past Robotics Winter Cup
		{3, 14, domain.StatusCompleted, true},       // Past ML NLP workshop
		{3, 9, domain.StatusWaitlisted, false},      // SwiftUI workshop (filling waitlist alongside Aisha)
	}

	for _, p := range plans {
		ev := events[p.eventIdx]
		st := users.students[p.studentIdx]
		reg := &domain.Registration{
			UserID:    st.ID,
			EventID:   ev.ID,
			Status:    p.status,
			CreatedAt: now.Add(-time.Duration(7+p.eventIdx) * 24 * time.Hour),
		}
		if p.checkedIn {
			t := ev.DateStart.Add(15 * time.Minute)
			reg.CheckedInAt = &t
		}
		mustCreate(db, reg)
	}
}

// ─────────────────────────────────── Favorites ───────────────────────────────

func seedFavorites(db *gorm.DB, users seededUsers, events []*domain.Event) {
	pairs := []struct{ student, event int }{
		{0, 1}, {0, 2}, {0, 6},
		{1, 5}, {1, 9}, {1, 11},
		{2, 1}, {2, 8}, {2, 10},
		{3, 3}, {3, 10},
	}
	for _, p := range pairs {
		fav := &domain.Favorite{
			UserID:  users.students[p.student].ID,
			EventID: events[p.event].ID,
		}
		mustCreate(db, fav)
	}
}

// ───────────────────────────────── Notifications ─────────────────────────────

func seedNotifications(db *gorm.DB, users seededUsers, events []*domain.Event) {
	notif := func(userID, eventID uint, t domain.NotificationType, title, body string, read bool) *domain.Notification {
		eid := eventID
		return &domain.Notification{
			UserID:    userID,
			EventID:   &eid,
			Type:      t,
			Title:     title,
			Body:      body,
			Read:      read,
			CreatedAt: time.Now().UTC().Add(-3 * time.Hour),
		}
	}
	mustCreate(db, notif(users.students[0].ID, events[0].ID,
		domain.NotifRegistrationApproved,
		"Registration approved",
		"You're confirmed for "+events[0].Title+".", false))
	mustCreate(db, notif(users.students[2].ID, events[1].ID,
		domain.NotifRegistrationApproved,
		"Registration approved",
		"You're confirmed for "+events[1].Title+".", false))
	mustCreate(db, notif(users.students[1].ID, events[9].ID,
		domain.NotifRegistrationSubmitted,
		"On the waitlist",
		"You're #2 on the waitlist for "+events[9].Title+".", true))
	mustCreate(db, notif(users.students[3].ID, events[10].ID,
		domain.NotifEventReminder,
		"Event soon",
		events[10].Title+" starts in 3 days.", false))
}

// ────────────────────────────────── Helpers ──────────────────────────────────

func truncateAll(db *gorm.DB) error {
	// CASCADE handles FK chains; RESTART IDENTITY resets bigserials so
	// re-running the seed produces stable IDs.
	return db.Exec(`TRUNCATE TABLE
		audit_logs, device_tokens, notifications,
		favorites, registrations, events, users
		RESTART IDENTITY CASCADE`).Error
}

func mustCreate(db *gorm.DB, v any) {
	if err := db.Create(v).Error; err != nil {
		log.Fatalf("seed: create %T: %v", v, err)
	}
}

func randHex32() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}

func getEnv(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}
