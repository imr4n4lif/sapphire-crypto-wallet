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
    return SvgPicture.asset(
      _getSvgPath(),
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}