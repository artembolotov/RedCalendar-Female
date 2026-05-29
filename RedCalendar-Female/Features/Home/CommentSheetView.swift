//
//  CommentSheetView.swift
//  RedCalendar-Female
//

import SwiftUI

struct CommentSheetView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var isPresented: Bool

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Комментарий").font(.headline)
                Spacer()
                Button(action: {
                    store.send(.saveComment(dayStamp, text))
                    isPresented = false
                }) {
                    Text("Готово")
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
            }
            .padding()

            Divider()

            TextEditor(text: $text)
                .focused($isFocused)
                .padding()
        }
        .onAppear {
            text = store.state.calendarState.visibleComments[dayStamp]?.comment ?? ""
            isFocused = true
        }
    }
}
