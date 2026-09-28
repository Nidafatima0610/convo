enum GameType {
  wouldYouRather,
  thisOrThat,
  emojiGuess,
  truthOrDare,
  quickQuiz;

  String get label {
    switch (this) {
      case GameType.wouldYouRather:
        return 'Would You Rather';
      case GameType.thisOrThat:
        return 'This or That';
      case GameType.emojiGuess:
        return 'Emoji Guess';
      case GameType.truthOrDare:
        return 'Truth or Dare';
      case GameType.quickQuiz:
        return 'Quick Quiz';
    }
  }

  String get emoji {
    switch (this) {
      case GameType.wouldYouRather:
        return '🤔';
      case GameType.thisOrThat:
        return '⚡';
      case GameType.emojiGuess:
        return '🕵️';
      case GameType.truthOrDare:
        return '🔥';
      case GameType.quickQuiz:
        return '🧠';
    }
  }

  static GameType fromString(String? val) {
    switch (val) {
      case 'wouldYouRather':
        return GameType.wouldYouRather;
      case 'thisOrThat':
        return GameType.thisOrThat;
      case 'emojiGuess':
        return GameType.emojiGuess;
      case 'truthOrDare':
        return GameType.truthOrDare;
      case 'quickQuiz':
        return GameType.quickQuiz;
      default:
        return GameType.wouldYouRather;
    }
  }

  String toValue() => name;
}

class GameModel {
  const GameModel({
    required this.id,
    required this.gameType,
    required this.title,
    required this.question,
    required this.options,
    this.answers = const {},
    this.correctAnswer,
    this.creatorId = '',
    this.creatorName = '',
    this.status = 'active',
  });

  final String id;
  final GameType gameType;
  final String title;
  final String question;
  final List<String> options;
  final Map<String, String> answers; // userId -> selected option/answer
  final String? correctAnswer; // optional for quizzes
  final String creatorId;
  final String creatorName;
  final String status; // 'active', 'completed'

  bool isAnsweredBy(String userId) => answers.containsKey(userId);
  String? answerOf(String userId) => answers[userId];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameType': gameType.toValue(),
      'title': title,
      'question': question,
      'options': options,
      'answers': answers,
      'correctAnswer': correctAnswer,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'status': status,
    };
  }

  factory GameModel.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];

    final rawAnswers = map['answers'];
    final answers = <String, String>{};
    if (rawAnswers is Map) {
      rawAnswers.forEach((key, val) {
        answers[key.toString()] = val.toString();
      });
    }

    return GameModel(
      id: map['id'] as String? ?? '',
      gameType: GameType.fromString(map['gameType'] as String?),
      title: map['title'] as String? ?? 'Game',
      question: map['question'] as String? ?? '',
      options: options,
      answers: answers,
      correctAnswer: map['correctAnswer'] as String?,
      creatorId: map['creatorId'] as String? ?? '',
      creatorName: map['creatorName'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }

  GameModel copyWith({
    String? id,
    GameType? gameType,
    String? title,
    String? question,
    List<String>? options,
    Map<String, String>? answers,
    String? correctAnswer,
    String? creatorId,
    String? creatorName,
    String? status,
  }) {
    return GameModel(
      id: id ?? this.id,
      gameType: gameType ?? this.gameType,
      title: title ?? this.title,
      question: question ?? this.question,
      options: options ?? this.options,
      answers: answers ?? this.answers,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      status: status ?? this.status,
    );
  }

  /// Curated template prompts for each game
  static List<GameModel> getPresetTemplates() {
    return [
      // Would You Rather
      const GameModel(
        id: 'wyr_1',
        gameType: GameType.wouldYouRather,
        title: 'Superpower Dilemma',
        question: 'Would you rather have the ability to fly or be invisible?',
        options: ['Fly at supersonic speeds', 'Turn completely invisible'],
      ),
      const GameModel(
        id: 'wyr_2',
        gameType: GameType.wouldYouRather,
        title: 'Time Travel',
        question: 'Would you rather travel 100 years into the past or 100 years into the future?',
        options: ['100 Years into the Past', '100 Years into the Future'],
      ),

      // This or That
      const GameModel(
        id: 'tot_1',
        gameType: GameType.thisOrThat,
        title: 'Morning Fuel',
        question: 'Coffee or Tea to start the day?',
        options: ['Coffee ☕', 'Tea 🍵'],
      ),
      const GameModel(
        id: 'tot_2',
        gameType: GameType.thisOrThat,
        title: 'Life Pace',
        question: 'Night Owl or Early Bird?',
        options: ['Night Owl 🦉', 'Early Bird 🌅'],
      ),

      // Emoji Guess
      const GameModel(
        id: 'eg_1',
        gameType: GameType.emojiGuess,
        title: 'Guess the Movie Vibe',
        question: 'What movie genre is this?\n🍿 🎬 👻 😱',
        options: [
          'Horror Movie',
          'Romantic Comedy',
          'Sci-Fi Action',
          'Animated Cartoon',
        ],
        correctAnswer: 'Horror Movie',
      ),

      // Truth or Dare
      const GameModel(
        id: 'tod_1',
        gameType: GameType.truthOrDare,
        title: 'Truth Session',
        question: 'Truth: What is your biggest guilty pleasure song?',
        options: ['Reveal Truth in Chat', 'Pass to other player'],
      ),
      const GameModel(
        id: 'tod_2',
        gameType: GameType.truthOrDare,
        title: 'Voice Dare',
        question: 'Dare: Send a 10-second voice note singing your favorite song right now!',
        options: ['Accepted! Sending audio', 'Too shy / Chicken out 🐔'],
      ),

      // Quick Quiz
      const GameModel(
        id: 'qq_1',
        gameType: GameType.quickQuiz,
        title: 'Solar System Trivia',
        question:
            'Which planet has the most confirmed moons in our solar system?',
        options: ['Jupiter', 'Saturn', 'Uranus', 'Mars'],
        correctAnswer: 'Saturn',
      ),
    ];
  }
}
