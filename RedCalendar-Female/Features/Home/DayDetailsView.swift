//
//  DayDetailsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

import SwiftUI

struct DayDetailsView: View {
    @EnvironmentObject var store: AppStore
    
    private var dayStamp: Daystamp? {
        if case .authenticated(_, _, let calendarState) = store.state.authState {
            return calendarState.selectedDayStamp
        }
        return nil
    }
    
    private var formattedDate: String {
        guard let dayStamp = dayStamp else { return "" }
        let date = dayStamp.toDate(calendar: Calendar.current)
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    var body: some View {
        if let dayStamp = dayStamp {
            VStack(spacing: 20) {
                // Header with close button
                HStack {
                    Text("Детали дня")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        store.send(.setSelectedDayStamp(nil))
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Day information
                VStack(spacing: 12) {
                    Text(formattedDate)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text("Daystamp: \(dayStamp.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(dayStamp.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer() // Оставить или убрать?
            }
            .padding([.top, .bottom])
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        DayDetailsView()
    }
    .environmentObject(
        AppStore(
            initialState: AppState(
                authState: .authenticated(
                    deviceId: "test",
                    userDetails: nil,
                    calendarState: CalendarState(selectedDayStamp: Daystamp(rawValue: 100))
                )
            ),
            reducer: appReducer,
            middlewares: []
        )
    )
}
