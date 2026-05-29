//
//  TagsSheetView.swift
//  RedCalendar-Female
//

import SwiftUI

struct TagsSheetView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var selectedIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            tagsList
            Divider()
            bottomActions
        }
        .onAppear {
            selectedIds = Set(store.state.calendarState.visibleDayTags[dayStamp] ?? [])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Теги").font(.headline)
            Spacer()
            Button(action: {
                store.send(.setDayTags(dayStamp, Array(selectedIds)))
                isPresented = false
            }) {
                Text("Готово")
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    // MARK: - Search

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Поиск", text: $searchText)
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Tags list

    private var tagsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(tagsByCategory, id: \.0) { category, tags in
                    tagCategorySection(category: category, tags: tags)
                }
            }
            .padding()
        }
    }

    private var tagsByCategory: [(Int, [UserTagRecord])] {
        let allTags = store.state.calendarState.userTags
        let filtered = searchText.isEmpty
            ? allTags
            : allTags.filter { $0.name?.localizedCaseInsensitiveContains(searchText) == true }
        let grouped = Dictionary(grouping: filtered) { $0.category ?? 0 }
        return grouped.sorted { $0.key < $1.key }
    }

    private func tagCategorySection(category: Int, tags: [UserTagRecord]) -> some View {
        FlowLayout(data: tags, id: \.id, spacing: 8, rowSpacing: 8) { tag in
            let isSelected = selectedIds.contains(tag.id)
            let color = Color.tagColor(for: category)
            Button(action: {
                if isSelected { selectedIds.remove(tag.id) }
                else { selectedIds.insert(tag.id) }
            }) {
                Text(tag.name ?? "")
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? color : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color, lineWidth: 1.5)
                    )
            }
        }
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack {
            Button("Новый тег") { /* next stage */ }
                .foregroundColor(.red)
            Spacer()
            Button("Редактировать") { /* next stage */ }
                .foregroundColor(.red)
        }
        .padding()
    }
}
