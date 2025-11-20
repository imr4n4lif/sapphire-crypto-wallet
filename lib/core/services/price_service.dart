import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../../models/wallet.dart';

class PriceService {
  static final PriceService _instance = PriceService._internal();
  factory PriceService() => _instance;
  PriceService._internal();

  // Enhanced caching with per-coin timestamps
  final Map<CoinType, PriceData> _priceCache = {};
  final Map<String, List<PricePoint>> _historyCache = {};
  final Map<CoinType, DateTime> _lastFetchTime = {};
  final Map<String, DateTime> _historyFetchTime = {};

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

  Future<PriceData> fetchPrice(CoinType coinType) async {
    try {
      // Check cache validity (1 minute)
      if (_isCacheFresh(coinType)) {
        return _priceCache[coinType]!;
      }

      final coinId = _getCoinId(coinType);
      final url = '${AppConstants.priceApiUrl}/coins/markets?vs_currency=usd&ids=$coinId&order=market_cap_desc&per_page=1&page=1&sparkline=false&price_change_percentage=24h';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final priceData = PriceData.fromJson(data[0]);
          _priceCache[coinType] = priceData;
          _lastFetchTime[coinType] = DateTime.now();

          print('✅ Fetched ${coinType.name} price: \$${priceData.price}');
          return priceData;
        }
      }

      // Return cached data if available
      if (_priceCache.containsKey(coinType)) {
        print('⚠️ Using cached price for ${coinType.name}');
        return _priceCache[coinType]!;
      }

      return PriceData(price: 0.0, change24h: 0.0, history: []);
    } catch (e) {
      print('❌ Error fetching price for $coinType: $e');
      return _priceCache[coinType] ?? PriceData(price: 0.0, change24h: 0.0, history: []);
    }
  }

  Future<Map<CoinType, PriceData>> fetchAllPrices() async {
    final Map<CoinType, PriceData> prices = {};

    // Fetch concurrently for better performance
    final results = await Future.wait([
      fetchPrice(CoinType.btc),
      fetchPrice(CoinType.eth),
      fetchPrice(CoinType.fil),
    ]);

    prices[CoinType.btc] = results[0];
    prices[CoinType.eth] = results[1];
    prices[CoinType.fil] = results[2];

    return prices;
  }

  PriceData? getCachedPrice(CoinType coinType) {
    return _priceCache[coinType];
  }

  Future<List<PricePoint>> fetchPriceHistory(CoinType coinType, {int days = 7}) async {
    try {
      final cacheKey = '${coinType.name}_$days';

      // Check history cache (5 minutes)
      if (_isHistoryCacheFresh(cacheKey)) {
        print('📦 Using cached history for ${coinType.name} ($days days)');
        return _historyCache[cacheKey]!;
      }

      final coinId = _getCoinId(coinType);

      // Determine interval based on days
      String interval = 'daily';
      if (days <= 1) {
        interval = 'hourly';  // For 1 day, use hourly data
      } else if (days <= 7) {
        interval = 'hourly';  // For 1 week, still hourly for better resolution
      } else if (days <= 90) {
        interval = 'daily';
      }

      final url = '${AppConstants.priceApiUrl}/coins/$coinId/market_chart?vs_currency=usd&days=$days&interval=$interval';

      print('🔄 Fetching price history for ${coinType.name} ($days days, $interval)');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List;

        if (prices.isEmpty) {
          print('⚠️ No price data returned for ${coinType.name}');
          return _historyCache[cacheKey] ?? [];
        }

        final pricePoints = prices.map((point) {
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0]),
            price: (point[1] as num).toDouble(),
          );
        }).toList();

        _historyCache[cacheKey] = pricePoints;
        _historyFetchTime[cacheKey] = DateTime.now();

        print('✅ Fetched ${pricePoints.length} price points for ${coinType.name}');
        return pricePoints;
      } else {
        print('⚠️ HTTP ${response.statusCode} for ${coinType.name} history');
      }

      return _historyCache[cacheKey] ?? [];
    } catch (e) {
      print('❌ Error fetching price history for $coinType: $e');
      return _historyCache['${coinType.name}_$days'] ?? [];
    }
  }

  bool _isCacheFresh(CoinType coinType) {
    if (!_priceCache.containsKey(coinType)) return false;
    if (!_lastFetchTime.containsKey(coinType)) return false;

    final age = DateTime.now().difference(_lastFetchTime[coinType]!);
    return age < const Duration(minutes: 1);
  }

  bool _isHistoryCacheFresh(String cacheKey) {
    if (!_historyCache.containsKey(cacheKey)) return false;
    if (!_historyFetchTime.containsKey(cacheKey)) return false;

    final age = DateTime.now().difference(_historyFetchTime[cacheKey]!);
    return age < const Duration(minutes: 5);
  }

  void clearCache() {
    _priceCache.clear();
    _historyCache.clear();
    _lastFetchTime.clear();
    _historyFetchTime.clear();
    print('🗑️ Price cache cleared');
  }
}