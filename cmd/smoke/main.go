// Command smoke runs a minimal end-to-end smoke suite against a running
// EventApp API (defaults to http://localhost:8080) populated with the
// seeded demo dataset. It exercises the highest-confidence MVP flows:
//
//   - GET /health
//   - POST /auth/login (admin, organizer, student)
//   - GET /api/events (list)
//   - GET /api/events/:id (detail)
//   - POST /api/events/:id/favorite + DELETE /api/events/:id/favorite
//   - POST /api/events/:id/apply (student → registration)
//   - POST /api/events (organizer creates event)
//   - PATCH /api/admin/organizers/:id/approve (admin approves pending organizer)
//
// Exits with a non-zero status if any check fails.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

var (
	baseURL = flag.String("base", envOr("SMOKE_BASE_URL", "http://localhost:8080"), "API base URL")
	pw      = flag.String("password", envOr("SEED_PASSWORD", "Password123!"), "seeded password")
)

type result struct {
	name string
	ok   bool
	msg  string
}

var results []result

func main() {
	flag.Parse()
	log.SetFlags(0)

	checkHealth()

	adminTok, _ := login(envOr("SEED_ADMIN_EMAIL", "admin@eventapp.local"))
	orgTok, _ := login("alma@robotics.kz")
	studentTok, studentID := login("nurlan@school.kz")

	listEvents(studentTok)
	eventID := getFirstUpcomingEvent(studentTok)
	getEventDetail(studentTok, eventID)

	favoriteRoundtrip(studentTok, eventID)

	// Apply uses an event the seed didn't already register Nurlan to —
	// pick one with capacity (FLL Qualifier, ID may vary; we look it up).
	applyEventID := findEventByTitle(studentTok, "FIRST LEGO League Qualifier")
	if applyEventID > 0 {
		applyToEvent(studentTok, applyEventID)
	} else {
		record("student-apply", false, "could not locate FLL Qualifier event")
	}

	createOrganizerEvent(orgTok)
	approvePendingOrganizer(adminTok)

	_ = studentID

	// ── Report ───────────────────────────────────────────────────────────
	fmt.Println()
	fmt.Println("──────── SMOKE RESULTS ────────")
	failed := 0
	for _, r := range results {
		mark := "✓"
		if !r.ok {
			mark = "✗"
			failed++
		}
		extra := ""
		if r.msg != "" {
			extra = "  " + r.msg
		}
		fmt.Printf("  %s %-40s%s\n", mark, r.name, extra)
	}
	fmt.Printf("───────────────────────────────\n%d passed, %d failed\n", len(results)-failed, failed)
	if failed > 0 {
		os.Exit(1)
	}
}

// ─────────────────────────────── Checks ──────────────────────────────────────

func checkHealth() {
	r, err := http.Get(*baseURL + "/health")
	if err != nil {
		record("GET /health", false, err.Error())
		return
	}
	defer r.Body.Close()
	record("GET /health", r.StatusCode == 200, fmt.Sprintf("status=%d", r.StatusCode))
}

func login(email string) (token string, userID float64) {
	body := map[string]string{"email": email, "password": *pw}
	resp, err := postJSON("", "/auth/login", body)
	if err != nil {
		record("login "+email, false, err.Error())
		return
	}
	if resp.status != 200 {
		record("login "+email, false, fmt.Sprintf("status=%d body=%s", resp.status, snippet(resp.body)))
		return
	}
	var out struct {
		AccessToken string         `json:"access_token"`
		User        map[string]any `json:"user"`
	}
	if err := json.Unmarshal(resp.body, &out); err != nil {
		record("login "+email, false, "decode: "+err.Error())
		return
	}
	token = out.AccessToken
	if id, ok := out.User["id"].(float64); ok {
		userID = id
	}
	record("login "+email, token != "", "")
	return
}

func listEvents(tok string) {
	resp, err := getJSON(tok, "/api/events?limit=50")
	if err != nil {
		record("GET /api/events", false, err.Error())
		return
	}
	if resp.status != 200 {
		record("GET /api/events", false, fmt.Sprintf("status=%d", resp.status))
		return
	}
	var out struct {
		Data  []map[string]any `json:"data"`
		Total int              `json:"total"`
	}
	_ = json.Unmarshal(resp.body, &out)
	record("GET /api/events", out.Total >= 16, fmt.Sprintf("total=%d (expected >= 16)", out.Total))
}

func getFirstUpcomingEvent(tok string) uint {
	resp, _ := getJSON(tok, "/api/events?limit=50")
	var out struct {
		Data []map[string]any `json:"data"`
	}
	_ = json.Unmarshal(resp.body, &out)
	now := time.Now()
	for _, ev := range out.Data {
		ds, _ := ev["date_start"].(string)
		t, err := time.Parse(time.RFC3339, ds)
		if err == nil && t.After(now) {
			if id, ok := ev["id"].(float64); ok {
				return uint(id)
			}
		}
	}
	if len(out.Data) > 0 {
		if id, ok := out.Data[0]["id"].(float64); ok {
			return uint(id)
		}
	}
	return 0
}

