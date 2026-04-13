import SwiftUI

struct EditProfileView: View {
    @StateObject private var vm = EditProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    let user: User
    var onSaved: ((User) -> Void)?

    private let gradeRange = Array(1...12)
    private let suggestedInterests = [
        "Robotics", "Programming", "AI/ML", "Mathematics",
        "Science", "Cybersecurity", "3D Printing", "Design"
    ]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Basic Info
                Section("Basic Info") {
                    IconTextField(icon: "person", placeholder: "Full name", text: $vm.fullName)
                    IconTextField(icon: "phone", placeholder: "Phone", text: $vm.phone,
                                  keyboardType: .phonePad)
                    IconTextField(icon: "mappin", placeholder: "City", text: $vm.city)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                // MARK: Student Info (only for students)
                if user.role == .student {
                    Section("School") {
                        IconTextField(icon: "building.columns", placeholder: "School name",
                                      text: $vm.school)

                        Picker("Grade", selection: $vm.grade) {
                            Text("Not set").tag(0)
                            ForEach(gradeRange, id: \.self) { g in
                                Text("Grade \(g)").tag(g)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                // MARK: Bio
                Section("About") {
                    ZStack(alignment: .topLeading) {
                        if vm.bio.isEmpty {
                            Text("Tell organizers about yourself...")
                                .foregroundStyle(AppTheme.textTertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $vm.bio)
                            .frame(minHeight: 80)
                    }
                }

                // MARK: Interests
                Section {
                    interestsContent
                } header: {
                    Text("Interests")
                } footer: {
                    Text("Tap suggestions or type your own. Max 20.")
                        .font(.caption)
                }

                // MARK: Privacy
                Section("Privacy") {
                    Toggle(isOn: $vm.visibleToOrganizers) {
                        Label("Visible to organizers", systemImage: "eye")
                    }
                    Toggle(isOn: $vm.visibleToSchool) {
                        Label("Visible to school", systemImage: "building.columns")
                    }
                }

                // MARK: Error
                if let error = vm.state.error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(AppTheme.error)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.save() }
                    }
                    .disabled(!vm.isValid || vm.state.isLoading)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                vm.populate(from: user)
                vm.onSaved = { updatedUser in
                    onSaved?(updatedUser)
                    dismiss()
                }
            }
            .interactiveDismissDisabled(vm.state.isLoading)
        }
    }

    // MARK: - Interests Content

    private var interestsContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Current interests as removable chips
            if !vm.interests.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(vm.interests, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                            Button {
                                vm.removeInterest(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.primary.opacity(0.12))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(Capsule())
                    }
                }
            }

            // Add custom interest
            HStack {
                TextField("Add interest...", text: $vm.newInterest)
                    .textInputAutocapitalization(.words)
                    .onSubmit { vm.addInterest() }
                if !vm.newInterest.isEmpty {
                    Button("Add") { vm.addInterest() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }

            // Suggestions
            let remaining = suggestedInterests.filter { s in
                !vm.interests.contains(where: { $0.lowercased() == s.lowercased() })
            }
            if !remaining.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(remaining, id: \.self) { suggestion in
                            Button {
                                vm.interests.append(suggestion)
                            } label: {
                                Text("+ \(suggestion)")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.surface)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(AppTheme.divider, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - FlowLayout (simple wrapping layout for interest chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x,
                                               y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
