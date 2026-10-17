import SwiftUI

struct OnlineSettings: View {
    @ObservedObject var navigation: OnlineNavigation
    @AppStorage("rentshare.appearance") private var appearance = "light"
    @AppStorage("rentshare.haptics") private var haptics = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let origin = "https://rentshare-fstu.pages.dev"
    private func text(_ uz: String, _ ru: String, _ en: String) -> String {
        navigation.language == "ru" ? ru : navigation.language == "en" ? en : uz
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(text("Ko‘rinish", "Оформление", "Appearance")) {
                    Picker(text("Ilova mavzusi", "Тема приложения", "App theme"), selection: $appearance) {
                        Text(text("Ochiq", "Светлая", "Light")).tag("light")
                        Text(text("Qorong‘i", "Тёмная", "Dark")).tag("dark")
                        Text(text("Tizimga mos", "Системная", "System")).tag("system")
                    }
                    Picker(text("Til", "Язык", "Language"), selection: $navigation.language) {
                        Text("O‘zbekcha").tag("uz"); Text("Русский").tag("ru"); Text("English").tag("en")
                    }.onChange(of: navigation.language) { _, language in
                        UserDefaults.standard.set(language,forKey:"rentshare.language")
                        let value = String(data: try! JSONSerialization.data(withJSONObject: language, options: [.fragmentsAllowed]), encoding: .utf8)!
                        navigation.webView?.evaluateJavaScript("window.RentShareSetLanguage?.(\(value))")
                    }
                    Toggle(text("Tebranish", "Вибрация", "Haptics"), isOn: $haptics)
                }
                Section(text("Hisob", "Аккаунт", "Account")) {
                    Button { navigation.select("profile"); dismiss() } label: {
                        Label(text("Profil", "Профиль", "Profile"), systemImage: "person.crop.circle")
                    }
                    Button {
                        dismiss()
                        navigation.webView?.evaluateJavaScript("window.RentShareOpenAccountDeletion?.()")
                    } label: { Label(text("Hisob va ma’lumotlarni o‘chirish", "Удаление аккаунта и данных", "Account and data deletion"), systemImage: "person.crop.circle.badge.minus") }
                }
                Section(text("Yordam va maxfiylik", "Помощь и конфиденциальность", "Help and privacy")) {
                    Link("+998 94 434 80 07", destination: URL(string: "tel:+998944348007")!)
                    Link("turondagi@gmail.com", destination: URL(string: "mailto:turondagi@gmail.com")!)
                    Link(text("Yordam", "Помощь", "Help"), destination: URL(string: origin + "/support")!)
                    Link(text("Maxfiylik siyosati", "Конфиденциальность", "Privacy policy"), destination: URL(string: origin + "/privacy")!)
                    Link(text("Foydalanish qoidalari", "Условия использования", "Terms of use"), destination: URL(string: origin + "/terms")!)
                }
                Section("RentShare") {
                    LabeledContent(text("Versiya", "Версия", "Version"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Text("Abduraxmonov Azizbek").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(text("Sozlamalar", "Настройки", "Settings"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(text("Tayyor", "Готово", "Done")) { dismiss() } } }
        }.tint(colorScheme == .dark ? Brand.mint : Brand.green)
            .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
            .presentationDragIndicator(.visible)
    }
}