func findEventByTitle(tok, title string) uint {
	resp, _ := getJSON(tok, "/api/events?limit=50")
	var out struct {
		Data []map[string]any `json:"data"`
	}
	_ = json.Unmarshal(resp.body, &out)
	for _, ev := range out.Data {
		if t, _ := ev["title"].(string); t == title {
			if id, ok := ev["id"].(float64); ok {
				return uint(id)
			}
		}
	}
	return 0
}

func getEventDetail(tok string, id uint) {
	resp, err := getJSON(tok, fmt.Sprintf("/api/events/%d", id))
	if err != nil {
		record("GET /api/events/:id", false, err.Error())
		return
	}
	record("GET /api/events/:id", resp.status == 200, fmt.Sprintf("id=%d status=%d", id, resp.status))
}

func favoriteRoundtrip(tok string, id uint) {
	addResp, err := postJSON(tok, fmt.Sprintf("/api/events/%d/favorite", id), nil)
	if err != nil {
		record("favorite add", false, err.Error())
		return
	}
	addOK := addResp.status == 200 || addResp.status == 201 || addResp.status == 409
	record("POST /api/events/:id/favorite", addOK, fmt.Sprintf("status=%d", addResp.status))

	delResp, err := deleteReq(tok, fmt.Sprintf("/api/events/%d/favorite", id))
	if err != nil {
		record("favorite remove", false, err.Error())
		return
	}
	record("DELETE /api/events/:id/favorite", delResp.status == 200 || delResp.status == 204,
		fmt.Sprintf("status=%d", delResp.status))
}

func applyToEvent(tok string, id uint) {
	resp, err := postJSON(tok, fmt.Sprintf("/api/events/%d/apply", id), nil)
	if err != nil {
		record("POST /api/events/:id/apply", false, err.Error())
		return
	}
	// 201 = newly created; 409 = already registered (acceptable for re-runs)
	ok := resp.status == 201 || resp.status == 200 || resp.status == 409
	record("POST /api/events/:id/apply", ok,
		fmt.Sprintf("status=%d body=%s", resp.status, snippet(resp.body)))
}

func createOrganizerEvent(tok string) {
	body := map[string]any{
		"title":       "Smoke-test Workshop " + time.Now().Format("150405"),
		"description": "Created by the smoke runner.",
		"category":    "Workshop",
		"format":      "online",
		"city":        "Online",
		"date_start":  time.Now().Add(48 * time.Hour).UTC().Format(time.RFC3339),
		"capacity":    10,
		"is_free":     true,
	}
	resp, err := postJSON(tok, "/api/events", body)
	if err != nil {
		record("organizer create event", false, err.Error())
		return
	}
	record("POST /api/events (organizer)", resp.status == 201,
		fmt.Sprintf("status=%d body=%s", resp.status, snippet(resp.body)))
}

func approvePendingOrganizer(adminTok string) {
	// Find the pending organizer (Yerlan) by listing /admin/organizers/pending.
	resp, err := getJSON(adminTok, "/api/admin/organizers/pending")
	if err != nil {
		record("admin approve organizer", false, err.Error())
		return
	}
	if resp.status != 200 {
		record("admin approve organizer", false, fmt.Sprintf("list status=%d", resp.status))
		return
	}
	// /admin/organizers/pending returns a bare JSON array of UserProfile.
	var out []struct {
		ID    float64 `json:"id"`
		Email string  `json:"email"`
	}
	if err := json.Unmarshal(resp.body, &out); err != nil {
		record("admin approve organizer", false, "decode: "+err.Error())
		return
	}
	if len(out) == 0 {
		// Already approved on a previous run — treat as pass.
		record("admin approve organizer", true, "no pending organizers (already approved)")
		return
	}
	id := uint(out[0].ID)
	patchResp, err := patchReq(adminTok, fmt.Sprintf("/api/admin/organizers/%d/approve", id))
	if err != nil {
		record("admin approve organizer", false, err.Error())
		return
	}
	record("PATCH /api/admin/organizers/:id/approve", patchResp.status == 200,
		fmt.Sprintf("id=%d status=%d", id, patchResp.status))
}

// ────────────────────────────── HTTP helpers ─────────────────────────────────

type httpResp struct {
	status int
	body   []byte
}

func doReq(method, tok, path string, body io.Reader) (*httpResp, error) {
	req, err := http.NewRequest(method, *baseURL+path, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if tok != "" {
		req.Header.Set("Authorization", "Bearer "+tok)
	}
	r, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()
	b, _ := io.ReadAll(r.Body)
	return &httpResp{status: r.StatusCode, body: b}, nil
}

func getJSON(tok, path string) (*httpResp, error)    { return doReq("GET", tok, path, nil) }
func deleteReq(tok, path string) (*httpResp, error)  { return doReq("DELETE", tok, path, nil) }
func patchReq(tok, path string) (*httpResp, error)   { return doReq("PATCH", tok, path, nil) }

func postJSON(tok, path string, body any) (*httpResp, error) {
	var r io.Reader
	if body != nil {
		buf, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}
		r = bytes.NewReader(buf)
	}
	return doReq("POST", tok, path, r)
}

func record(name string, ok bool, msg string) {
	results = append(results, result{name: name, ok: ok, msg: msg})
}

func envOr(k, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(k)); v != "" {
		return v
	}
	return fallback
}

func snippet(b []byte) string {
	const n = 160
	if len(b) > n {
		return string(b[:n]) + "…"
	}
	return string(b)
}
