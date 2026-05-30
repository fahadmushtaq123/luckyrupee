class DrawModel {
  final int id;
  final String prizeName, prizeDescription, prizeImageUrl, prizeType, category, status;
  final double prizeValue, entryPrice;
  final int maxEntries, maxPerUser, entriesSold, userEntries;
  final bool isFeatured;
  final DateTime endTime;

  const DrawModel({required this.id, required this.prizeName, required this.prizeDescription,
    required this.prizeImageUrl, required this.prizeValue, required this.prizeType,
    required this.entryPrice, required this.maxEntries, required this.maxPerUser,
    required this.category, required this.status, required this.isFeatured,
    required this.endTime, required this.entriesSold, required this.userEntries});

  double get fillPercent => entriesSold / maxEntries;
  int get spotsLeft => maxEntries - entriesSold;
  bool get isAlmostFull => fillPercent > 0.85;

  factory DrawModel.fromJson(Map<String, dynamic> j) => DrawModel(
    id: j['id'], prizeName: j['prize_name'], prizeDescription: j['prize_description'] ?? '',
    prizeImageUrl: j['prize_image_url'] ?? '', prizeValue: (j['prize_value'] as num).toDouble(),
    prizeType: j['prize_type'] ?? 'physical', entryPrice: (j['entry_price'] as num).toDouble(),
    maxEntries: j['max_entries'], maxPerUser: j['max_per_user'] ?? 50,
    category: j['category'] ?? 'gadget', status: j['status'], isFeatured: j['is_featured'] ?? false,
    endTime: DateTime.parse(j['end_time']),
    entriesSold: int.parse(j['entries_sold'].toString()),
    userEntries: int.parse((j['user_entries'] ?? 0).toString()));
}

class SkillQuestion {
  final int id;
  final String question, optionA, optionB, optionC, optionD;
  const SkillQuestion({required this.id, required this.question,
    required this.optionA, required this.optionB, required this.optionC, required this.optionD});
  factory SkillQuestion.fromJson(Map<String, dynamic> j) => SkillQuestion(
    id: j['id'], question: j['question'], optionA: j['option_a'],
    optionB: j['option_b'], optionC: j['option_c'], optionD: j['option_d']);
}
