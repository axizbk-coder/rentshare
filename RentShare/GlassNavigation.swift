import SwiftUI
import WebKit

@MainActor final class OnlineNavigation: ObservableObject {
    @Published var selected = "home"
    @Published var language = UserDefaults.standard.string(forKey: "rentshare.language") ?? "uz"
    @Published var settingsPresented = false
    @Published var modalPresented = false
    @Published var keyboardPresented = false
    weak var webView: WKWebView?
    func updateSelection(_ page: String) {
        guard selected != page else { return }
        if UIAccessibility.isReduceMotionEnabled { selected = page }
        else { withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { selected = page } }
    }
    func select(_ page: String) {
        guard !modalPresented else { return }
        guard ["home","search","dormitories","messages","profile"].contains(page) else { return }
        if page != "create" { updateSelection(page) }
        if UserDefaults.standard.object(forKey: "rentshare.haptics") == nil || UserDefaults.standard.bool(forKey: "rentshare.haptics") { UISelectionFeedbackGenerator().selectionChanged() }
        let argument = String(data: try! JSONSerialization.data(withJSONObject: page, options: [.fragmentsAllowed]), encoding: .utf8)!
        webView?.evaluateJavaScript("window.RentShareNavigate?.(\(argument))")
    }
}

struct GlassNavigation: View {
    @ObservedObject var navigation: OnlineNavigation
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Namespace private var selection
    var body: some View {
        if reduceTransparency || contrast == .increased {
            buttons.background(Brand.canvas, in: Capsule()).overlay(Capsule().stroke(Color.primary.opacity(0.18), lineWidth: 1)).padding(.horizontal,18).padding(.bottom,10)
        } else if #available(iOS 26.0, *) {
            buttons.glassEffect(.regular.interactive(), in: Capsule()).shadow(color: .black.opacity(0.12), radius: 16, y: 8).padding(.horizontal, 18).padding(.bottom, 10)
        } else {
            buttons.background(.regularMaterial, in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1)).shadow(color: .black.opacity(0.12), radius: 16, y: 8).padding(.horizontal,18).padding(.bottom,10)
        }
    }
    private var labels:[String] { navigation.language == "ru" ? ["Главная","Поиск","Общежития","Чаты","Профиль"] : navigation.language == "en" ? ["Home","Search","Dormitories","Messages","Profile"] : ["Bosh sahifa","Qidirish","Yotoqxona","Xabarlar","Profil"] }
    private var buttons: some View {
        HStack(spacing: 2) {
            item("home", "house", labels[0])
            item("search", "magnifyingglass", labels[1])
            item("dormitories", "building.2", labels[2])
            item("messages", "bubble.left.and.bubble.right", labels[3])
            item("profile", "person.crop.circle", labels[4])
        }.padding(8).frame(maxWidth:520).background {
            Capsule().fill(Color.white.opacity(0.001)).contentShape(Capsule()).onTapGesture { }
        }
    }
    private func item(_ id:String,_ icon:String,_ title:String) -> some View {
        Button { navigation.select(id) } label: {
            VStack(spacing:4) { Image(systemName:icon).font(.system(size:20,weight:.medium)).scaleEffect(navigation.selected == id ? 1.08 : 1);Text(title).font(.system(size:9,weight:.medium)).lineLimit(1) }
                .frame(maxWidth:.infinity).frame(height:49).foregroundStyle(navigation.selected==id ? (colorScheme == .dark ? Color(red:0.71,green:0.95,blue:0.84) : Brand.green) : (colorScheme == .dark ? Color.white.opacity(0.85) : Color.secondary))
                .contentShape(Rectangle())
                .background {
                    if navigation.selected == id {
                        Capsule().fill(Brand.green.opacity(0.13))
                            .matchedGeometryEffect(id: "activeTab", in: selection)
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78), value: navigation.selected)
        }.buttonStyle(PillPressStyle()).accessibilityAddTraits(navigation.selected==id ? .isSelected : [])
    }
}

private struct PillPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
