import SwiftUI
import UIKit

struct MedicineInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var state: AppState

    @State private var searchText = ""
    @State private var filter: InventoryFilter = .all
    @State private var showAddSheet = false
    @State private var editingItem: MedicineInventoryItem?
    @State private var pendingDelete: MedicineInventoryItem?

    private var sortedItems: [MedicineInventoryItem] {
        state.medicineInventory
            .filter { item in
                let matchesSearch = searchText.isEmpty ||
                    item.name.localizedCaseInsensitiveContains(searchText) ||
                    item.purpose.localizedCaseInsensitiveContains(searchText) ||
                    item.storageLocation.localizedCaseInsensitiveContains(searchText)

                let matchesFilter: Bool
                switch filter {
                case .all: matchesFilter = true
                case .attention:
                    matchesFilter = item.expiryState() != .ok || item.isLowStock
                case .expiring:
                    matchesFilter = item.expiryState() == .expiringSoon
                case .lowStock:
                    matchesFilter = item.isLowStock
                }
                return matchesSearch && matchesFilter
            }
            .sorted {
                if $0.expiryState() != $1.expiryState() {
                    return $0.expiryState().sortOrder < $1.expiryState().sortOrder
                }
                return $0.expiryDate < $1.expiryDate
            }
    }

    private var expiringCount: Int {
        state.medicineInventory.filter { $0.expiryState() == .expiringSoon }.count
    }

    private var attentionCount: Int {
        state.medicineInventory.filter { $0.expiryState() != .ok || $0.isLowStock }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        summary
                        filters

                        if sortedItems.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(sortedItems) { item in
                                    inventoryCard(item)
                                }
                            }
                        }

                        Text("Care+ helps you organise medicines, but it does not replace a pharmacist or medical advice.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Medicine cabinet")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Medicine, purpose or location")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add medicine to cabinet")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                MedicineInventoryEditor(state: state, item: nil)
            }
            .sheet(item: $editingItem) { item in
                MedicineInventoryEditor(state: state, item: item)
            }
            .alert("Remove this medicine?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Remove", role: .destructive) {
                    guard let pendingDelete else { return }
                    NotificationManager.cancelMedicineExpiryReminder(for: pendingDelete.id)
                    state.medicineInventory.removeAll { $0.id == pendingDelete.id }
                    state.saveMedicineInventory()
                    Task { await SyncEngine.deleteMedicineInventoryItem(id: pendingDelete.id, state: state) }
                    self.pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This only removes the item from your cabinet inventory. Scheduled medication reminders are not changed.")
            }
        }
        .tint(AppTheme.primary)
    }

    private var summary: some View {
        HStack(spacing: 10) {
            InventoryMetric(
                value: state.medicineInventory.count,
                label: "Medicines",
                icon: "cross.case.fill",
                color: AppTheme.primary
            )
            InventoryMetric(
                value: expiringCount,
                label: "Expiring",
                icon: "calendar.badge.exclamationmark",
                color: AppTheme.warning
            )
            InventoryMetric(
                value: attentionCount,
                label: "Attention",
                icon: "exclamationmark.triangle.fill",
                color: AppTheme.danger
            )
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InventoryFilter.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { filter = item }
                    } label: {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(filter == item ? Color.white : AppTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(filter == item ? AppTheme.primary : AppTheme.surface2)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: filter == item ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == item ? .isSelected : [])
                }
            }
        }
    }

    private var emptyState: some View {
        CardDark {
            VStack(spacing: 12) {
                Image(systemName: searchText.isEmpty && filter == .all ? "cross.case" : "magnifyingglass")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppTheme.primary)

                Text(searchText.isEmpty && filter == .all ? "Your cabinet is empty" : "No medicines found")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(searchText.isEmpty && filter == .all
                     ? "Add the medicines you have at home to keep quantities, purposes and expiry dates together."
                     : "Try another search or filter.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if searchText.isEmpty && filter == .all {
                    Button("Add first medicine") { showAddSheet = true }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private func inventoryCard(_ item: MedicineInventoryItem) -> some View {
        let status = item.expiryState()
        return CardDark {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "pills.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.primary.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if !item.strength.isEmpty {
                            Text(item.strength)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        if !item.purpose.isEmpty {
                            Text(item.purpose)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Menu {
                        Button("Edit", systemImage: "pencil") { editingItem = item }
                        Button("Remove", systemImage: "trash", role: .destructive) { pendingDelete = item }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Actions for \(item.name)")
                }

                HStack(spacing: 8) {
                    statusChip(status.title, icon: status.icon, color: status.color)
                    if item.isLowStock {
                        statusChip("Low stock", icon: "shippingbox.fill", color: AppTheme.danger)
                    }
                }

                Divider().overlay(AppTheme.stroke)

                HStack {
                    Label("\(item.quantity) \(item.unit.label)", systemImage: "number")
                    Spacer()
                    Label(item.expiryDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

                if !item.storageLocation.isEmpty {
                    Label(item.storageLocation, systemImage: "archivebox.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                HStack(spacing: 10) {
                    quantityButton(systemName: "minus", label: "Use one \(item.unit.label)") {
                        adjustQuantity(item, by: -1)
                    }
                    .disabled(item.quantity == 0)

                    Text("Update stock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)

                    quantityButton(systemName: "plus", label: "Add one \(item.unit.label)") {
                        adjustQuantity(item, by: 1)
                    }
                }
            }
        }
    }

    private func statusChip(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func quantityButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.surface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func adjustQuantity(_ item: MedicineInventoryItem, by amount: Int) {
        guard let index = state.medicineInventory.firstIndex(where: { $0.id == item.id }) else { return }
        state.medicineInventory[index].quantity = max(0, state.medicineInventory[index].quantity + amount)
        state.medicineInventory[index].updatedAt = .now
        state.saveMedicineInventory()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct InventoryMetric: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1))
    }
}

private struct MedicineInventoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var state: AppState
    let item: MedicineInventoryItem?

    @State private var name: String
    @State private var purpose: String
    @State private var strength: String
    @State private var quantity: Int
    @State private var unit: MedicineUnit
    @State private var expiryDate: Date
    @State private var storageLocation: String
    @State private var lowStockThreshold: Int
    @State private var notes: String

    init(state: AppState, item: MedicineInventoryItem?) {
        self.state = state
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _purpose = State(initialValue: item?.purpose ?? "")
        _strength = State(initialValue: item?.strength ?? "")
        _quantity = State(initialValue: item?.quantity ?? 1)
        _unit = State(initialValue: item?.unit ?? .tablets)
        _expiryDate = State(initialValue: item?.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now)
        _storageLocation = State(initialValue: item?.storageLocation ?? "")
        _lowStockThreshold = State(initialValue: item?.lowStockThreshold ?? 5)
        _notes = State(initialValue: item?.notes ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medicine") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("What is it for?", text: $purpose, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Strength or form (e.g. 500 mg)", text: $strength)
                }

                Section("Stock") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...9999)
                    Picker("Unit", selection: $unit) {
                        ForEach(MedicineUnit.allCases) { unit in
                            Text(unit.label.capitalized).tag(unit)
                        }
                    }
                    Stepper("Low-stock alert at: \(lowStockThreshold)", value: $lowStockThreshold, in: 0...999)
                }

                Section("Expiry and storage") {
                    DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
                    TextField("Where is it kept?", text: $storageLocation)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(item == nil ? "Add medicine" : "Edit medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .tint(AppTheme.primary)
        .presentationDetents([.large])
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var hasUnsavedChanges: Bool {
        if let item {
            return trimmedName != item.name || purpose != item.purpose || strength != item.strength ||
                quantity != item.quantity || unit != item.unit || expiryDate != item.expiryDate ||
                storageLocation != item.storageLocation || lowStockThreshold != item.lowStockThreshold ||
                notes != item.notes
        }
        return !trimmedName.isEmpty || !purpose.isEmpty || !strength.isEmpty || quantity != 1 ||
            !storageLocation.isEmpty || !notes.isEmpty
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let updated = MedicineInventoryItem(
            id: item?.id ?? UUID(),
            name: trimmedName,
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            strength: strength.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            unit: unit,
            expiryDate: expiryDate,
            storageLocation: storageLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            lowStockThreshold: lowStockThreshold,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: item?.createdAt ?? .now,
            updatedAt: .now
        )

        if let index = state.medicineInventory.firstIndex(where: { $0.id == updated.id }) {
            state.medicineInventory[index] = updated
        } else {
            state.medicineInventory.append(updated)
        }
        state.saveMedicineInventory()
        NotificationManager.scheduleMedicineExpiryReminder(for: updated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

private enum InventoryFilter: String, CaseIterable, Identifiable {
    case all
    case attention
    case expiring
    case lowStock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .attention: return "Needs attention"
        case .expiring: return "Expiring"
        case .lowStock: return "Low stock"
        }
    }
}

private extension ExpiryState {
    var title: String {
        switch self {
        case .ok: return "In date"
        case .expiringSoon: return "Expiring soon"
        case .expired: return "Expired"
        }
    }

    var icon: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .expired: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok: return AppTheme.success
        case .expiringSoon: return AppTheme.warning
        case .expired: return AppTheme.danger
        }
    }

    var sortOrder: Int {
        switch self {
        case .expired: return 0
        case .expiringSoon: return 1
        case .ok: return 2
        }
    }
}
