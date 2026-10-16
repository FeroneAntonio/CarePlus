#if DEBUG
import UIKit

/// Fills guest mode with sample data for demos and screenshots.
/// Debug builds only, and only when launched with CAREPLUS_DEMO_SEED=1.
enum DemoSeed {
    static func runIfNeeded() {
        guard ProcessInfo.processInfo.environment["CAREPLUS_DEMO_SEED"] == "1" else { return }
        let d = UserDefaults.standard
        d.set(true, forKey: "guest_mode_v1")
        d.set(true, forKey: "education_seen_v1")
        d.set(true, forKey: "onboarding_done_v1")
        let cal = Calendar.current
        let now = Date()
        func at(_ dayOffset: Int, _ h: Int, _ m: Int) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: now)!
            return cal.date(bySettingHour: h, minute: m, second: 0, of: day)!
        }

        let contacts = [
            ContactItem(name: "Giulia", relation: "Daughter", phone: "+39 333 000 0001", photoData: portrait(bg: 0.55, skin: 0.10, hair: (0.08, 0.55, 0.35), longHair: true), isCaregiver: true),
            ContactItem(name: "Marco", relation: "Son", phone: "+39 333 000 0002", photoData: portrait(bg: 0.08, skin: 0.07, hair: (0.07, 0.45, 0.22), longHair: false)),
            ContactItem(name: "Dr. Rossi", relation: "Family doctor", phone: "+39 081 000 0003", photoData: portrait(bg: 0.40, skin: 0.09, hair: (0.0, 0.0, 0.75), longHair: false, glasses: true), isDoctor: true),
            ContactItem(name: "Anna", relation: "Neighbour", phone: "+39 333 000 0004", photoData: portrait(bg: 0.88, skin: 0.06, hair: (0.02, 0.70, 0.45), longHair: true)),
        ]
        save(contacts, "contacts_v1")
        d.set(contacts[0].id.uuidString, forKey: "sos_contact_id_v1__guest")
        save([
            CallEvent(contactKey: contacts[0].uniqueKey, timestamp: at(0, 9, 12)),
            CallEvent(contactKey: contacts[2].uniqueKey, timestamp: at(-1, 17, 40)),
            CallEvent(contactKey: contacts[1].uniqueKey, timestamp: at(-2, 19, 5)),
        ], "call_events_v1")

        save([
            TaskItem(title: "Take Donepezil 10 mg", notes: "After breakfast, with a glass of water", kind: .medication, isCompleted: true, dueDate: at(0, 8, 30)),
            TaskItem(title: "Morning walk with Giulia", notes: "Around the park, 20 minutes", kind: .event, isCompleted: false, dueDate: at(0, 10, 30)),
            TaskItem(title: "Take Memantine 5 mg", notes: "With lunch", kind: .medication, isCompleted: false, dueDate: at(0, 13, 0)),
            TaskItem(title: "Visit with Dr. Rossi", notes: "Bring the diary and the blood test results", kind: .event, isCompleted: false, dueDate: at(1, 16, 0)),
            TaskItem(title: "Call Marco", kind: .event, isCompleted: false, dueDate: at(0, 19, 0), phone: "+39 333 000 0002"),
        ], "tasks_v1")

        save([
            MedicineInventoryItem(name: "Donepezil", purpose: "Memory support", strength: "10 mg", quantity: 24, unit: .tablets, expiryDate: at(210, 9, 0), storageLocation: "Kitchen cabinet", lowStockThreshold: 7),
            MedicineInventoryItem(name: "Memantine", purpose: "Memory support", strength: "5 mg", quantity: 4, unit: .tablets, expiryDate: at(120, 9, 0), storageLocation: "Kitchen cabinet", lowStockThreshold: 7),
            MedicineInventoryItem(name: "Vitamin D", purpose: "Bone health", strength: "25,000 IU", quantity: 3, unit: .doses, expiryDate: at(18, 9, 0), storageLocation: "Bathroom drawer"),
            MedicineInventoryItem(name: "Paracetamol", purpose: "Pain / fever", strength: "500 mg", quantity: 16, unit: .tablets, expiryDate: at(400, 9, 0), storageLocation: "Bedroom"),
        ], "medicine_inventory_v1")

        save([
            DiaryEntry(date: at(0, 11, 15), text: "Walked to the park with Giulia. The lime trees are in bloom, I remembered the summer in Sorrento.", imageData: scene(), mood: .perfect),
            DiaryEntry(date: at(-1, 18, 30), text: "Marco came for dinner. We cooked pasta e patate together.", mood: .okay),
            DiaryEntry(date: at(-3, 21, 0), text: "A little tired today, I could not find my glasses for a while.", mood: .notGood),
        ], "diary_v1")

        let keys = contacts.map(\.uniqueKey)
        save((0..<4).map { i -> GameSessionResult in
            let start = at(-i, 15, 0)
            let correct = [5, 4, 4, 3][i]
            return GameSessionResult(type: .guessWho, startedAt: start, finishedAt: start.addingTimeInterval(140),
                                     durationSeconds: 140 + i * 20, totalRounds: 5, correctCount: correct,
                                     totalAttempts: 5 + (5 - correct),
                                     roundResults: (0..<5).map { GuessWhoRoundResult(roundIndex: $0, contactKey: keys[$0 % keys.count], isCorrect: $0 < correct, attempts: $0 < correct ? 1 : 2) })
        }, "game_results_v1")
    }

    private static func save<T: Encodable>(_ v: T, _ key: String) {
        Persistence.save(v, key: key, userId: "guest")
    }

    /// Flat illustrated portrait (no real people) so the memory game has recognisable faces.
    private static func portrait(bg: CGFloat, skin: CGFloat, hair: (h: CGFloat, s: CGFloat, b: CGFloat),
                                 longHair: Bool, glasses: Bool = false) -> Data? {
        let size: CGFloat = 480
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let c = ctx.cgContext
            UIColor(hue: bg, saturation: 0.30, brightness: 0.95, alpha: 1).setFill()
            c.fill(CGRect(x: 0, y: 0, width: size, height: size))
            let hairColor = UIColor(hue: hair.h, saturation: hair.s, brightness: hair.b, alpha: 1)
            let skinColor = UIColor(hue: skin, saturation: 0.38, brightness: 0.93, alpha: 1)

            if longHair {
                hairColor.setFill()
                c.fill(CGRect(x: 135, y: 150, width: 210, height: 230))
            }
            UIColor(hue: bg, saturation: 0.55, brightness: 0.55, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 70, y: 340, width: 340, height: 260))
            skinColor.setFill()
            c.fill(CGRect(x: 205, y: 280, width: 70, height: 80))
            c.fillEllipse(in: CGRect(x: 150, y: 120, width: 180, height: 210))
            hairColor.setFill()
            c.addArc(center: CGPoint(x: 240, y: 200), radius: 96, startAngle: .pi, endAngle: 0, clockwise: false)
            c.fillPath()
            c.fill(CGRect(x: 144, y: 196, width: 18, height: 50))
            c.fill(CGRect(x: 318, y: 196, width: 18, height: 50))

            UIColor(white: 0.15, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 197, y: 222, width: 14, height: 14))
            c.fillEllipse(in: CGRect(x: 269, y: 222, width: 14, height: 14))
            UIColor(white: 0.15, alpha: 1).setStroke()
            c.setLineWidth(5)
            c.setLineCap(.round)
            c.addArc(center: CGPoint(x: 240, y: 262), radius: 26, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            c.strokePath()
            if glasses {
                c.setLineWidth(5)
                c.strokeEllipse(in: CGRect(x: 180, y: 206, width: 48, height: 44))
                c.strokeEllipse(in: CGRect(x: 252, y: 206, width: 48, height: 44))
                c.move(to: CGPoint(x: 228, y: 226)); c.addLine(to: CGPoint(x: 252, y: 226)); c.strokePath()
            }
        }
        return img.jpegData(compressionQuality: 0.85)
    }

    private static func scene() -> Data? {
        let w: CGFloat = 900, h: CGFloat = 600
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            let c = ctx.cgContext
            let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [UIColor(red: 0.98, green: 0.78, blue: 0.55, alpha: 1).cgColor,
                                          UIColor(red: 0.55, green: 0.72, blue: 0.92, alpha: 1).cgColor] as CFArray,
                                 locations: [0, 1])!
            c.drawLinearGradient(sky, start: CGPoint(x: 0, y: h * 0.6), end: .zero, options: [])
            UIColor(red: 1, green: 0.93, blue: 0.75, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 600, y: 120, width: 140, height: 140))
            UIColor(red: 0.42, green: 0.62, blue: 0.45, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: -200, y: 380, width: 900, height: 500))
            UIColor(red: 0.33, green: 0.52, blue: 0.38, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 350, y: 420, width: 900, height: 500))
            for x in stride(from: 80.0, to: 900.0, by: 210.0) {
                UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1).setFill()
                c.fill(CGRect(x: x + 30, y: 360, width: 18, height: 90))
                UIColor(red: 0.26, green: 0.45, blue: 0.30, alpha: 1).setFill()
                c.fillEllipse(in: CGRect(x: x - 20, y: 270, width: 120, height: 120))
            }
        }
        return img.jpegData(compressionQuality: 0.85)
    }
}
#endif
