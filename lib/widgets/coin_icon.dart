import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/constants/app_constants.dart';

class CoinIcon extends StatelessWidget {
  final CoinType coinType;
  final double size;
  final Color? color;

  const CoinIcon({
    super.key,
    required this.coinType,
    this.size = 24,
    this.color,
  });

  String _getSvgPath() {
    switch (coinType) {
      case CoinType.btc:
        return 'assets/icons/bitcoin.svg';
      case CoinType.eth:
        return 'assets/icons/ethereum.svg';
      case CoinType.trx:
        return 'assets/icons/tron.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Don't apply color filter for Tron to keep original red color
    // Only apply color filter if explicitly provided AND not Tron
    final shouldApplyColor = color != null && coinType != CoinType.trx;

    return SvgPicture.asset(
      _getSvgPath(),
      width: size,
      height: size,
      colorFilter: shouldApplyColor
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      // Allow original colors to show through for Tron
      fit: BoxFit.contain,
    );
  }
}