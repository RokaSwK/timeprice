import SwiftUI

/// A believable slice of a MacBook desktop (wallpaper, menu bar, Safari window)
/// used to composite showcase images. Only used by `--render-assets`.
struct DesktopScene<Notch: View>: View {
    var metrics: NotchMetrics
    var size: CGSize
    var date: Date
    var page: NSImage?
    var url: String = "demostore.example/es/airpods-pro-3"
    var timeZone: TimeZone
    @ViewBuilder var notch: () -> Notch

    var body: some View {
        ZStack(alignment: .top) {
            Wallpaper()
            if let page {
                SafariWindow(page: page, url: url)
                    .frame(width: size.width - 300, height: size.height - 84)
                    .offset(y: metrics.notchHeight + 34)
            }
            MenuBar(metrics: metrics, date: date, timeZone: timeZone)
            notch()
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
        .environment(\.colorScheme, .dark)
    }
}

struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.12, blue: 0.2), Color(red: 0.04, green: 0.06, blue: 0.1)],
                startPoint: .top, endPoint: .bottom)
            Ellipse()
                .fill(Color(red: 0.16, green: 0.42, blue: 0.4))
                .frame(width: 900, height: 420)
                .offset(x: -420, y: 120)
                .blur(radius: 120)
            Ellipse()
                .fill(Color(red: 0.42, green: 0.25, blue: 0.62))
                .frame(width: 760, height: 380)
                .offset(x: 460, y: 40)
                .blur(radius: 130)
            Ellipse()
                .fill(Color(red: 0.86, green: 0.5, blue: 0.32).opacity(0.75))
                .frame(width: 620, height: 260)
                .offset(x: 120, y: 420)
                .blur(radius: 140)
        }
    }
}

struct MenuBar: View {
    var metrics: NotchMetrics
    var date: Date
    var timeZone: TimeZone

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 19) {
                Image(systemName: "apple.logo").font(.system(size: 14, weight: .semibold))
                Text("Safari").fontWeight(.bold)
                ForEach(["File", "Edit", "View", "History", "Bookmarks", "Window", "Help"], id: \.self) { Text($0) }
            }
            .padding(.leading, 20)
            Spacer()
            HStack(spacing: 17) {
                Image(systemName: "hourglass").foregroundStyle(Theme.mint)
                Image(systemName: "battery.75percent")
                Image(systemName: "wifi")
                Image(systemName: "magnifyingglass")
                Image(systemName: "switch.2")
                Text(clock)
            }
            .padding(.trailing, 18)
        }
        .font(.system(size: 13.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.95))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .frame(height: metrics.notchHeight)
        .background(Color.black.opacity(0.18))
    }

    private var clock: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = timeZone
        f.dateFormat = "EEE d MMM  HH:mm"
        return f.string(from: date)
    }
}

struct SafariWindow: View {
    var page: NSImage
    var url: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) {
                        Circle().fill($0).frame(width: 12, height: 12)
                    }
                }
                .padding(.leading, 16)
                HStack(spacing: 18) {
                    Image(systemName: "sidebar.left")
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right").opacity(0.4)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.55))
                .padding(.leading, 26)
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "lock.fill").font(.system(size: 10))
                    Text(url).font(.system(size: 13))
                }
                .foregroundStyle(Color.black.opacity(0.75))
                .frame(width: 440, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.black.opacity(0.055)))
                Spacer()
                HStack(spacing: 20) {
                    Image(systemName: "puzzlepiece.extension")
                    Image(systemName: "square.and.arrow.up")
                    Image(systemName: "plus")
                    Image(systemName: "square.on.square")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.55))
                .padding(.trailing, 18)
            }
            .frame(height: 52)
            .background(Color(white: 0.965))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5) }
            GeometryReader { geo in
                Image(nsImage: page)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, alignment: .top)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
            }
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 40, y: 20)
        .environment(\.colorScheme, .light)
    }
}
