import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var category = "All muscle groups"
    @State private var equipment = "All equipment"
    @State private var selectedExercise: Exercise?

    private var categories: [String] {
        ["All muscle groups"] + Set(model.exercises.map(\.category)).sorted()
    }
    private var equipmentTypes: [String] {
        ["All equipment"] + Set(model.exercises.map(\.equipment)).sorted()
    }
    private var filtered: [Exercise] {
        model.exercises.filter {
            (category == "All muscle groups" || $0.category == category) &&
            (equipment == "All equipment" || $0.equipment == equipment) &&
            (search.isEmpty || "\($0.name) \($0.target) \($0.equipment)".localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            PageHeader(
                title: "Build your next session.",
                subtitle: "\(model.exercises.count.formatted()) exercises. Find a movement, set your reps, and make it yours."
            )

            // Search and Filters
            ExerciseFilterBar(
                search: $search,
                category: $category,
                equipment: $equipment,
                categories: categories,
                equipmentTypes: equipmentTypes
            )

            if !model.isEditingAllowed {
                Label("Finish or end your current session before adding exercises.", systemImage: "info.circle")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.secondary)
            }

            // Results count & column headers
            HStack(spacing: AppSpacing.md) {
                Text("\(filtered.count.formatted()) movements")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text("Equipment")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .frame(width: 140, alignment: .leading)
                Text("Target")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .frame(width: 120, alignment: .leading)
                Color.clear.frame(width: 65, height: 1)
            }
            .padding(.horizontal, AppSpacing.md)

            // Exercise List
            ScrollView {
                if filtered.isEmpty {
                    EmptyState(
                        symbol: "magnifyingglass",
                        title: "No matching movements.",
                        detail: "Try a different name or clear your equipment and muscle filters."
                    )
                    .padding(.top, AppSpacing.xl)
                } else {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(filtered) { exercise in
                            ExerciseRow(exercise: exercise) {
                                selectedExercise = exercise
                            }
                        }
                    }
                }
            }

            // Footer credits
            HStack {
                Text("Catalogue and instructions by Hasan Emir Yıldırım, under the MIT licence.")
                Spacer()
                Link("Source dataset", destination: URL(string: "https://github.com/hasaneyldrm/exercises-dataset")!)
            }
            .font(AppTypography.micro)
            .foregroundStyle(AppColors.secondary)
        }
        .padding(AppSpacing.xxl)
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
                .environment(model)
        }
    }
}

// MARK: - Exercise Filter Bar Subview
private struct ExerciseFilterBar: View {
    @Binding var search: String
    @Binding var category: String
    @Binding var equipment: String
    let categories: [String]
    let equipmentTypes: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.sm) {
                searchField
                categoryPicker
                equipmentPicker
            }
            VStack(spacing: AppSpacing.xs) {
                searchField
                HStack(spacing: AppSpacing.sm) {
                    categoryPicker
                    equipmentPicker
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.secondary)

            TextField("Search exercises, muscles, or equipment", text: $search)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .accessibilityIdentifier("exercise-search")

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs + 2)
        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }

    private var categoryPicker: some View {
        Picker("Muscle group", selection: $category) {
            ForEach(categories, id: \.self) {
                Text($0.capitalized).tag($0)
            }
        }
        .labelsHidden()
        .accessibilityLabel("Filter by muscle group")
        .frame(minWidth: 140, maxWidth: 160)
    }

    private var equipmentPicker: some View {
        Picker("Equipment", selection: $equipment) {
            ForEach(equipmentTypes, id: \.self) {
                Text($0.capitalized).tag($0)
            }
        }
        .labelsHidden()
        .accessibilityLabel("Filter by equipment")
        .frame(minWidth: 130, maxWidth: 150)
    }
}

// MARK: - Dedicated Exercise Row Subview
private struct ExerciseRow: View {
    let exercise: Exercise
    let onSelect: () -> Void

