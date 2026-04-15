import SwiftUI
import PhotosUI

// MARK: - EventFormMode

enum EventFormMode {
    case create
    case edit(Event)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    var navigationTitle: String {
        isEdit ? "Edit Event" : "New Event"
    }

    var submitLabel: String {
        isEdit ? "Save Changes" : "Create Event"
    }
}

// MARK: - ViewModel

@MainActor
final class EventFormViewModel: ObservableObject {
    @Published var state: Loadable<Event> = .idle
    @Published var uploadState: Loadable<String> = .idle  // uploaded poster URL

    let toast = ToastPresenter()
    var onSaved: ((Event) -> Void)?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Upload Poster

    func uploadPoster(imageData: Data) async {
        uploadState = .loading
        do {
            let resp: UploadResponse = try await api.uploadImage(
                path: "/api/upload",
                imageData: imageData,
                filename: "poster.jpg",
                mimeType: "image/jpeg",
                responseType: UploadResponse.self
            )
            uploadState = .success(resp.url)
            toast.showSuccess("Poster uploaded")
        } catch {
            uploadState = .failure(error)
            toast.showError(error)
        }
    }

    // MARK: - Create

    func create(title: String, description: String, category: String,
                tags: [String], format: EventFormat, city: String,
                address: String, organizerContact: String,
                additionalInfo: String,
                dateStart: Date, dateEnd: Date?, regDeadline: Date?,
                capacity: Int, isFree: Bool, price: Double,
                posterURL: String?) async {
        state = .loading
        do {
            var body = CreateEventBody(
                title: title, description: description,
                category: category, tags: tags, format: format.rawValue,
                city: city, address: address,
                organizerContact: organizerContact,
                additionalInfo: additionalInfo,
                dateStart: dateStart, dateEnd: dateEnd,
                regDeadline: regDeadline,
                capacity: capacity, isFree: isFree, price: price
            )
            body.posterURL = posterURL
            let event: Event = try await api.request(
                .createEvent(body: body),
                responseType: Event.self
            )
            state = .success(event)
            onSaved?(event)
        } catch {
            state = .failure(error)
            toast.showError(error)
        }
    }

    // MARK: - Update

    func update(eventID: Int, title: String, description: String, category: String,
                tags: [String], format: EventFormat, city: String,
                address: String, organizerContact: String,
                additionalInfo: String,
                dateStart: Date, dateEnd: Date?, regDeadline: Date?,
                capacity: Int, isFree: Bool, price: Double,
                posterURL: String?) async {
        state = .loading
        do {
            let body = FullUpdateEventBody(
                title: title, description: description,
                category: category, tags: tags, format: format.rawValue,
                city: city, address: address,
                organizerContact: organizerContact,
                additionalInfo: additionalInfo,
                dateStart: dateStart, dateEnd: dateEnd,
                regDeadline: regDeadline,
                capacity: capacity, isFree: isFree, price: price,
                posterURL: posterURL
            )
            let event: Event = try await api.request(
                .updateEvent(id: eventID, body: body),
                responseType: Event.self
            )
            state = .success(event)
            toast.showSuccess("Event updated")
            onSaved?(event)
        } catch {
            state = .failure(error)
            toast.showError(error)
        }
    }

    // MARK: - Delete

    func delete(eventID: Int) async -> Bool {
        do {
            try await api.requestVoid(.deleteEvent(id: eventID))
            toast.showSuccess("Event deleted")
            return true
        } catch {
            toast.showError(error)
            return false
        }
    }
}

// MARK: - EventFormView (shared create/edit)

