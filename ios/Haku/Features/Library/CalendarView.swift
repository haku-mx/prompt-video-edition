//
//  CalendarView.swift
//  Calendario mensual con los videos subidos ubicados en su día (miniatura +
//  check), inspirado en la captura de referencia. Navegable mes a mes.
//  iOS-M1: usa la media mock fechada de la biblioteca.
//

import SwiftUI

struct CalendarView: View {
    private let media = MockLibrary.allMedia
    @State private var monthAnchor: Date
    @State private var detailVideo: VideoDetailPayload?

    private static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_MX")
        c.firstWeekday = 2 // lunes
        return c
    }

    private let weekdays = ["L", "M", "M", "J", "V", "S", "D"]

    init() {
        // Arranca en el mes más reciente que tenga media.
        let cal = Self.cal
        let latest = MockLibrary.allMedia
            .compactMap { $0.modifiedAt }
            .max()
            .map { Date(timeIntervalSince1970: $0) } ?? Date()
        let anchor = cal.date(from: cal.dateComponents([.year, .month], from: latest)) ?? latest
        _monthAnchor = State(initialValue: anchor)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HakuSpacing.lg) {
                monthHeader
                weekdayRow
                daysGrid
                Text("\(monthCount) video\(monthCount == 1 ? "" : "s") este mes")
                    .font(HakuFont.caption)
                    .foregroundStyle(HakuColor.textTertiary)
            }
            .padding(.horizontal, HakuSpacing.lg)
            .padding(.top, HakuSpacing.sm)
            .padding(.bottom, HakuLayout.bottomInset)
        }
        .background(HakuColor.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Calendario")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $detailVideo) { VideoDetailSheet(payload: $0) }
    }

    // MARK: - Encabezado de mes

    private var monthHeader: some View {
        HStack {
            Text(Self.monthTitle(monthAnchor))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(HakuColor.textPrimary)
            Spacer()
            HStack(spacing: HakuSpacing.sm) {
                navButton("chevron.left") { shiftMonth(-1) }
                navButton("chevron.right") { shiftMonth(1) }
            }
        }
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.snappy(duration: 0.25)) { action() } }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HakuColor.textPrimary)
                .frame(width: 38, height: 38)
                .background(HakuColor.surface, in: Circle())
                .overlay(Circle().stroke(HakuColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var weekdayRow: some View {
        HStack(spacing: HakuSpacing.sm) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(HakuFont.caption)
                    .foregroundStyle(HakuColor.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Rejilla de días

    private var daysGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: HakuSpacing.sm), count: 7)
        return LazyVGrid(columns: columns, spacing: HakuSpacing.sm) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                if let day { dayCell(day) } else { Color.clear.aspectRatio(1, contentMode: .fit) }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let videos = videos(on: day)
        let number = Self.cal.component(.day, from: day)
        return Group {
            if let first = videos.first {
                Button {
                    detailVideo = VideoDetailPayload(video: first, playbackURL: nil)
                } label: {
                    PlaceholderThumbnail(seed: first.videoID)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(alignment: .topLeading) {
                            Text("\(number)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .shadow(radius: 2)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if videos.count > 1 {
                                Text("\(videos.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(.black.opacity(0.5), in: Circle())
                                    .padding(2)
                            } else if first.indexed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(HakuColor.ready, in: Circle())
                                    .padding(2)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: HakuRadius.sm, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                RoundedRectangle(cornerRadius: HakuRadius.sm, style: .continuous)
                    .fill(HakuColor.surfaceMuted.opacity(0.5))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Text("\(number)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HakuColor.textTertiary)
                    }
            }
        }
    }

    // MARK: - Datos

    private var monthCells: [Date?] {
        let cal = Self.cal
        guard let range = cal.range(of: .day, in: .month, for: monthAnchor),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor))
        else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(cal.date(byAdding: .day, value: day - 1, to: first))
        }
        return cells
    }

    private func videos(on day: Date) -> [Video] {
        let cal = Self.cal
        return media.filter {
            guard let t = $0.modifiedAt else { return false }
            return cal.isDate(Date(timeIntervalSince1970: t), inSameDayAs: day)
        }
    }

    private var monthCount: Int {
        let cal = Self.cal
        return media.filter {
            guard let t = $0.modifiedAt else { return false }
            return cal.isDate(Date(timeIntervalSince1970: t), equalTo: monthAnchor, toGranularity: .month)
        }.count
    }

    private func shiftMonth(_ delta: Int) {
        if let d = Self.cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }

    private static func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        let s = f.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

#Preview {
    NavigationStack { CalendarView() }
        .preferredColorScheme(.light)
}
