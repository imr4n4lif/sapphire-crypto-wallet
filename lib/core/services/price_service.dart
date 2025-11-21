import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../constants/app_constants.dart';
import '../../models/wallet.dart';

class PriceService {
  static final PriceService _instance = PriceService._internal();
  factory PriceService() => _instance;
  PriceService._internal();

  // Enhanced caching with longer TTL
  final Map<CoinType, PriceData> _priceCache = {};
  final Map<String, List<PricePoint>> _historyCache = {};
  final Map<CoinType, DateTime> _lastFetchTime = {};
  final Map<String, DateTime> _historyFetchTime = {};

  final http.Client _client = http.Client();

  // Rate limit tracking
  DateTime? _lastApiCall;
  static const Duration _minApiDelay = Duration(seconds: 3);
  int _rateLimitHits = 0;

  String _getCoinId(CoinType coinType) {
    switch (coinType) {
      case CoinType.btc:
        return AppConstants.btcCoinId;
      case CoinType.eth:
        return AppConstants.ethCoinId;
      case CoinType.trx:
        return AppConstants.trxCoinId;
    }
  }

  Future<void> _respectRateLimit() async {
    if (_lastApiCall != null) {
      final timeSince = DateTime.now().difference(_lastApiCall!);
      if (timeSince < _minApiDelay) {
        await Future.delayed(_minApiDelay - timeSince);
      }
    }
    _lastApiCall = DateTime.now();
  }

  Future<PriceData> fetchPrice(CoinType coinType) async {
    try {
      if (_isCacheFresh(coinType)) {
        print('✅ Using cached price for ${coinType.name}');
        return _priceCache[coinType]!;
      }

      await _respectRateLimit();

      final coinId = _getCoinId(coinType);
      final url = '${AppConstants.priceApiUrl}/coins/markets'
          '?vs_currency=usd&ids=$coinId&order=market_cap_desc'
          '&per_page=1&page=1&sparkline=false&price_change_percentage=24h';

      print('🔄 Fetching price for ${coinType.name}...');

      final response = await _client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final priceData = PriceData.fromJson(data[0]);
          _priceCache[coinType] = priceData;
          _lastFetchTime[coinType] = DateTime.now();
          _rateLimitHits = 0;

          print('✅ Fetched ${coinType.name} price: \$${priceData.price}');
          return priceData;
        }
      } else if (response.statusCode == 429) {
        _rateLimitHits++;
        print('⚠️ Rate limit hit for ${coinType.name} (count: $_rateLimitHits)');

        if (_priceCache.containsKey(coinType)) {
          return _priceCache[coinType]!;
        }
      }

      if (_priceCache.containsKey(coinType)) {
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

    // Fetch sequentially to avoid rate limits
    for (final coinType in [CoinType.btc, CoinType.eth, CoinType.trx]) {
      try {
        prices[coinType] = await fetchPrice(coinType);
        // Add delay between requests
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        print('Error fetching $coinType: $e');
        prices[coinType] = _priceCache[coinType] ??
            PriceData(price: 0.0, change24h: 0.0, history: []);
      }
    }

    return prices;
  }

  PriceData? getCachedPrice(CoinType coinType) {
    return _priceCache[coinType];
  }

  Future<List<PricePoint>> fetchPriceHistory(CoinType coinType, {int days = 7}) async {
    try {
      final cacheKey = '${coinType.name}_$days';

      // Check cache first with longer TTL for rate limit protection
      final cacheTTL = _rateLimitHits > 3
          ? const Duration(minutes: 15)
          : const Duration(minutes: 10);

      if (_isHistoryCacheFresh(cacheKey, maxAge: cacheTTL)) {
        print('✅ Using cached history for ${coinType.name} ($days days)');
        return _historyCache[cacheKey]!;
      }

      // Don't fetch if we're hitting rate limits too much
      if (_rateLimitHits > 5) {
        print('⚠️ Skipping history fetch due to rate limits');
        return _historyCache[cacheKey] ?? [];
      }

      await _respectRateLimit();

      final coinId = _getCoinId(coinType);
      int actualDays = days;

      // Simplify to only supported intervals
      if (days <= 1) {
        actualDays = 1;
      } else if (days <= 7) {
        actualDays = 7;
      } else {
        actualDays = 30;
      }

      final url = '${AppConstants.priceApiUrl}/coins/$coinId/market_chart'
          '?vs_currency=usd&days=$actualDays&interval=daily';

      print('🔄 Fetching price history: $coinId ($actualDays days)');

      final response = await _client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List? ?? [];

        if (prices.isEmpty) {
          print('⚠️ No price data returned');
          return _historyCache[cacheKey] ?? [];
        }

        List<PricePoint> pricePoints = prices.map((point) {
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0]),
            price: (point[1] as num).toDouble(),
          );
        }).toList();

        // Sample data if too many points
        if (pricePoints.length > 50) {
          final step = (pricePoints.length / 50).ceil();
          pricePoints = [
            for (int i = 0; i < pricePoints.length; i += step)
              pricePoints[i]
          ];
        }

        _historyCache[cacheKey] = pricePoints;
        _historyFetchTime[cacheKey] = DateTime.now();
        _rateLimitHits = 0;

        print('✅ Fetched ${pricePoints.length} price points for $coinId');
        return pricePoints;
      } else if (response.statusCode == 429) {
        _rateLimitHits++;
        print('⚠️ Rate limit hit for history (count: $_rateLimitHits)');
        return _historyCache[cacheKey] ?? [];
      }

      return _historyCache[cacheKey] ?? [];
    } catch (e) {
      print('❌ Error fetching price history: $e');
      final cacheKey = '${coinType.name}_$days';
      return _historyCache[cacheKey] ?? [];
    }
  }

  bool _isCacheFresh(CoinType coinType) {
    if (!_priceCache.containsKey(coinType)) return false;
    if (!_lastFetchTime.containsKey(coinType)) return false;

    // Longer cache if hitting rate limits
    final cacheDuration = _rateLimitHits > 3
        ? const Duration(minutes: 10)
        : const Duration(minutes: 3);

    final age = DateTime.now().difference(_lastFetchTime[coinType]!);
    return age < cacheDuration;
  }

  bool _isHistoryCacheFresh(String cacheKey, {Duration maxAge = const Duration(minutes: 10)}) {
    if (!_historyCache.containsKey(cacheKey)) return false;
    if (!_historyFetchTime.containsKey(cacheKey)) return false;

    final age = DateTime.now().difference(_historyFetchTime[cacheKey]!);
    return age < maxAge;
  }

  void clearCache() {
    _priceCache.clear();
    _historyCache.clear();
    _lastFetchTime.clear();
    _historyFetchTime.clear();
    _rateLimitHits = 0;
    print('🗑️ Price cache cleared');
  }

  Future<List<double>> getSparklineData(CoinType coinType) async {
    try {
      final history = await fetchPriceHistory(coinType, days: 7);
      if (history.isEmpty) return [];

      final points = history.length > 24 ? history.sublist(history.length - 24) : history;
      return points.map((p) => p.price).toList();
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}