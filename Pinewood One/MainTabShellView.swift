import SwiftUI

struct MainTabShellView: View {
    @ObservedObject var appState: AppState
    @State private var isShowingUserProfile = false

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            UpcomingTabView(appState: appState) {
                isShowingUserProfile = true
            }
            .tabItem {
                Label("Upcoming", systemImage: "calendar")
            }
            .tag(AppState.AppTab.upcoming)

            ComingSoonTabView(title: "Schedule", appState: appState) {
                isShowingUserProfile = true
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar.day.timeline.leading")
            }
            .tag(AppState.AppTab.schedule)

            ComingSoonTabView(title: "Grades", appState: appState) {
                isShowingUserProfile = true
            }
            .tabItem {
                Label("Grades", systemImage: "checklist")
            }
            .tag(AppState.AppTab.grades)

            ComingSoonTabView(title: "Chat", appState: appState) {
                isShowingUserProfile = true
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }
            .tag(AppState.AppTab.chat)
        }
        .sheet(isPresented: $isShowingUserProfile) {
            UserProfileSheetView(appState: appState)
        }
    }
}

private struct UpcomingTabView: View {
    @ObservedObject var appState: AppState
    let showProfile: () -> Void

    @State private var assignments: [UpcomingAssignment] = []
    @State private var bannerURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let bannerURL {
                        AsyncImage(url: bannerURL) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Color.gray.opacity(0.22)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    if assignments.isEmpty && !isLoading {
                        Text("No upcoming assignments.")
                            .foregroundStyle(.secondary)
                    } else {
                        TabView {
                            ForEach(assignments) { assignment in
                                UpcomingCard(assignment: assignment)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(height: 270)
                    }
                }
                .padding()
            }
            .navigationTitle("Upcoming")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileAvatarButton(user: appState.user, action: showProfile)
                }
            }
            .task {
                await loadData(refreshSchoology: false)
            }
            .refreshable {
                await loadData(refreshSchoology: true)
            }
        }
    }

    private func loadData(refreshSchoology: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if refreshSchoology {
                try await appState.sessionManager.refreshSchoologyData()
            }
            assignments = try await appState.fetchUpcomingAssignments(refreshSchoology: false)
            bannerURL = await appState.fetchBannerURL()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct UpcomingCard: View {
    let assignment: UpcomingAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(assignment.title)
                .font(.title3.bold())
                .lineLimit(2)

            Text("Due: \(assignment.due)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(assignment.courseTitle)
                .font(.headline)

            if !assignment.sectionTitle.isEmpty {
                Text(assignment.sectionTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !assignment.assignmentDescription.isEmpty {
                Text(assignment.assignmentDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ComingSoonTabView: View {
    let title: String
    @ObservedObject var appState: AppState
    let showProfile: () -> Void

    var body: some View {
        NavigationStack {
            Text("\(title) is coming soon.")
                .foregroundStyle(.secondary)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileAvatarButton(user: appState.user, action: showProfile)
                    }
                }
        }
    }
}

private struct ProfileAvatarButton: View {
    let user: MobileUser?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileAvatarView(user: user, size: 34)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("Open profile")
    }
}

private struct ProfileAvatarView: View {
    let user: MobileUser?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let avatarURL = resolvedAvatarURL(from: user?.profilePictureUrl) {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        initialsView
                    case .empty:
                        ProgressView()
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .background(Color.blue.opacity(0.16))
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
    }

    private var initialsView: some View {
        Text(initials(for: user?.name))
            .font(.caption.bold())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func initials(for name: String?) -> String {
        let safeName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = safeName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        return letters.isEmpty ? "U" : String(letters)
    }

    private func resolvedAvatarURL(from rawURL: String?) -> URL? {
        if let rawURL {
            let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
                if scheme == "http" || scheme == "https" {
                    return url
                }
            }
        }

        return AppConfig.frontendURL
            .appendingPathComponent("banner-photos")
            .appendingPathComponent("afternoon")
            .appendingPathComponent("001.webp")
    }
}

private struct UserProfileSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let user = appState.user {
                    Section("Account") {
                        HStack(spacing: 12) {
                            ProfileAvatarView(user: user, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                Text(user.email)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await appState.logout()
                            dismiss()
                        }
                    } label: {
                        Text("Log Out")
                    }
                }
            }
            .navigationTitle("User")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
