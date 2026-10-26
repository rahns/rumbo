/// "I can…" self-assessment statements per band, adapted from the CEFR self-assessment grid.
/// Used for placement (§2.1) and level-up gates.
public enum CanDo {
    public static let perBand = 10

    public static func statements(for band: Band) -> [String] {
        switch band {
        case .a2_1: [
            "I can follow a slow, clear video about daily life on a familiar topic.",
            "I can understand simple directions and announcements when spoken slowly.",
            "I can introduce myself and talk about my family, work or studies.",
            "I can order food and ask how much something costs.",
            "I can write a short message about what I'm doing today.",
            "I can understand the main idea of a short, simple text about everyday things.",
            "I can ask and answer simple questions about where people live and what they do.",
            "I can say what I like and don't like, with a simple reason.",
            "I can talk about what I did yesterday using a few common past-tense verbs.",
            "I can get by in a simple shop or café conversation if the other person helps.",
        ]
        case .a2_2: [
            "I can describe my day and my plans in simple connected sentences.",
            "I can follow most of a slow podcast or video made for learners.",
            "I can tell a short story about something that happened, in the past.",
            "I can write a short personal email to thank someone or make plans.",
            "I can explain what's wrong when I have a simple problem (lost bag, wrong order).",
            "I can understand the main points of short, clear messages from a friend.",
            "I can compare two things, places or people in simple terms.",
            "I can ask for and follow directions in a town.",
            "I can keep a short text chat going without translating every sentence.",
            "I can describe my home, my town and my routine in some detail.",
        ]
        case .b1_1: [
            "I can understand the main points of a podcast about a topic I know.",
            "I can deal with most situations while travelling where Spanish is spoken.",
            "I can join a conversation on a familiar topic without preparing first.",
            "I can describe experiences, dreams and plans, and give short reasons.",
            "I can write a simple connected text about something that interests me.",
            "I can follow a TV episode made for learners without subtitles most of the time.",
            "I can explain my opinion about a film or book and say why.",
            "I can ask someone to repeat or rephrase and then keep going.",
            "I can understand the plot of a story when it's told clearly.",
            "I can talk about past habits ('when I was a child, I used to…').",
        ]
        case .b1_2: [
            "I can tell a story about something that happened to me, using past tenses correctly most of the time.",
            "I can follow most conversations between native speakers when they speak clearly.",
            "I can explain a problem and suggest what should be done.",
            "I can write an email describing events and my feelings about them.",
            "I can understand most of a podcast for intermediate learners at normal speed.",
            "I can give simple advice and recommendations ('you should…', 'I'd recommend…').",
            "I can talk for a few minutes about a topic I know without long pauses.",
            "I can understand the main points of news on topics I'm familiar with.",
            "I can make plans with someone by phone or voice note.",
            "I can describe hypothetical situations in simple terms ('if I had time, I would…').",
        ]
        case .b2_1: [
            "I can follow most of a TV series episode for native speakers.",
            "I can take part in a conversation with native speakers without making them slow down much.",
            "I can explain my point of view on a current topic, giving pros and cons.",
            "I can write a clear, detailed text on a range of subjects I care about.",
            "I can understand most podcasts and radio programmes on familiar topics.",
            "I can read articles where the writer argues a particular point of view.",
            "I can describe a film or book plot and my reaction to it in detail.",
            "I can handle everyday admin (renting, banking, a doctor's appointment) in Spanish.",
            "I can use the subjunctive in common expressions without thinking too hard.",
            "I can understand jokes or irony some of the time.",
        ]
        case .b2_2: [
            "I can keep up in a group conversation and give my opinion with reasons.",
            "I can understand native speakers from different countries at normal speed.",
            "I can argue a case and respond to counter-arguments.",
            "I can write an essay or report presenting an argument with supporting details.",
            "I can follow films and series without subtitles, apart from heavy slang.",
            "I can explain something complex from my work or studies clearly.",
            "I can change my tone between formal and informal situations.",
            "I can understand long, complex speech when the topic is reasonably familiar.",
            "I can correct myself when I notice a mistake, mid-sentence.",
            "I can live day to day in a Spanish-speaking country without switching to English.",
        ]
        }
    }

    /// Onboarding shows 5 statements from the band the hours point to and 5 from the next one.
    public static let placementSampleSize = 5

    public static func placementStatements(for band: Band) -> (own: [String], next: [String]) {
        let own = Array(statements(for: band).prefix(placementSampleSize))
        let next = band.next.map { Array(statements(for: $0).prefix(placementSampleSize)) } ?? []
        return (own, next)
    }
}
