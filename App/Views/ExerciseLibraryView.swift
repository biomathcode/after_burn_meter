import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var category = "All muscle groups"
    @State private var equipment = "All equipment"
    @State private var selectedExercise: Exercise?

    private var categories: [String] { ["All muscle groups"] + Set(model.exercises.map(\.category)).sorted() }
    private var equipmentTypes: [String] { ["All equipment"] + Set(model.exercises.map(\.equipment)).sorted() }
    private var filtered: [Exercise] {
        model.exercises.filter {
            (category == "All muscle groups" || $0.category == category) &&
            (equipment == "All equipment" || $0.equipment == equipment) &&
            (search.isEmpty || "\($0.name) \($0.target) \($0.equipment)".localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Build your next session.").font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("\(model.exercises.count.formatted()) exercises. Find a movement, set your reps, and make it yours.")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
            }
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                    TextField("Search exercises, muscles, or equipment", text: $search).textFieldStyle(.plain)
                        .accessibilityIdentifier("exercise-search")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
                Picker("Muscle group", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0.capitalized).tag($0) }
                }.labelsHidden().frame(width: 155)
                Picker("Equipment", selection: $equipment) {
                    ForEach(equipmentTypes, id: \.self) { Text($0.capitalized).tag($0) }
                }.labelsHidden().frame(width: 145)
            }
            if !model.isEditingAllowed {
                Label("Finish or end your current session before adding exercises.", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            HStack {
                Text("\(filtered.count.formatted()) movements").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("Equipment").frame(width: 150, alignment: .leading)
                Text("Target").frame(width: 120, alignment: .leading)
                Color.clear.frame(width: 65, height: 1)
            }.font(.system(size: 11)).foregroundStyle(Palette.secondary).padding(.horizontal, 18)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { exercise in
                        HStack(spacing: 14) {
                            Image(systemName: exercise.symbol).font(.system(size: 23, weight: .regular))
                                .foregroundStyle(Palette.teal).frame(width: 48, height: 48)
                                .background(Palette.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.displayName).font(.system(size: 13, weight: .medium))
                                Text(exercise.category.capitalized).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text(exercise.equipment.capitalized).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                                .frame(width: 150, alignment: .leading)
                            Text(exercise.target.capitalized).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                                .frame(width: 120, alignment: .leading)
                            Button("View") { selectedExercise = exercise }.buttonStyle(.bordered).controlSize(.small)
                                .frame(width: 65).accessibilityLabel("View \(exercise.displayName)")
                        }
                    .padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                if filtered.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: "No matching movements.",
                        detail: "Try a different name or clear your equipment and muscle filters.")
                }
            }
            HStack {
                Text("Catalogue and instructions by Hasan Emir Yıldırım, under the MIT licence.")
                Spacer()
                Link("Source", destination: URL(string: "https://github.com/hasaneyldrm/exercises-dataset")!)
            }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }
        .padding(30)
        .sheet(item: $selectedExercise) { ExerciseDetailView(exercise: $0).environment(model) }
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sets = 3
    @State private var reps = 10
    @State private var seconds = 45

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                Image(systemName: exercise.symbol).font(.system(size: 36, weight: .light)).foregroundStyle(Palette.teal)
                    .frame(width: 68, height: 68).background(Palette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 7) {
                    Text(exercise.displayName).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(exercise.equipment.capitalized).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    HStack { Pill(title: exercise.category.capitalized); Pill(title: exercise.target.capitalized) }
                }
                Spacer()
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How to do it").font(.system(size: 15, weight: .semibold))
                    if exercise.steps.isEmpty {
                        Text(exercise.instructions).font(.system(size: 13)).lineSpacing(5)
                    } else {
                        ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.teal)
                                    .frame(width: 23, height: 23).background(Palette.teal.opacity(0.07), in: Circle())
                                Text(step).font(.system(size: 13)).foregroundStyle(Palette.secondary).lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if !exercise.secondaryMuscles.isEmpty {
                        Text("Also works: " + exercise.secondaryMuscles.map(\.capitalized).joined(separator: ", "))
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 300)
            Divider()
            PlanFields(sets: $sets, reps: $reps, seconds: $seconds)
            HStack {
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                PrimaryButton(title: "Add to session", symbol: "plus") {
                    model.add(exercise, sets: sets, reps: reps, seconds: seconds)
                    dismiss()
                }.disabled(!model.isEditingAllowed).keyboardShortcut(.defaultAction)
            }
        }
        .padding(30).frame(width: 580).foregroundStyle(Palette.ink).background(Palette.background)
    }
}

struct PlanFields: View {
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var seconds: Int
    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Sets").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Stepper("\(sets)", value: $sets, in: 1...20).frame(width: 125)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Repetitions").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Stepper("\(reps)", value: $reps, in: 1...100).frame(width: 125)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Time target").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Stepper("\(seconds)s", value: $seconds, in: 10...3600, step: 5).frame(width: 145)
            }
        }.font(.system(size: 13))
    }
}

struct PlanEditor: View {
    @State var item: PlannedExercise
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Make this set yours.").font(.system(size: 25, weight: .semibold, design: .rounded))
            Text(model.exercises.first { $0.id == item.exerciseID }?.displayName ?? "Exercise")
                .font(.system(size: 14)).foregroundStyle(Palette.secondary)
            PlanFields(sets: $item.sets, reps: $item.repetitions, seconds: $item.targetSeconds)
            Divider()
            HStack {
                Button("Remove exercise", role: .destructive) { model.removePlanItem(item.id); dismiss() }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                PrimaryButton(title: "Save changes", symbol: "checkmark") { model.updatePlan(item); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width: 580).background(Palette.background)
    }
}