struct EventFormView: View {
    let mode: EventFormMode
    var onSaved: ((Event) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = EventFormViewModel()

    // Form fields
    @State private var title            = ""
    @State private var description      = ""
    @State private var selectedCategories: [String] = []
    @State private var tagsText         = ""
    @State private var format           = EventFormat.offline
    @State private var city             = ""
    @State private var address          = ""
    @State private var organizerContact = ""
    @State private var additionalInfo   = ""
    @State private var dateStart        = Date().addingTimeInterval(86400)
    @State private var dateEnd: Date?   = nil
    @State private var hasEndDate       = false
    @State private var regDeadline: Date? = nil
    @State private var hasDeadline      = false
    @State private var capacity         = 0
    @State private var isFree           = true
    @State private var price: Double    = 0
    @State private var existingPosterURL: String? = nil

    // Poster upload
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var posterPreview: UIImage? = nil

    private var availableCities: [String] {
        var values = AppCatalog.cities
        if !city.isEmpty && !values.contains(city) {
            values.insert(city, at: 0)
        }
        return values
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Poster
                Section("Poster Image") {
                    posterSection
                }

                Section("Basic Info") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    categorySelectionSection
                    TextField("Tags (comma-separated)", text: $tagsText)
                }

                Section("Format & Location") {
                    Picker("Format", selection: $format) {
                        ForEach(EventFormat.allCases, id: \.rawValue) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    Picker("City", selection: $city) {
                        Text("Not specified").tag("")
                        ForEach(availableCities, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("Address / Venue", text: $address)
                }

                Section("Contact & Info") {
                    TextField("Organizer contact (email/phone)", text: $organizerContact)
                    TextField("Additional info / FAQ", text: $additionalInfo, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Schedule") {
                    DatePicker("Start Date *", selection: $dateStart,
                               displayedComponents: [.date, .hourAndMinute])
                    Toggle("Has End Date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date",
                                   selection: Binding(
                                    get: { dateEnd ?? dateStart },
                                    set: { dateEnd = $0 }),
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                    Toggle("Registration Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Deadline",
                                   selection: Binding(
                                    get: { regDeadline ?? dateStart },
                                    set: { regDeadline = $0 }),
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Capacity & Pricing") {
                    Stepper(capacity == 0 ? "Unlimited" : "\(capacity) spots",
                            value: $capacity, in: 0...1000, step: 10)
                    Toggle("Free Event", isOn: $isFree)
                    if !isFree {
                        HStack {
                            Text("Price (KZT)")
                            Spacer()
                            TextField("0", value: $price, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                    }
                }

                if case .failure(let error) = vm.state {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: submit) {
                        if vm.state.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(mode.submitLabel).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.state.isLoading || title.isEmpty || selectedCategories.isEmpty)
                }
            }
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .toastOverlay(vm.toast)
        }
        .onAppear {
            vm.onSaved = { event in
                onSaved?(event)
                dismiss()
            }
            if case .edit(let event) = mode {
                populateFromEvent(event)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
    }

    // MARK: - Poster Section

    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Categories *")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)

            FlowLayout(spacing: 8) {
                ForEach(AppCatalog.eventCategories, id: \.self) { option in
                    Button {
                        toggleCategory(option)
                    } label: {
                        Text(option)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedCategories.contains(option) ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                if selectedCategories.contains(option) {
                                    Capsule().fill(AppTheme.primaryGradient)
                                } else {
                                    Capsule()
                                        .fill(AppTheme.surface)
                                        .overlay {
                                            Capsule().strokeBorder(AppTheme.divider, lineWidth: 1)
                                        }
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let primary = selectedCategories.first {
                Text("Primary category: \(primary)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("Choose at least one category.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var posterSection: some View {
        if let preview = posterPreview {
            Image(uiImage: preview)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .overlay(alignment: .topTrailing) {
                    Button {
                        posterPreview = nil
                        selectedPhoto = nil
                        existingPosterURL = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
        } else if let urlStr = existingPosterURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                } else {
                    posterPlaceholder
                }
            }
        } else {
            posterPlaceholder
        }

        if vm.uploadState.isLoading {
            HStack {
                ProgressView()
                Text("Uploading...").font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
        }

        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Label(posterPreview != nil || existingPosterURL != nil ? "Change Photo" : "Add Poster Photo",
                  systemImage: "photo.on.rectangle")
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
            .fill(AppTheme.primary.opacity(0.08))
            .frame(height: 120)
            .overlay {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No poster")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
    }

    // MARK: - Photo loading + upload

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        posterPreview = image

        // Compress and upload
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return }
        await vm.uploadPoster(imageData: jpegData)
    }

    // MARK: - Populate for edit

    private func populateFromEvent(_ event: Event) {
        title = event.title
        description = event.description ?? ""
        var categories = [String]()
        if let category = event.category, !category.isEmpty {
            categories.append(category)
        }
        if let tags = event.tags {
            categories.append(contentsOf: tags.filter(AppCatalog.eventCategories.contains))
        }
        selectedCategories = Array(NSOrderedSet(array: categories)) as? [String] ?? categories
        tagsText = event.tags?.joined(separator: ", ") ?? ""
        format = event.format ?? .offline
        city = event.city ?? ""
        address = event.address ?? ""
        organizerContact = event.organizerContact ?? ""
        additionalInfo = event.additionalInfo ?? ""
        dateStart = event.dateStart
        if let end = event.dateEnd {
            dateEnd = end
            hasEndDate = true
        }
        if let dl = event.regDeadline {
            regDeadline = dl
            hasDeadline = true
        }
        capacity = event.capacity
        isFree = event.isFree ?? true
        price = event.price ?? 0
        existingPosterURL = event.posterURL
    }

    // MARK: - Submit

    private var resolvedPosterURL: String? {
        if case .success(let url) = vm.uploadState { return url }
        return existingPosterURL
    }

    private var parsedTags: [String] {
        tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var eventCategory: String {
        selectedCategories.first ?? ""
    }

    private var eventTags: [String] {
        var combined = selectedCategories
        combined.append(contentsOf: parsedTags)
        var unique: [String] = []
        for item in combined where !item.isEmpty {
            if !unique.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                unique.append(item)
            }
        }
        return unique
    }

    private func toggleCategory(_ option: String) {
        if let index = selectedCategories.firstIndex(of: option) {
            selectedCategories.remove(at: index)
        } else {
            selectedCategories.append(option)
        }
    }

    private func submit() {
        Task {
            switch mode {
            case .create:
                await vm.create(
                    title: title, description: description, category: eventCategory,
                    tags: eventTags, format: format, city: city, address: address,
                    organizerContact: organizerContact, additionalInfo: additionalInfo,
                    dateStart: dateStart, dateEnd: hasEndDate ? dateEnd : nil,
                    regDeadline: hasDeadline ? regDeadline : nil,
                    capacity: capacity, isFree: isFree, price: isFree ? 0 : price,
                    posterURL: resolvedPosterURL
                )
            case .edit(let event):
                await vm.update(
                    eventID: event.id,
                    title: title, description: description, category: eventCategory,
                    tags: eventTags, format: format, city: city, address: address,
                    organizerContact: organizerContact, additionalInfo: additionalInfo,
                    dateStart: dateStart, dateEnd: hasEndDate ? dateEnd : nil,
                    regDeadline: hasDeadline ? regDeadline : nil,
                    capacity: capacity, isFree: isFree, price: isFree ? 0 : price,
                    posterURL: resolvedPosterURL
                )
            }
        }
    }
}

// Keep backward compatibility — CreateEventView wraps EventFormView in create mode.
struct CreateEventView: View {
    var onCreated: ((Event) -> Void)? = nil

    var body: some View {
        EventFormView(mode: .create, onSaved: onCreated)
    }
}
