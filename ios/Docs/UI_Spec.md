# UI Gap Analysis & Target Spec

## Phase 1 — Gap Analysis

### Current navigation graph
```
ContentView
  ├── (not authenticated) → LoginView → RegisterView
  └── (authenticated) → MainTabView
        ├── Tab 1: EventListView (plain .navigationTitle "Events", sheet filters)
        ├── Tab 2: MyEventsView (plain list, no segmented control)
        └── Tab 3: ProfileView (plain List, system icons)
```

### What's missing vs screenshots

| Area | Screenshot requires | Currently |
|---|---|---|
| Onboarding | 3-page swipe flow before auth | ❌ missing |
| SignIn | Gradient CTA, icon text fields, "Forgot password?", Google button, new layout | ❌ plain form |
| Discover | Greeting header, search bar, filter chips (horizontal scroll), count label, new EventCard | ❌ sheet filters, old card |
| EventCard | Date box (left column), organizer, time range, price/capacity badges | ❌ basic card |
| Event Detail | Hero image/gradient, info card with labeled rows, Requirements section | ❌ no hero |
| My Events | Segmented "Upcoming / Past" control, applied-date text on card | ❌ plain list |
| Profile | Gradient header card with initials, Settings rows | ❌ plain list |
| Design system | Color tokens, gradient button, custom text field, FilterChip | ❌ none |

---

## Phase 2 — Target UI Spec

### Navigation Flow
```
Launch
  └── hasSeenOnboarding? (UserDefaults)
        ├── false → OnboardingView (3 pages) → [Get Started] → SignInView
        └── true  → isAuthenticated?
                      ├── true  → MainTabView
                      └── false → SignInView
```

### Design Tokens
```
Primary:    #4A6BF5  (blue)
Secondary:  #8C5CF6  (purple)
Gradient:   leading → trailing (primary → secondary)
Background: Color(.systemGroupedBackground)  ← light gray list bg
Surface:    Color(.systemBackground)          ← white card
TextPrimary:    Color(.label)
TextSecondary:  Color(.secondaryLabel)
Success: Color.green
Warning: Color.orange
Error:   Color.red
```

### Typography
```
screenTitle:  largeTitle .bold()      "Discover Events"
cardTitle:    .headline               event card title
bodyText:     .body                   descriptions
caption:      .caption / .caption2   badges, meta
```

### Components Checklist
- [x] AppTheme (colors, spacing, radius, gradient)
- [x] PrimaryButton (gradient, full-width)
- [x] SecondaryButton (outlined)
- [x] IconTextField (prefix SF Symbol + text field)
- [x] FilterChip (pill, selected/unselected)
- [x] EventCard (date box + content + badges)
- [x] StatusBadge (Submitted=blue, Approved=green, Rejected=red)
- [x] OnboardingView (3 pages + paging)
- [x] SignInView (new layout)
- [x] DiscoverView (search + chips + count + list)
- [x] EventDetailView (hero + info card + sections)
- [x] MyEventsView (segmented + cards)
- [x] ProfileView (gradient header + rows + settings)
