import Foundation

/// Prompts for output tasks. Picked by date, so the same day always shows the same prompt.
public enum Prompts {
    public enum Level: Sendable {
        case a2, b1, b2

        public init(_ band: Band) {
            switch band {
            case .a2_1, .a2_2: self = .a2
            case .b1_1, .b1_2: self = .b1
            case .b2_1, .b2_2: self = .b2
            }
        }
    }

    /// Target word range for `write.guided` (§2.3).
    public static func wordTarget(for band: Band) -> ClosedRange<Int> {
        switch Level(band) {
        case .a2: 50...100
        case .b1: 120...180
        case .b2: 200...300
        }
    }

    public static func writing(for band: Band, on date: Date, calendar: Calendar = .current) -> String {
        pick(writingPrompts[Level(band)]!, on: date, calendar: calendar)
    }

    public static func tandem(for band: Band, on date: Date, calendar: Calendar = .current) -> String {
        pick(tandemPrompts[Level(band)]!, on: date, calendar: calendar)
    }

    public static func quickWrite(on date: Date, calendar: Calendar = .current) -> String {
        pick(quickWriteTopics, on: date, calendar: calendar)
    }

    public static func fluencyStory(on date: Date, calendar: Calendar = .current) -> String {
        pick(fluencyStories, on: date, calendar: calendar)
    }

    public static func travelMission(on date: Date, calendar: Calendar = .current) -> String {
        pick(travelMissions, on: date, calendar: calendar)
    }

    static func pick(_ list: [String], on date: Date, calendar: Calendar) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[day % list.count]
    }

    static let writingPrompts: [Level: [String]] = [
        .a2: [
            "Describe your perfect weekend. Where are you, who is with you, what do you do?",
            "Write about what you did yesterday, from morning to night.",
            "Describe your town to someone who has never been there.",
            "Write a message to a friend inviting them to dinner. Say when, where and what you'll eat.",
            "What is your favourite food? Describe it and say why you like it.",
            "Write about a trip you took. Where did you go and what did you see?",
            "Describe a person in your family: what they look like and what they like doing.",
            "What do you usually do on a work day? Write about your routine.",
        ],
        .b1: [
            "Tell the story of a time something went wrong on a trip, and how you solved it.",
            "Should everyone learn a second language? Give your opinion with two reasons.",
            "Describe a film or series you liked recently and recommend it (or not).",
            "When you were a child, what did you use to do in summer? How is it different now?",
            "Write an email to a host family introducing yourself before you arrive.",
            "If you could live anywhere in Latin America for a year, where would it be and why?",
            "Describe a tradition from your country to someone from Latin America.",
            "What would you change about your city if you were the mayor?",
        ],
        .b2: [
            "Is social media doing more harm than good? Argue one side and answer an objection.",
            "Write a formal email to a landlord about a problem in your flat and ask for a solution.",
            "Compare living in a big city with living in a small town. Which suits you better and why?",
            "Describe a decision that changed your life, and what would have happened otherwise.",
            "Should tourists have to pay more to visit popular places? Argue your view.",
            "Review a book or podcast in Spanish you finished recently: plot, style, and who should read it.",
            "What does a 'good life' mean to you? Discuss with examples.",
            "Explain something you know well (a hobby, your job) to someone who knows nothing about it.",
        ],
    ]

    static let tandemPrompts: [Level: [String]] = [
        .a2: [
            "Ask your partner what they did this weekend and tell them about yours.",
            "Tell your partner what you ate today and ask about their favourite dish.",
            "Ask your partner about their town: what is there to do?",
            "Send a photo of something near you and describe it in two or three sentences.",
            "Ask your partner for one word or phrase young people use a lot in their country.",
        ],
        .b1: [
            "Tell your partner a short story about something funny or strange that happened to you.",
            "Ask your partner to recommend a series or song from their country, and ask why.",
            "Describe your plans for next month and ask about theirs.",
            "Ask your partner how a typical holiday is celebrated where they live.",
            "Ask your partner to correct one message you send today.",
        ],
        .b2: [
            "Ask your partner's opinion on a news story from their country and share yours.",
            "Debate a small topic: is it better to travel alone or with friends?",
            "Ask your partner about regional expressions and try using one in a sentence.",
            "Explain a cultural difference you've noticed and ask whether they agree.",
            "Ask your partner what surprised them most about your country or language.",
        ],
    ]

    static let quickWriteTopics = [
        "Your morning so far", "The last thing you bought", "A place you love", "Your favourite season",
        "What's in your bag", "Your plans for tomorrow", "The view from where you are", "A song stuck in your head",
    ]

    static let fluencyStories = [
        "Tell the story of your last trip.", "Describe your best friend and how you met.",
        "Explain how to cook a dish you like.", "Tell the story of your first day at a job or school.",
        "Describe your ideal day from morning to night.",
    ]

    static let travelMissions = [
        "Ask for a recommendation at your hostel or hotel and write down two phrases you heard.",
        "Order food or a drink entirely in Spanish, including one question about the menu.",
        "Ask someone for directions, even if you already know the way.",
        "Buy something at a market and ask about the price and where it comes from.",
        "Start a short conversation with another traveller or a local, in Spanish.",
        "Read a sign, menu or poster and look up three new words.",
    ]
}
