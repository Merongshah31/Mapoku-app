/// A redeemable reward in the mapOKU points catalogue.
///
/// The catalogue is hardcoded for the hackathon demo so redemption never
/// depends on a backend that does not yet expose a rewards endpoint.
class Reward {
  const Reward({
    required this.id,
    required this.brand,
    required this.label,
    required this.cost,
    required this.emoji,
    this.tagline = '',
    this.colorValue = 0xFF346F4B,
  });

  final String id;
  final String brand;
  final String label;
  final int cost;
  final String emoji;
  final String tagline;

  /// ARGB colour used to tint the reward card.
  final int colorValue;

  bool canAfford(int points) => points >= cost;
}

/// A redeemed reward code stored locally after a successful redemption.
class Redemption {
  const Redemption({
    required this.rewardId,
    required this.brand,
    required this.label,
    required this.code,
    required this.cost,
    required this.redeemedAt,
  });

  final String rewardId;
  final String brand;
  final String label;
  final String code;
  final int cost;
  final DateTime redeemedAt;

  Map<String, dynamic> toJson() => {
        'rewardId': rewardId,
        'brand': brand,
        'label': label,
        'code': code,
        'cost': cost,
        'redeemedAt': redeemedAt.toIso8601String(),
      };

  factory Redemption.fromJson(Map<String, dynamic> json) {
    return Redemption(
      rewardId: json['rewardId']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      redeemedAt: DateTime.tryParse(json['redeemedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}