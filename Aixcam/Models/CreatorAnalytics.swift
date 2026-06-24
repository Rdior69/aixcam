import Foundation

struct CreatorAnalytics: Codable, Equatable, Sendable {
    var totalRevenue: Decimal
    var monthlyRevenue: Decimal
    var totalSubscribers: Int
    var freeSubscribers: Int
    var premiumSubscribers: Int
    var vipSubscribers: Int
    var profileViews: Int
    var profileViewsChange: Double
    var engagementRate: Double
    var contentViews: Int
    var averageWatchTime: Double
    var topPerformingContent: [ContentPerformance]
    var revenueByMonth: [MonthlyRevenue]
    var subscriberGrowth: [SubscriberDataPoint]
    var lastUpdated: Date

    static let preview = CreatorAnalytics(
        totalRevenue: 12_450,
        monthlyRevenue: 2_180,
        totalSubscribers: 847,
        freeSubscribers: 612,
        premiumSubscribers: 189,
        vipSubscribers: 46,
        profileViews: 24_500,
        profileViewsChange: 18.4,
        engagementRate: 6.8,
        contentViews: 156_000,
        averageWatchTime: 4.2,
        topPerformingContent: [
            ContentPerformance(title: "Behind the Scenes Vlog", views: 12_400, revenue: 890, type: .video),
            ContentPerformance(title: "Exclusive Photo Set", views: 8_200, revenue: 620, type: .photo),
            ContentPerformance(title: "Live Q&A Replay", views: 6_100, revenue: 445, type: .video)
        ],
        revenueByMonth: [
            MonthlyRevenue(month: "Jan", amount: 1200),
            MonthlyRevenue(month: "Feb", amount: 1450),
            MonthlyRevenue(month: "Mar", amount: 1680),
            MonthlyRevenue(month: "Apr", amount: 1920),
            MonthlyRevenue(month: "May", amount: 2050),
            MonthlyRevenue(month: "Jun", amount: 2180)
        ],
        subscriberGrowth: [
            SubscriberDataPoint(label: "Jan", count: 420),
            SubscriberDataPoint(label: "Feb", count: 510),
            SubscriberDataPoint(label: "Mar", count: 590),
            SubscriberDataPoint(label: "Apr", count: 680),
            SubscriberDataPoint(label: "May", count: 760),
            SubscriberDataPoint(label: "Jun", count: 847)
        ],
        lastUpdated: Date()
    )
}

struct ContentPerformance: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var views: Int
    var revenue: Decimal
    var type: MediaType

    init(id: UUID = UUID(), title: String, views: Int, revenue: Decimal, type: MediaType) {
        self.id = id
        self.title = title
        self.views = views
        self.revenue = revenue
        self.type = type
    }
}

struct MonthlyRevenue: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var month: String
    var amount: Decimal

    init(id: UUID = UUID(), month: String, amount: Decimal) {
        self.id = id
        self.month = month
        self.amount = amount
    }
}

struct SubscriberDataPoint: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var label: String
    var count: Int

    init(id: UUID = UUID(), label: String, count: Int) {
        self.id = id
        self.label = label
        self.count = count
    }
}
