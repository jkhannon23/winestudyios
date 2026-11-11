//
//  Question.swift
//  winestudyios
//

import Foundation

/// Optional place a question is about (used later for maps). Ignored if missing or invalid.
struct QuestionPlace: Codable {
    let name: String
    let lat: Double
    let lon: Double

    var isValid: Bool {
        !name.isEmpty && (-90...90).contains(lat) && (-180...180).contains(lon)
    }
}

struct Question: Codable {
    let question: String
    let answers: [String]
    let correctAnswerIndex: Int
    let feedback: String
    let category: String?
    let place: QuestionPlace?

    private enum CodingKeys: String, CodingKey {
        case question, answers, correctAnswerIndex, feedback, category, place
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        question = try c.decode(String.self, forKey: .question)
        answers = try c.decode([String].self, forKey: .answers)
        correctAnswerIndex = try c.decode(Int.self, forKey: .correctAnswerIndex)
        feedback = try c.decode(String.self, forKey: .feedback)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        // A broken "place" must never break the question itself: drop it quietly.
        let decoded = try? c.decodeIfPresent(QuestionPlace.self, forKey: .place)
        place = (decoded ?? nil).flatMap { $0.isValid ? $0 : nil }
    }
}

struct QuestionLoader {

    /// Where the live question file lives. New `content/` folder, so older app
    /// versions keep using their own bundled copy untouched.
    static let remoteURL = "https://raw.githubusercontent.com/jkhannon23/winestudyios/main/content/questions.json"

    /// A download smaller than this is treated as broken.
    private static let minimumQuestionCount = 20

    // MARK: - Loading (instant, never empty)

    /// Returns questions straight away: last good download if there is one,
    /// otherwise the copy bundled in the app.
    static func load() -> [Question] {
        if let data = try? Data(contentsOf: cacheFileURL),
           let cached = validatedQuestions(from: data) {
            return cached
        }
        return loadBundled()
    }

    static func loadBundled() -> [Question] {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let questions = try? JSONDecoder().decode([Question].self, from: data) else {
            return []
        }
        return questions
    }

    // MARK: - Refresh from GitHub (background)

    /// Downloads the live file. Only if it passes every check is it saved for next time
    /// and passed to `completion` (on the main thread). Anything wrong: nothing changes.
    static func refreshFromServer(completion: (([Question]) -> Void)? = nil) {
        guard let url = URL(string: remoteURL) else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let questions = validatedQuestions(from: data) else { return }
            saveToCache(data)
            DispatchQueue.main.async { completion?(questions) }
        }.resume()
    }

    // MARK: - Checking the file

    /// Returns the questions only if the WHOLE file is good; otherwise nil.
    /// Good = valid JSON list, enough questions, and every question has text,
    /// exactly 4 non-empty answers, a correct index in range, and its own unique text
    /// (the question text is what makes the question's ID).
    static func validatedQuestions(from data: Data) -> [Question]? {
        guard let questions = try? JSONDecoder().decode([Question].self, from: data),
              questions.count >= minimumQuestionCount else { return nil }
        var seen = Set<String>()
        for q in questions {
            guard !q.question.isEmpty,
                  q.answers.count == 4,
                  !q.answers.contains(where: { $0.isEmpty }),
                  (0..<4).contains(q.correctAnswerIndex),
                  seen.insert(q.question).inserted else { return nil }
        }
        return questions
    }

    // MARK: - Saved copy on the phone

    private static var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("questions-cache.json")
    }

    private static func saveToCache(_ data: Data) {
        let url = cacheFileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
