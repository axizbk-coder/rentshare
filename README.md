# RentShare iOS — GitHub va Codemagic

Bu paket mavjud RentShare Swift/SwiftUI ilovasining Xcode manbasi. Server va foydalanuvchi ma’lumotlari ko‘chirilmaydi; ilova mavjud onlayn backend bilan ishlaydi. Xcode loyihasi: `RentShare.xcodeproj`, umumiy scheme: `RentShare`, versiya: 1.12, boshlang‘ich build: 14, Bundle ID: `uz.rentshare.ios`.

## Birinchi build

1. ZIP’ni oching. GitHub’da **private** repository yarating. ZIP faylining o‘zini emas, uning ichidagi fayllarni yuklang: `codemagic.yaml`, `RentShare.xcodeproj`, `RentShare`, `ci`, `.gitignore`, shu README. `codemagic.yaml` repository ildizida bo‘lsin.
2. Codemagic hisobiga kiring va aynan shu repository’ga ruxsat bering. Add application orqali uni tanlang, konfiguratsiya sifatida repository’dagi YAML’dan foydalaning.
3. Avval **RentShare - unsigned iOS validation** workflow’ni qo‘lda ishga tushiring. Apple imzolash kalitlari bu bosqichga kerak emas. Natija simulator uchun `.app` ZIP va build loglari bo‘ladi; uni jismoniy iPhone’ga o‘rnatib bo‘lmaydi.
4. Xato bo‘lsa, birinchi build xatosi va logini tekshiring. Muvaffaqiyatli cloud build hali bajarilmagan; lokal paket tekshiruvi macOS build o‘rnini bosmaydi.

## Imzolangan App Store IPA

Oxirgi tekshiruvda Apple jamoasi bepul provisioning sifatida ko‘ringan; pullik a’zolik tasdiqlanmagan. App Store tarqatishdan oldin Apple Developer Program a’zoligi faol ekanini tekshiring.

1. Pullik jamoada `uz.rentshare.ios` App ID’ni va mos App Store Connect ilova yozuvini tekshiring. Boshqa Bundle ID zarur bo‘lsa, Xcode project, YAML va `ci/verify-ipa.py` qiymatlarini birgalikda yangilang; mavjud iPhone ilovasi identifikatori almashishi mumkin.
2. Codemagic → Team settings → Code signing identities’da mos **Apple Distribution** sertifikati va **App Store** provisioning profilini xavfsiz yuklang yoki rasmiy Developer Portal integratsiyasi orqali oling. API integratsiya ishlatilsa, App Manager huquqli maxsus kalitni Codemagic’da saqlang. Mavjud sertifikatlarni bekor qilmang. `.p8`, `.p12`, profil va parollarni GitHub yoki chatga yubormang.
3. Codemagic ilova environment sozlamasida `IOS_BUILD_NUMBER` ni ilgari yuklangan barcha buildlardan katta yangi butun songa o‘rnating (15..9999). Masalan, 15 faqat avval ishlatilmagan bo‘lsa to‘g‘ri. Build raqami maxfiy emas.
4. **RentShare - signed App Store IPA (no upload)** workflow’ni qo‘lda ishga tushiring. Sertifikat/profil mos kelmasa workflow to‘xtaydi. Natija haqiqiy imzolangan IPA bo‘ladi, faqat cloud build muvaffaqiyatli tugagandan keyin.
5. IPA’ni App Store Connect’ga yuklash, TestFlight tarqatish va App Review’ga yuborish ushbu YAML’da yoqilmagan. App Store metadata, privacy javoblari, native imkoniyatlar va barcha ishlaydigan oqimlarni alohida tekshiring. Paket Apple tasdig‘ini anglatmaydi.

Xcode 26.6 / Mac mini M2 tanlangan. Cloud build hisob limitlariga sarflanadi; hisobingizdagi amaldagi limit va narxlarni ishga tushirishdan oldin ko‘ring. Bepul cheksiz Mac kafolatlanmaydi.

Rasmiy qo‘llanmalar:
- https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/
- https://docs.codemagic.io/specs-macos/xcode-26-6/

## Paketga kiritilmagan narsalar

Apple kalitlari, provisioning profillari, developer IPA, qurilma identifikatorlari, server kalitlari, baza nusxasi, `.env` va foydalanuvchi sessiyalari. Xcode, GitHub yoki Codemagic hisobiga kirish ushbu ZIP orqali avtomatik amalga oshmaydi.
