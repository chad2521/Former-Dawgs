import Foundation

final class StoriesService: NSObject, XMLParserDelegate {
    private var stories: [Story] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentSource = ""
    private var currentPublished = ""
    private var insideItem = false

    func fetchStories(for player: PlayerCatalogEntry) async -> [Story] {
        do {
            let items = try await fetchMergedFeedItems(queries: storyQueries(for: player))
            return items.map { item in
                Story(
                    title: item.title,
                    source: item.source,
                    publishedText: item.publishedText,
                    url: item.url
                )
            }
        } catch {
            return []
        }
    }

    func fetchHighlights(for player: PlayerCatalogEntry) async -> [HighlightVideo] {
        do {
            let items = try await fetchMergedFeedItems(queries: highlightQueries(for: player))
            return items.map { item in
                HighlightVideo(
                    title: item.title,
                    source: item.source,
                    publishedText: item.publishedText,
                    url: item.url
                )
            }
        } catch {
            return []
        }
    }

    private func fetchMergedFeedItems(queries: [String]) async throws -> [FeedItem] {
        var mergedItems: [FeedItem] = []
        var seenURLs: Set<URL> = []
        var seenTitles: Set<String> = []

        // Run RSS queries concurrently (used to be sequential).
        var batches: [[FeedItem]] = []
        try await withThrowingTaskGroup(of: [FeedItem].self) { group in
            for query in queries {
                group.addTask {
                    // Each StoriesService instance owns parser state; use a fresh one per query.
                    try await StoriesService().fetchFeedItems(query: query)
                }
            }
            for try await items in group {
                batches.append(items)
            }
        }

        for items in batches {
            for item in items {
                let normalizedTitle = item.title.lowercased()
                if seenURLs.contains(item.url) || seenTitles.contains(normalizedTitle) {
                    continue
                }
                seenURLs.insert(item.url)
                seenTitles.insert(normalizedTitle)
                mergedItems.append(item)
            }
        }

        let sortedItems = mergedItems.sorted { lhs, rhs in
            publishedDate(for: lhs) > publishedDate(for: rhs)
        }
        return Array(sortedItems.prefix(8))
    }

    private func fetchFeedItems(query: String) async throws -> [FeedItem] {
        var components = URLComponents(string: "https://news.google.com/rss/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "hl", value: "en-US"),
            URLQueryItem(name: "gl", value: "US"),
            URLQueryItem(name: "ceid", value: "US:en")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return parse(data: data)
    }

    private func parse(data: Data) -> [FeedItem] {
        stories = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        let sortedStories = stories.sorted { lhs, rhs in
            publishedDate(for: lhs) > publishedDate(for: rhs)
        }
        return Array(sortedStories.prefix(8))
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentSource = ""
            currentPublished = ""
        }

        if insideItem, elementName == "source" {
            currentSource = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        switch currentElement {
        case "title":
            currentTitle += value
        case "link":
            currentLink += value
        case "source":
            currentSource += value
        case "pubDate":
            currentPublished += value
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "item" else { return }
        insideItem = false

        if let url = URL(string: currentLink), !currentTitle.isEmpty {
            stories.append(
                Story(
                    title: currentTitle.decodingHTMLEntities(),
                    source: currentSource.isEmpty ? "News" : currentSource.decodingHTMLEntities(),
                    publishedText: currentPublished,
                    url: url
                )
            )
        }
    }

    private func publishedDate(for story: Story) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: story.publishedText) ?? .distantPast
    }

    private func context(for player: PlayerCatalogEntry) -> String {
        return "Mississippi State"
    }

    private func storyQueries(for player: PlayerCatalogEntry) -> [String] {
        return [
            "\"\(player.displayName)\" \"\(context(for: player))\" baseball",
            "\"\(player.displayName)\" MiLB",
            "\"\(player.displayName)\" baseball"
        ]
    }

    private func highlightQueries(for player: PlayerCatalogEntry) -> [String] {
        [
            "\"\(player.displayName)\" baseball highlights OR video",
            "\"\(player.displayName)\" MiLB highlights",
            "\"\(player.displayName)\" \(context(for: player)) video"
        ]
    }

}

private typealias FeedItem = Story

private extension String {
    func decodingHTMLEntities() -> String {
        replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
