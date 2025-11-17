import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../../models/wallet.dart';

class PriceService {
  static final PriceService _instance = PriceService._internal();
  factory PriceService() => _instance;
  PriceService._internal();

  // Cache for prices
  final Map<CoinType, PriceData> _priceCache = {};
  DateTime? _lastFetch;

  // Get coin ID for API
  String _getCoinId(CoinType coinType) {
    switch (coinType) {
      case CoinType.btc:
        return AppConstants.btcCoinId;
      case CoinType.eth:
        return AppConstants.ethCoinId;
      case CoinType.fil:
        return AppConstants.filCoinId;
    }
  }

  // Fetch price for a single coin
  Future<PriceData> fetchPrice(CoinType coinType) async {
    try {
      final coinId = _getCoinId(coinType);
      final url = '${AppConstants.priceApiUrl}/coins/markets?vs_currency=usd&ids=$coinId&order=market_cap_desc&per_page=1&page=1&sparkline=false&price_change_percentage=24h';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final priceData = PriceData.fromJson(data[0]);
          _priceCache[coinType] = priceData;
          _lastFetch = DateTime.now();
          return priceData;
        }
      }

      // Return cached data if available
      if (_priceCache.containsKey(coinType)) {
        return _priceCache[coinType]!;
      }

      // Return default data
      return PriceData(price: 0.0, change24h: 0.0, history: []);
    } catch (e) {
      print('Error fetching price for $coinType: $e');

      // Return cached data if available
      if (_priceCache.containsKey(coinType)) {
        return _priceCache[coinType]!;
      }

      return PriceData(price: 0.0, change24h: 0.0, history: []);
    }
  }

  // Fetch prices for all coins
  Future<Map<CoinType, PriceData>> fetchAllPrices() async {
    final Map<CoinType, PriceData> prices = {};

    for (final coinType in CoinType.values) {
      prices[coinType] = await fetchPrice(coinType);
    }

    return prices;
  }

  // Get cached price
  PriceData? getCachedPrice(CoinType coinType) {
    return _priceCache[coinType];
  }

  // Fetch price history for charts
  Future<List<PricePoint>> fetchPriceHistory(CoinType coinType, {int days = 7}) async {
    try {
      final coinId = _getCoinId(coinType);
      final url = '${AppConstants.priceApiUrl}/coins/$coinId/market_chart?vs_currency=usd&days=$days';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List;

        return prices.map((point) {
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0]),
            price: point[1].toDouble(),
          );
        }).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching price history for $coinType: $e');
      return [];
    }
  }

  // Check if cache is fresh (less than 1 minute old)
  bool isCacheFresh() {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!).inMinutes < 1;
  }

  // Clear cache
  void clearCache() {
    _priceCache.clear();
    _lastFetch = null;
  }
}