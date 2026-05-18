//
//  ViewController.swift
//  winestudyios
//
//  Created by JILL HANNON on 14/03/26.
//

import UIKit
import AVFoundation

// Button that always fills its container width (ignores intrinsic width)
class FullWidthButton: UIButton {
    var padding = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height + padding.top + padding.bottom)
    }

    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        return contentRect.inset(by: padding)
    }
}

class ViewController: UIViewController {

    // MARK: - Theme Colors
    private let hotPink = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1)     // #E33B8E
    private let correctGreen = UIColor(red: 2/255, green: 147/255, blue: 7/255, alpha: 1)    // #029307
    private let wrongRed = UIColor(red: 211/255, green: 47/255, blue: 47/255, alpha: 1)      // #D32F2F

    private let totalQuestions = 10

    private var allQuestions: [Question] = []
    private var quizQuestions: [Question] = []
    private var currentIndex = 0
    private var score = 0
    private var hasAnswered = false
    private var shuffledAnswerIndices: [Int] = []
    private var isDailyChallenge = false

    // MARK: - Font Helpers

    private static func nunito(_ size: CGFloat, weight: String = "Regular") -> UIFont {
        let wght: CGFloat
        let uiWeight: UIFont.Weight
        switch weight {
        case "Bold":     wght = 700; uiWeight = .bold
        case "SemiBold": wght = 600; uiWeight = .semibold
        case "Medium":   wght = 500; uiWeight = .medium
        case "Black":    wght = 900; uiWeight = .black
        default:         wght = 400; uiWeight = .regular
        }
        // Variable font: drive the 'wght' axis directly so the requested weight
        // actually renders (UIFontDescriptor traits are unreliable for variable fonts).
        let wghtAxis = 0x77676874  // 'wght' as a four-char code
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Nunito",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: wght]
        ])
        let base = UIFont(descriptor: descriptor, size: size)
        // If the custom font failed to load, fall back to a system font of the same weight.
        if base.familyName != "Nunito" {
            return UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: size, weight: uiWeight))
        }
        return UIFontMetrics.default.scaledFont(for: base)
    }

    private static func applyButtonShadow(_ button: UIButton) {
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 6
    }

    // MARK: - Sound Effects

    private var soundPlayers: [String: AVAudioPlayer] = [:]
    private var activePlayers: [AVAudioPlayer] = []

    private func preloadSounds() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let soundFiles: [(String, String)] = [("correct", "mp3"), ("wrong", "mp3"), ("again", "mp3"), ("next", "mp3"), ("win", "mp3"), ("fail", "mp3")]
        for (name, ext) in soundFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                  let player = try? AVAudioPlayer(contentsOf: url) else {
                print("Sound file not found in bundle: \(name).\(ext)")
                continue
            }
            player.prepareToPlay()
            soundPlayers[name] = player
        }
    }

    private func playSound(named name: String, duration: TimeInterval? = nil) {
        guard let url = soundPlayers[name]?.url else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.currentTime = 0
        player.play()
        if let duration = duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                player.stop()
            }
        }
        activePlayers.removeAll { !$0.isPlaying }
        activePlayers.append(player)
    }

    private func playCorrectSound() { playSound(named: "correct") }
    private func playWrongSound() { playSound(named: "wrong") }
    private func playNextSound() { playSound(named: "next") }
    private func playAgainSound() { playSound(named: "again", duration: 3.0) }

    // MARK: - Status Bar

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - UI Elements

    // --- Welcome screen ---
    private let welcomeContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let welcomeBackgroundImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "background"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "title"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let birdImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "bird-fly"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Test your wine knowledge!"
        label.font = nunito(22, weight: "Bold")
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let welcomeStreakLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(16)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = nunito(20, weight: "Bold")
        button.backgroundColor = .white
        button.setTitleColor(UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1), for: .normal)
        button.layer.cornerRadius = 28
        button.clipsToBounds = false
        button.translatesAutoresizingMaskIntoConstraints = false
        applyButtonShadow(button)
        // Set title with arrow
        let attrs: [NSAttributedString.Key: Any] = [
            .font: nunito(20, weight: "Bold"),
            .foregroundColor: UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1)
        ]
        button.setAttributedTitle(NSAttributedString(string: "Play \u{2192}", attributes: attrs), for: .normal)
        return button
    }()

    private let dailyChallengeButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = nunito(20, weight: "Bold")
        button.backgroundColor = .clear
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 28
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: nunito(20, weight: "Bold"),
            .foregroundColor: UIColor.white
        ]
        button.setAttributedTitle(NSAttributedString(string: "Daily challenge", attributes: attrs), for: .normal)
        return button
    }()

    private let dailyStatusLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(14, weight: "Medium")
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // --- Quiz screen ---
    private let quizContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()

    // Pink wave header image that fills the top portion of the quiz screen behind the question.
    // Plain UIView with the image painted via CALayer.contents so it has no intrinsic content
    // size — its frame is fully determined by the autolayout constraints.
    private let quizPinkHeaderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.contents = UIImage(named: "pinkwave2")?.cgImage
        view.layer.contentsGravity = .resize
        return view
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(16, weight: "Bold")
        label.textColor = .white
        label.textAlignment = .left
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scoreCountLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(16, weight: "Bold")
        label.textColor = .white
        label.textAlignment = .right
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let quizScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let quizContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Speech bubble
    private let speechBubbleView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let speechBubbleTail: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "Vector 1"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.transform = CGAffineTransform(rotationAngle: .pi / 18) // tilt slightly right
        return imageView
    }()

    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(20, weight: "Bold")
        label.textColor = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Quiz bird (peeking from left edge)
    private let quizBirdImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "bird-talk"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var answerButtons: [UIButton] = []

    private let answersContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Progress dots
    private let progressDotsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let feedbackLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(15, weight: "Regular")
        label.textColor = UIColor(red: 90/255, green: 90/255, blue: 90/255, alpha: 1)
        label.numberOfLines = 0
        label.textAlignment = .left
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Decorative hot-pink "!" image to the left of the feedback text.
    private let feedbackExclamationImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "exclamation"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // We no longer use a separate pill view; feedback is shown directly on pink bg
    private let feedbackContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let nextButton: UIButton = {
        let button = UIButton(type: .custom)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: nunito(18, weight: "Bold"),
            .foregroundColor: UIColor.white
        ]
        button.setAttributedTitle(NSAttributedString(string: "Next question \u{2192}", attributes: attrs), for: .normal)
        button.backgroundColor = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1)
        button.layer.cornerRadius = 24
        button.clipsToBounds = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 6
        return button
    }()

    // --- Score screen ---
    private let scoreContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 247/255, green: 195/255, blue: 222/255, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.alpha = 0
        return view
    }()

    private let scoreBirdImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let scoreRingView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let scoreRingTrack = CAShapeLayer()
    private let scoreRingFill = CAShapeLayer()

    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(40, weight: "Bold")
        label.textColor = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1)
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scoreOutOfLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(14)
        label.textColor = UIColor(red: 140/255, green: 140/255, blue: 140/255, alpha: 1)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scoreSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = nunito(18, weight: "Bold")
        label.textColor = .black
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let restartButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = nunito(18, weight: "Bold")
        button.backgroundColor = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 28
        button.clipsToBounds = false
        button.translatesAutoresizingMaskIntoConstraints = false
        applyButtonShadow(button)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = hotPink
        preloadSounds()
        allQuestions = QuestionLoader.load()
        // Kick off the server fetch immediately so today's question IDs are
        // cached before the user taps Daily Challenge.
        DailyChallengeManager.prefetchTodaysChallenge()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startBirdBounce()
    }

    private func startBirdBounce() {
        birdImageView.layer.removeAllAnimations()
        UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.birdImageView.transform = CGAffineTransform(translationX: 0, y: -8)
        }
    }

    private func shakeButton(_ button: UIButton) {
        UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: []) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.125) {
                button.transform = CGAffineTransform(translationX: -12, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.125, relativeDuration: 0.125) {
                button.transform = CGAffineTransform(translationX: 12, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.125) {
                button.transform = CGAffineTransform(translationX: -8, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.375, relativeDuration: 0.125) {
                button.transform = CGAffineTransform(translationX: 8, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.125) {
                button.transform = CGAffineTransform(translationX: -4, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.625, relativeDuration: 0.125) {
                button.transform = CGAffineTransform(translationX: 4, y: 0)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                button.transform = .identity
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateWelcomeStreak()
        updateDailyChallengeStatus()

        // shadowPath must be set after layout so bounds are resolved.
        // An explicit oval path is required — UIImageView sets its image via
        // layer.contents, which CoreAnimation cannot alpha-trace for shadows.
    }

    private func updateWelcomeStreak() {
        let streak = StreakManager.currentStreak
        if streak > 0 {
            welcomeStreakLabel.text = "Streak: \(streak) day\(streak == 1 ? "" : "s")"
        } else {
            welcomeStreakLabel.text = ""
        }
    }

    private func updateDailyChallengeStatus() {
        if DailyChallengeManager.hasCompletedToday {
            dailyStatusLabel.text = "\u{2713} Daily challenge completed"
            dailyChallengeButton.isEnabled = false
            dailyChallengeButton.alpha = 0.5
        } else {
            dailyStatusLabel.text = ""
            dailyChallengeButton.isEnabled = true
            dailyChallengeButton.alpha = 1.0
        }
    }

    // MARK: - Progress Dots

    private func updateProgressDots() {
        progressDotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for i in 0..<totalQuestions {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = i == currentIndex ? 5 : 4

            if i < currentIndex {
                // Completed: solid pink small dot
                dot.backgroundColor = hotPink
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 8),
                    dot.heightAnchor.constraint(equalToConstant: 8)
                ])
            } else if i == currentIndex {
                // Current: bigger solid pink circle
                dot.backgroundColor = hotPink
                dot.layer.cornerRadius = 7
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 14),
                    dot.heightAnchor.constraint(equalToConstant: 14)
                ])
            } else {
                // Upcoming: small faded pink dot
                dot.backgroundColor = hotPink.withAlphaComponent(0.3)
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 8),
                    dot.heightAnchor.constraint(equalToConstant: 8)
                ])
                dot.layer.cornerRadius = 4
            }

            progressDotsStack.addArrangedSubview(dot)
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Create answer buttons
        for i in 0..<4 {
            let button = FullWidthButton(type: .custom)
            button.tag = i
            button.addTarget(self, action: #selector(answerTapped(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(answerTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(answerTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tintAdjustmentMode = .normal
            button.backgroundColor = hotPink
            button.layer.cornerRadius = 16
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = ViewController.nunito(24, weight: "Bold")
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.7
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.25
            button.layer.shadowOffset = CGSize(width: 0, height: 3)
            button.layer.shadowRadius = 6
            button.clipsToBounds = false
            answerButtons.append(button)
            answersContainerView.addSubview(button)

            // Every button: same left edge, same right edge, same height
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: answersContainerView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: answersContainerView.trailingAnchor),
                button.heightAnchor.constraint(equalToConstant: 64),
            ])

            if i == 0 {
                button.topAnchor.constraint(equalTo: answersContainerView.topAnchor).isActive = true
            } else {
                button.topAnchor.constraint(equalTo: answerButtons[i - 1].bottomAnchor, constant: 12).isActive = true
            }

            if i == 3 {
                button.bottomAnchor.constraint(equalTo: answersContainerView.bottomAnchor).isActive = true
            }
        }

        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTouchDown), for: .touchDown)
        nextButton.addTarget(self, action: #selector(nextTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        restartButton.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        dailyChallengeButton.addTarget(self, action: #selector(dailyChallengeTapped), for: .touchUpInside)

        // --- Welcome container ---
        view.addSubview(welcomeContainerView)
        welcomeContainerView.addSubview(welcomeBackgroundImageView)
        welcomeContainerView.addSubview(titleImageView)
        welcomeContainerView.addSubview(birdImageView)
        welcomeContainerView.addSubview(subtitleLabel)
        welcomeContainerView.addSubview(welcomeStreakLabel)
        welcomeContainerView.addSubview(playButton)
        welcomeContainerView.addSubview(dailyChallengeButton)
        welcomeContainerView.addSubview(dailyStatusLabel)
        // --- Quiz container ---
        quizContainerView.isHidden = true
        view.addSubview(quizContainerView)
        quizContainerView.addSubview(quizPinkHeaderView)
        quizContainerView.addSubview(progressLabel)
        quizContainerView.addSubview(scoreCountLabel)
        quizContainerView.addSubview(quizScrollView)
        quizScrollView.addSubview(quizContentView)
        // Z-order (back→front): pink header (in quizContainerView, behind scroll) →
        // tail → speech bubble (covers tail's top) → answers/feedback → bird on top.
        quizContentView.addSubview(speechBubbleTail)
        quizContentView.addSubview(speechBubbleView)
        speechBubbleView.addSubview(questionLabel)
        quizContentView.addSubview(answersContainerView)
        feedbackContainerView.addSubview(feedbackExclamationImageView)
        feedbackContainerView.addSubview(feedbackLabel)
        quizContentView.addSubview(feedbackContainerView)
        quizContentView.addSubview(quizBirdImageView)
        quizContainerView.addSubview(nextButton)
        quizContainerView.addSubview(progressDotsStack)

        // --- Score container ---
        view.addSubview(scoreContainerView)
        scoreContainerView.addSubview(scoreBirdImageView)
        scoreContainerView.addSubview(scoreRingView)
        scoreContainerView.addSubview(scoreSubtitleLabel)
        scoreContainerView.addSubview(restartButton)
        setupScoreRing()
        // Add labels after ring layers so they render on top
        scoreRingView.addSubview(scoreLabel)
        scoreRingView.addSubview(scoreOutOfLabel)

        NSLayoutConstraint.activate([
            // Welcome container fills entire view (edge to edge)
            welcomeContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            welcomeContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            welcomeContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            welcomeContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Background image fills welcome container
            welcomeBackgroundImageView.topAnchor.constraint(equalTo: welcomeContainerView.topAnchor),
            welcomeBackgroundImageView.leadingAnchor.constraint(equalTo: welcomeContainerView.leadingAnchor),
            welcomeBackgroundImageView.trailingAnchor.constraint(equalTo: welcomeContainerView.trailingAnchor),
            welcomeBackgroundImageView.bottomAnchor.constraint(equalTo: welcomeContainerView.bottomAnchor),

            // Title image near top - larger
            titleImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            titleImageView.centerXAnchor.constraint(equalTo: welcomeContainerView.centerXAnchor),
            titleImageView.widthAnchor.constraint(equalTo: welcomeContainerView.widthAnchor, multiplier: 0.85),
            titleImageView.heightAnchor.constraint(equalToConstant: 140),

            // Bird image right below title, minimal gap
            birdImageView.topAnchor.constraint(equalTo: titleImageView.bottomAnchor, constant: -10),
            birdImageView.centerXAnchor.constraint(equalTo: welcomeContainerView.centerXAnchor),
            birdImageView.widthAnchor.constraint(equalToConstant: 300),
            birdImageView.heightAnchor.constraint(equalToConstant: 300),

            // Subtitle below bird
            subtitleLabel.topAnchor.constraint(equalTo: birdImageView.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: welcomeContainerView.centerXAnchor),

            // Play button below subtitle
            playButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            playButton.centerXAnchor.constraint(equalTo: welcomeContainerView.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 280),
            playButton.heightAnchor.constraint(equalToConstant: 55),

            // Daily challenge button below play
            dailyChallengeButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 16),
            dailyChallengeButton.centerXAnchor.constraint(equalTo: welcomeContainerView.centerXAnchor),
            dailyChallengeButton.widthAnchor.constraint(equalToConstant: 280),
            dailyChallengeButton.heightAnchor.constraint(equalToConstant: 55),

            // Daily status label below daily challenge button
            dailyStatusLabel.topAnchor.constraint(equalTo: dailyChallengeButton.bottomAnchor, constant: 12),
            dailyStatusLabel.centerXAnchor.constraint(equalTo: welcomeContainerView.centerXAnchor),

            // Streak label below daily status
            welcomeStreakLabel.topAnchor.constraint(equalTo: dailyStatusLabel.bottomAnchor, constant: 8),
            welcomeStreakLabel.centerXAnchor.constraint(equalTo: welcomeContainerView.centerXAnchor),

            // Quiz container fills entire view
            quizContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            quizContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            quizContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            quizContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Pink header — fills top area behind the question, extending past the
            // speech-bubble tail (tail extends ~42pt below the bubble).
            quizPinkHeaderView.topAnchor.constraint(equalTo: quizContainerView.topAnchor),
            quizPinkHeaderView.leadingAnchor.constraint(equalTo: quizContainerView.leadingAnchor),
            quizPinkHeaderView.trailingAnchor.constraint(equalTo: quizContainerView.trailingAnchor),
            quizPinkHeaderView.bottomAnchor.constraint(equalTo: speechBubbleView.bottomAnchor, constant: 140),

            // Progress label (top left) - in safe area
            progressLabel.topAnchor.constraint(equalTo: quizContainerView.safeAreaLayoutGuide.topAnchor, constant: 12),
            progressLabel.leadingAnchor.constraint(equalTo: quizContainerView.leadingAnchor, constant: 20),

            // Score count label (top right)
            scoreCountLabel.centerYAnchor.constraint(equalTo: progressLabel.centerYAnchor),
            scoreCountLabel.trailingAnchor.constraint(equalTo: quizContainerView.trailingAnchor, constant: -20),
            scoreCountLabel.leadingAnchor.constraint(greaterThanOrEqualTo: progressLabel.trailingAnchor, constant: 8),

            // Scroll view below progress, above sticky next button
            quizScrollView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 2),
            quizScrollView.leadingAnchor.constraint(equalTo: quizContainerView.leadingAnchor),
            quizScrollView.trailingAnchor.constraint(equalTo: quizContainerView.trailingAnchor),
            quizScrollView.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -12),

            // Content view inside scroll view
            quizContentView.topAnchor.constraint(equalTo: quizScrollView.topAnchor),
            quizContentView.leadingAnchor.constraint(equalTo: quizScrollView.leadingAnchor),
            quizContentView.trailingAnchor.constraint(equalTo: quizScrollView.trailingAnchor),
            quizContentView.bottomAnchor.constraint(equalTo: quizScrollView.bottomAnchor),
            quizContentView.widthAnchor.constraint(equalTo: quizScrollView.widthAnchor),

            // Speech bubble - nearly full width with margins
            speechBubbleView.topAnchor.constraint(equalTo: quizContentView.topAnchor, constant: 16),
            speechBubbleView.leadingAnchor.constraint(equalTo: quizContentView.leadingAnchor, constant: 24),
            speechBubbleView.trailingAnchor.constraint(equalTo: quizContentView.trailingAnchor, constant: -24),

            // Speech bubble tail (extending from bottom of bubble, toward bird)
            speechBubbleTail.widthAnchor.constraint(equalToConstant: 80),
            speechBubbleTail.heightAnchor.constraint(equalToConstant: 80),
            speechBubbleTail.leadingAnchor.constraint(equalTo: speechBubbleView.leadingAnchor, constant: 115),
            speechBubbleTail.topAnchor.constraint(equalTo: speechBubbleView.bottomAnchor, constant: -38),

            // Question label inside bubble
            questionLabel.topAnchor.constraint(equalTo: speechBubbleView.topAnchor, constant: 20),
            questionLabel.leadingAnchor.constraint(equalTo: speechBubbleView.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: speechBubbleView.trailingAnchor, constant: -20),
            questionLabel.bottomAnchor.constraint(equalTo: speechBubbleView.bottomAnchor, constant: -20),

            // Quiz bird - flush against left edge, head overlaps question box
            quizBirdImageView.widthAnchor.constraint(equalToConstant: 250),
            quizBirdImageView.heightAnchor.constraint(equalToConstant: 250),
            quizBirdImageView.leadingAnchor.constraint(equalTo: quizContentView.leadingAnchor, constant: -30),
            quizBirdImageView.topAnchor.constraint(equalTo: speechBubbleView.bottomAnchor, constant: -40),

            // Answers stack below bubble
            answersContainerView.topAnchor.constraint(equalTo: quizBirdImageView.bottomAnchor, constant: -30),
            answersContainerView.centerXAnchor.constraint(equalTo: quizContentView.centerXAnchor),
            answersContainerView.widthAnchor.constraint(equalTo: quizContentView.widthAnchor, multiplier: 0.9),

            // Feedback container — also defines the scroll content's bottom
            feedbackContainerView.topAnchor.constraint(equalTo: answersContainerView.bottomAnchor, constant: 16),
            feedbackContainerView.leadingAnchor.constraint(equalTo: quizContentView.leadingAnchor, constant: 24),
            feedbackContainerView.trailingAnchor.constraint(equalTo: quizContentView.trailingAnchor, constant: -24),
            feedbackContainerView.bottomAnchor.constraint(equalTo: quizContentView.bottomAnchor, constant: -20),

            // Decorative "!" image — fixed height, width follows the asset's
            // aspect ratio (221:500 → ~0.442). Positioned to roughly align with
            // the first line of feedback text.
            feedbackExclamationImageView.leadingAnchor.constraint(equalTo: feedbackContainerView.leadingAnchor, constant: 8),
            feedbackExclamationImageView.topAnchor.constraint(equalTo: feedbackContainerView.topAnchor, constant: 8),
            feedbackExclamationImageView.heightAnchor.constraint(equalToConstant: 64),
            feedbackExclamationImageView.widthAnchor.constraint(equalTo: feedbackExclamationImageView.heightAnchor, multiplier: 221.0/500.0),

            // Feedback label sits to the right of the "!" mark, left-aligned text.
            feedbackLabel.topAnchor.constraint(equalTo: feedbackContainerView.topAnchor, constant: 8),
            feedbackLabel.leadingAnchor.constraint(equalTo: feedbackExclamationImageView.trailingAnchor, constant: 16),
            feedbackLabel.trailingAnchor.constraint(equalTo: feedbackContainerView.trailingAnchor, constant: -8),
            feedbackLabel.bottomAnchor.constraint(equalTo: feedbackContainerView.bottomAnchor, constant: -8),

            // Next button — sticky bar pinned above the progress dots, outside the scroll view
            nextButton.centerXAnchor.constraint(equalTo: quizContainerView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 240),
            nextButton.heightAnchor.constraint(equalToConstant: 48),
            nextButton.bottomAnchor.constraint(equalTo: progressDotsStack.topAnchor, constant: -20),

            // Progress dots at bottom of quiz screen
            progressDotsStack.centerXAnchor.constraint(equalTo: quizContainerView.centerXAnchor),
            progressDotsStack.bottomAnchor.constraint(equalTo: quizContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            progressDotsStack.heightAnchor.constraint(equalToConstant: 14),

            // Score container fills entire view
            scoreContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            scoreContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scoreContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scoreContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Score bird above ring
            scoreBirdImageView.centerXAnchor.constraint(equalTo: scoreContainerView.centerXAnchor),
            scoreBirdImageView.bottomAnchor.constraint(equalTo: scoreRingView.topAnchor, constant: -5),
            scoreBirdImageView.widthAnchor.constraint(equalToConstant: 250),
            scoreBirdImageView.heightAnchor.constraint(equalToConstant: 250),

            // Score ring centered
            scoreRingView.centerXAnchor.constraint(equalTo: scoreContainerView.centerXAnchor),
            scoreRingView.centerYAnchor.constraint(equalTo: scoreContainerView.centerYAnchor, constant: 60),
            scoreRingView.widthAnchor.constraint(equalToConstant: 150),
            scoreRingView.heightAnchor.constraint(equalToConstant: 150),

            // Score label centered in ring
            scoreLabel.centerXAnchor.constraint(equalTo: scoreRingView.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: scoreRingView.centerYAnchor, constant: -8),

            // "out of" label below score number
            scoreOutOfLabel.centerXAnchor.constraint(equalTo: scoreRingView.centerXAnchor),
            scoreOutOfLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 0),

            // Score subtitle
            scoreSubtitleLabel.topAnchor.constraint(equalTo: scoreRingView.bottomAnchor, constant: 24),
            scoreSubtitleLabel.leadingAnchor.constraint(equalTo: scoreContainerView.leadingAnchor, constant: 24),
            scoreSubtitleLabel.trailingAnchor.constraint(equalTo: scoreContainerView.trailingAnchor, constant: -24),

            // Restart button
            restartButton.topAnchor.constraint(equalTo: scoreSubtitleLabel.bottomAnchor, constant: 40),
            restartButton.centerXAnchor.constraint(equalTo: scoreContainerView.centerXAnchor),
            restartButton.widthAnchor.constraint(equalToConstant: 220),
            restartButton.heightAnchor.constraint(equalToConstant: 55),
        ])
    }

    private func setupScoreRing() {
        let size: CGFloat = 150
        let center = CGPoint(x: size / 2, y: size / 2)
        let ringRadius: CGFloat = 63
        let ringWidth: CGFloat = 12

        // White filled circle inside the ring
        let whiteFill = CAShapeLayer()
        let innerRadius = ringRadius - ringWidth / 2
        whiteFill.path = UIBezierPath(arcCenter: center, radius: innerRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        whiteFill.fillColor = UIColor.white.cgColor
        scoreRingView.layer.addSublayer(whiteFill)

        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi
        let path = UIBezierPath(arcCenter: center, radius: ringRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)

        // Track (darker pink ring for wrong answers)
        scoreRingTrack.path = path.cgPath
        scoreRingTrack.fillColor = UIColor.clear.cgColor
        scoreRingTrack.strokeColor = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 0.35).cgColor
        scoreRingTrack.lineWidth = ringWidth
        scoreRingTrack.lineCap = .round
        scoreRingView.layer.addSublayer(scoreRingTrack)

        // Fill (hot pink ring for correct answers)
        scoreRingFill.path = path.cgPath
        scoreRingFill.fillColor = UIColor.clear.cgColor
        scoreRingFill.strokeColor = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1).cgColor
        scoreRingFill.lineWidth = ringWidth
        scoreRingFill.lineCap = .round
        scoreRingFill.strokeEnd = 0
        scoreRingView.layer.addSublayer(scoreRingFill)
    }

    private func animateScoreRing() {
        let targetFraction = CGFloat(score) / CGFloat(totalQuestions)

        scoreRingFill.strokeEnd = 0
        let ringAnim = CABasicAnimation(keyPath: "strokeEnd")
        ringAnim.fromValue = 0
        ringAnim.toValue = targetFraction
        ringAnim.duration = 1.0
        ringAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ringAnim.fillMode = .forwards
        ringAnim.isRemovedOnCompletion = false
        scoreRingFill.add(ringAnim, forKey: "ringFill")

        // Count-up animation for the number
        scoreLabel.text = "0"
        scoreOutOfLabel.text = "out of \(totalQuestions)"
        let steps = score
        guard steps > 0 else {
            scoreLabel.text = "0"
            return
        }
        let totalDuration = 1.0
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration * Double(i) / Double(steps)) { [weak self] in
                self?.scoreLabel.text = "\(i)"
            }
        }
    }

    // MARK: - Transitions

    private func transition(from fromView: UIView, to toView: UIView) {
        toView.isHidden = false
        toView.alpha = 0
        UIView.animate(withDuration: 0.6, animations: {
            fromView.alpha = 0
            toView.alpha = 1
        }, completion: { _ in
            fromView.isHidden = true
        })
    }

    // MARK: - Quiz Logic

    @objc private func playTapped() {
        playAgainSound()
        isDailyChallenge = false
        startQuiz()
    }

    @objc private func dailyChallengeTapped() {
        playAgainSound()
        isDailyChallenge = true
        startQuiz()
    }

    private func startQuiz() {
        if isDailyChallenge {
            quizQuestions = DailyChallengeManager.questionsForToday(from: allQuestions, count: totalQuestions)
        } else {
            // Spaced-repetition: mix due-for-review weak items with new questions.
            quizQuestions = QuestionStatsManager.selectQuiz(from: allQuestions, count: totalQuestions)
        }
        currentIndex = 0
        score = 0

        scoreCountLabel.text = "Score: 0"
        scoreContainerView.isHidden = true
        scoreContainerView.alpha = 0

        transition(from: welcomeContainerView, to: quizContainerView)
        showQuestion()
    }

    private func showQuestion() {
        hasAnswered = false
        let question = quizQuestions[currentIndex]

        progressLabel.text = "\(currentIndex + 1)/\(totalQuestions)"
        let qPara = NSMutableParagraphStyle()
        qPara.lineSpacing = 6
        qPara.alignment = .center
        questionLabel.attributedText = NSAttributedString(string: question.question, attributes: [
            .paragraphStyle: qPara,
            .font: questionLabel.font as Any,
            .foregroundColor: questionLabel.textColor as Any
        ])

        // Reset bird to talking pose
        quizBirdImageView.image = UIImage(named: "bird-talk")

        // Update progress dots
        updateProgressDots()

        // Shuffle answer order
        shuffledAnswerIndices = Array(0..<question.answers.count).shuffled()

        for (i, button) in answerButtons.enumerated() {
            // Reset to default pink bg, white text, no icon
            button.setTitle(question.answers[shuffledAnswerIndices[i]], for: .normal)
            button.backgroundColor = hotPink
            button.setTitleColor(.white, for: .normal)
            button.setImage(nil, for: .normal)
            button.layer.cornerRadius = 16
            button.isEnabled = true
            button.alpha = 1
            button.layer.removeAllAnimations()
            button.transform = .identity
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.viewWithTag(999)?.removeFromSuperview()
            // Reset shadow to consistent style
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.25
            button.layer.shadowOffset = CGSize(width: 0, height: 3)
            button.layer.shadowRadius = 6
            button.clipsToBounds = false
        }

        feedbackContainerView.isHidden = true
        feedbackContainerView.transform = .identity
        answersContainerView.transform = .identity
        nextButton.isHidden = true
        quizScrollView.setContentOffset(.zero, animated: false)

        // Cascade entrance animations
        quizContentView.alpha = 1
        quizBirdImageView.alpha = 0
        quizBirdImageView.transform = CGAffineTransform(translationX: -30, y: 0)
        speechBubbleView.alpha = 0
        speechBubbleView.transform = CGAffineTransform(translationX: 0, y: 15)
        speechBubbleTail.alpha = 0
        for button in answerButtons {
            button.alpha = 0
            button.transform = CGAffineTransform(translationX: 0, y: 20)
        }

        // 1) Bird slides in from left
        UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.quizBirdImageView.alpha = 1
            self.quizBirdImageView.transform = .identity
        }

        // 2) Speech bubble with question
        UIView.animate(withDuration: 0.4, delay: 0.35, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.speechBubbleView.alpha = 1
            self.speechBubbleView.transform = .identity
            self.speechBubbleTail.alpha = 1
        }

        // 3) Answer buttons stagger in
        for (i, button) in answerButtons.enumerated() {
            UIView.animate(
                withDuration: 0.4,
                delay: 0.65 + Double(i) * 0.1,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: .curveEaseOut
            ) {
                button.alpha = 1
                button.transform = .identity
            }
        }
    }

    @objc private func answerTouchDown(_ sender: UIButton) {
        guard !hasAnswered else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.toValue = 0.95
        scale.duration = 0.1
        scale.fillMode = .forwards
        scale.isRemovedOnCompletion = false
        sender.layer.add(scale, forKey: "touchDownScale")
    }

    @objc private func answerTouchUp(_ sender: UIButton) {
        guard !hasAnswered else { return }
        sender.layer.removeAnimation(forKey: "touchDownScale")
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.95
        spring.toValue = 1.0
        spring.damping = 8
        spring.stiffness = 300
        spring.mass = 0.5
        spring.duration = spring.settlingDuration
        sender.layer.add(spring, forKey: "touchUpSpring")
    }

    @objc private func answerTapped(_ sender: UIButton) {
        guard !hasAnswered else { return }
        hasAnswered = true
        // The touchUp handler bails out once hasAnswered is true, so clear
        // the touchDown scale here to keep the tapped button at full size.
        sender.layer.removeAnimation(forKey: "touchDownScale")

        let question = quizQuestions[currentIndex]
        let selectedButton = sender.tag
        let selectedOriginalIndex = shuffledAnswerIndices[selectedButton]
        let correctOriginalIndex = question.correctAnswerIndex
        let correctButton = shuffledAnswerIndices.firstIndex(of: correctOriginalIndex)!

        let isCorrect = selectedOriginalIndex == correctOriginalIndex
        if isCorrect {
            score += 1
            scoreCountLabel.text = "Score: \(score)"
            playCorrectSound()
        } else {
            playWrongSound()
        }

        // Spaced-repetition: record the result so the next non-daily quiz
        // prioritises questions the user is struggling with.
        QuestionStatsManager.recordAnswer(for: question, correct: isCorrect)

        // Color all buttons based on answer state
        for (i, button) in answerButtons.enumerated() {
            // Remove any previously added icon views
            button.viewWithTag(999)?.removeFromSuperview()
            button.setImage(nil, for: .normal)

            if i == correctButton {
                // Correct answer: green bg, white text, wine glasses icon right-aligned
                button.backgroundColor = correctGreen
                button.setTitleColor(.white, for: .normal)
                let iconView = UIImageView(image: UIImage(named: "glasses")?.withRenderingMode(.alwaysTemplate))
                iconView.tintColor = .white
                iconView.contentMode = .scaleAspectFit
                iconView.tag = 999
                iconView.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(iconView)
                NSLayoutConstraint.activate([
                    iconView.widthAnchor.constraint(equalToConstant: 36),
                    iconView.heightAnchor.constraint(equalToConstant: 36),
                    iconView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -20),
                    iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            } else if i == selectedButton && !isCorrect {
                // Wrong selected: red bg, white text, broken glass icon right-aligned
                button.backgroundColor = wrongRed
                button.setTitleColor(.white, for: .normal)
                let iconView = UIImageView(image: UIImage(named: "broken-glass")?.withRenderingMode(.alwaysTemplate))
                iconView.tintColor = .white
                iconView.contentMode = .scaleAspectFit
                iconView.tag = 999
                iconView.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(iconView)
                NSLayoutConstraint.activate([
                    iconView.widthAnchor.constraint(equalToConstant: 36),
                    iconView.heightAnchor.constraint(equalToConstant: 36),
                    iconView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -20),
                    iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            } else {
                // Unselected: faded pink bg, white text, no shadow
                button.backgroundColor = hotPink
                button.setTitleColor(.white, for: .normal)
                button.alpha = 0.4
                button.layer.shadowOpacity = 0
            }

            // Add drop shadow to correct answer
            if i == correctButton {
                button.layer.shadowColor = UIColor.black.cgColor
                button.layer.shadowOpacity = 0.45
                button.layer.shadowOffset = CGSize(width: 0, height: 2)
                button.layer.shadowRadius = 1
            }
        }

        // Shake animation + haptic on wrong answer button
        if !isCorrect {
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.shakeButton(sender)
            }
        }

        // Switch bird to listening pose in place
        UIView.animate(withDuration: 0.15, delay: 0.05, options: .curveEaseIn) {
            self.quizBirdImageView.transform = CGAffineTransform(scaleX: 1.0, y: 0.93)
        } completion: { _ in
            self.quizBirdImageView.image = UIImage(named: "bird-listen1")
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5, options: []) {
                self.quizBirdImageView.transform = .identity
            }
        }
        UIView.animate(withDuration: 0.4, delay: 0.05, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.answersContainerView.transform = CGAffineTransform(translationX: 0, y: -25)
        }

        // Show feedback text (white, bold, centered on pink bg)
        let fPara = NSMutableParagraphStyle()
        fPara.lineSpacing = 2
        fPara.alignment = feedbackLabel.textAlignment
        feedbackLabel.attributedText = NSAttributedString(string: question.feedback, attributes: [
            .paragraphStyle: fPara,
            .font: feedbackLabel.font as Any,
            .foregroundColor: feedbackLabel.textColor as Any
        ])
        feedbackContainerView.isHidden = false
        feedbackContainerView.alpha = 0
        feedbackContainerView.transform = CGAffineTransform(translationX: 0, y: -13)
        UIView.animate(withDuration: 0.35, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.feedbackContainerView.alpha = 1
            self.feedbackContainerView.transform = CGAffineTransform(translationX: 0, y: -25)
        }

        // Show next button
        let nextAttrs: [NSAttributedString.Key: Any] = [
            .font: ViewController.nunito(18, weight: "Bold"),
            .foregroundColor: UIColor.white
        ]
        if currentIndex < totalQuestions - 1 {
            nextButton.setAttributedTitle(NSAttributedString(string: "Next question \u{2192}", attributes: nextAttrs), for: .normal)
        } else {
            nextButton.setAttributedTitle(NSAttributedString(string: "See results \u{2192}", attributes: nextAttrs), for: .normal)
        }
        nextButton.isHidden = false

        // Safety net: if the content is taller than the scroll view, scroll the feedback into view.
        quizContentView.layoutIfNeeded()
        let feedbackRect = quizScrollView.convert(feedbackContainerView.bounds, from: feedbackContainerView)
        quizScrollView.scrollRectToVisible(feedbackRect, animated: true)
    }

    @objc private func nextTouchDown() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.toValue = 0.93
        scale.duration = 0.1
        scale.fillMode = .forwards
        scale.isRemovedOnCompletion = false
        nextButton.layer.add(scale, forKey: "touchDownScale")
    }

    @objc private func nextTouchUp() {
        nextButton.layer.removeAnimation(forKey: "touchDownScale")
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.93
        spring.toValue = 1.0
        spring.damping = 6
        spring.stiffness = 250
        spring.mass = 0.5
        spring.duration = spring.settlingDuration
        nextButton.layer.add(spring, forKey: "touchUpSpring")
    }

    @objc private func nextTapped() {
        playNextSound()
        currentIndex += 1
        if currentIndex < totalQuestions {
            UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseIn, animations: {
                self.quizContentView.alpha = 0
            }, completion: { _ in
                self.showQuestion()
            })
        } else {
            showScore()
        }
    }

    private func showScore() {
        if isDailyChallenge {
            DailyChallengeManager.recordScore(score)
            StreakManager.recordCompletion()
            scoreSubtitleLabel.text = scoreMessage()
            let restartAttrs: [NSAttributedString.Key: Any] = [
                .font: ViewController.nunito(18, weight: "Bold"),
                .foregroundColor: UIColor.white
            ]
            restartButton.setAttributedTitle(NSAttributedString(string: "\u{21BB} Back to menu", attributes: restartAttrs), for: .normal)
        } else {
            scoreSubtitleLabel.text = scoreMessage()
            let restartAttrs: [NSAttributedString.Key: Any] = [
                .font: ViewController.nunito(18, weight: "Bold"),
                .foregroundColor: UIColor.white
            ]
            restartButton.setAttributedTitle(NSAttributedString(string: "\u{21BB} Play again", attributes: restartAttrs), for: .normal)
        }

        // Show bird and play sound based on score
        if score >= 5 {
            scoreBirdImageView.image = UIImage(named: "bird-yes")
            playSound(named: "win")
        } else {
            scoreBirdImageView.image = UIImage(named: "bird-no")
            playSound(named: "fail")
        }

        transition(from: quizContainerView, to: scoreContainerView)
        animateScoreRing()
    }

    private func scoreMessage() -> String {
        switch score {
        case 9...10: return "You rock! Can you do it again?"
        case 7...8: return "Great job! Almost a sommelier!"
        case 5...6: return "Not bad! Keep studying!"
        default: return "Keep going, you'll get there!"
        }
    }

    @objc private func restartTapped() {
        updateWelcomeStreak()
        updateDailyChallengeStatus()
        transition(from: scoreContainerView, to: welcomeContainerView)
        startBirdBounce()
    }
}