    var body: some View {
        Panel(padding: AppSpacing.sm, cornerRadius: AppRadius.md) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(AppColors.brandTeal)
                    .frame(width: 44, height: 44)
                    .background(AppColors.brandTeal.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(exercise.displayName)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Text(exercise.category.capitalized)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(exercise.equipment.capitalized)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondary)
                    .frame(width: 140, alignment: .leading)
                    .lineLimit(1)

                Text(exercise.target.capitalized)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondary)
                    .frame(width: 120, alignment: .leading)
                    .lineLimit(1)

                Button("View") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .buttonStyle(.tactile(scale: 0.96))
                .frame(width: 65)
                .accessibilityLabel("View \(exercise.displayName)")
            }
        }
    }
}

// MARK: - Exercise Detail Sheet
struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sets = 3
    @State private var reps = 10
    @State private var seconds = 45

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(AppColors.brandTeal)
                    .frame(width: 60, height: 60)
                    .background(AppColors.brandTeal.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(exercise.displayName)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.ink)
                    Text(exercise.equipment.capitalized)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.secondary)
                    HStack(spacing: AppSpacing.xs) {
                        Pill(title: exercise.category.capitalized, color: AppColors.brandTeal)
                        Pill(title: exercise.target.capitalized, color: AppColors.brandOrange)
                    }
                }
                Spacer()
            }

            Divider().opacity(0.6)

            // Step-by-step instructions
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("How to perform")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.ink)

                    if exercise.steps.isEmpty {
                        Text(exercise.instructions)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondary)
                            .lineSpacing(4)
                    } else {
                        ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                Text("\(index + 1)")
                                    .font(AppTypography.captionMedium)
                                    .foregroundStyle(AppColors.brandTeal)
                                    .frame(width: 22, height: 22)
                                    .background(AppColors.brandTeal.opacity(0.12), in: Circle())
                                Text(step)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.secondary)
                                    .lineSpacing(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if !exercise.secondaryMuscles.isEmpty {
                        Text("Secondary muscles: " + exercise.secondaryMuscles.map(\.capitalized).joined(separator: ", "))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 280)

            Divider().opacity(0.6)

            // Target fields
            PlanFields(sets: $sets, reps: $reps, seconds: $seconds)

            // Action row
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                PrimaryButton(title: "Add to session", symbol: "plus", tint: AppColors.brandTeal) {
                    model.add(exercise, sets: sets, reps: reps, seconds: seconds)
                    dismiss()
                }
                .disabled(!model.isEditingAllowed)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.xl)
        .frame(minWidth: 520, idealWidth: 580)
        .foregroundStyle(AppColors.ink)
        .background(AppColors.background)
    }
}

// MARK: - Plan Fields Subview
struct PlanFields: View {
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Sets")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                Stepper("\(sets)", value: $sets, in: 1...20)
                    .frame(width: 125)
                    .accessibilityLabel("Sets count")
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Repetitions")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                Stepper("\(reps)", value: $reps, in: 1...100)
                    .frame(width: 125)
                    .accessibilityLabel("Repetitions count")
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Time target")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                Stepper("\(seconds)s", value: $seconds, in: 10...3600, step: 5)
                    .frame(width: 145)
                    .accessibilityLabel("Target seconds")
            }
        }
        .font(AppTypography.bodyMedium)
    }
}

// MARK: - Plan Editor Sheet
struct PlanEditor: View {
    @State var item: PlannedExercise
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            PageHeader(
                title: "Make this set yours.",
                subtitle: model.exercises.first { $0.id == item.exerciseID }?.displayName ?? "Exercise"
            )

            PlanFields(sets: $item.sets, reps: $item.repetitions, seconds: $item.targetSeconds)

            Divider().opacity(0.6)

            HStack {
                Button("Remove exercise", role: .destructive) {
                    model.removePlanItem(item.id)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.regular)

                PrimaryButton(title: "Save changes", symbol: "checkmark", tint: AppColors.brandTeal) {
                    model.updatePlan(item)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.xl)
        .frame(minWidth: 520, idealWidth: 580)
        .background(AppColors.background)
    }
}
