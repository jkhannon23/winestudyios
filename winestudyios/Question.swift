//
//  Question.swift
//  winestudyios
//

import Foundation

struct Question: Codable {
    let question: String
    let answers: [String]
    let correctAnswerIndex: Int
    let feedback: String
    let category: String?
}

struct QuestionLoader {
    static func load() -> [Question] {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let questions = try? JSONDecoder().decode([Question].self, from: data) else {
            return []
        }
        return questions
    }
}
