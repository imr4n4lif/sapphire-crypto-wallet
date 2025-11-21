import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../constants/app_constants.dart';
import '../../models/wallet.dart';

class PriceService {
  static final PriceService _instance = PriceService._internal();
  factory PriceService() => _instance;
  PriceService._internal();

  // Enhanced caching
  final Map<CoinType, PriceData> _priceCache = {};
  final Map<String, List<PricePoint>> _historyCache = {};
  final Map<CoinType, DateTime> _lastFetchTime = {};
  final Map<String, DateTime> _historyFetchTime = {};

  final http.Client _client = http.Client();

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

  Future<PriceData> fetchPrice(CoinType coinType) async {
    try {
      if (_isCacheFresh(coinType)) {
        return _priceCache[coinType]!;
      }

      final coinId = _getCoinId(coinType);
      final url = '${AppConstants.priceApiUrl}/coins/markets'
          '?vs_currency=usd&ids=$coinId&order=market_cap_desc'
          '&per_page=1&page=1&sparkline=false&price_change_percentage=24h';

      final response = await _client.get(Uri.parse(url)).timeout(
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
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit hit for ${coinType.name}');
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

    final results = await Future.wait([
      fetchPrice(CoinType.btc),
      fetchPrice(CoinType.eth),
      fetchPrice(CoinType.trx),
    ].map((future) => future.catchError((e) {
      print('Error in fetchAllPrices: $e');
      return PriceData(price: 0.0, change24h: 0.0, history: []);
    })));

    prices[CoinType.btc] = results[0];
    prices[CoinType.eth] = results[1];
    prices[CoinType.trx] = results[2];

    return prices;
  }

  PriceData? getCachedPrice(CoinType coinType) {
    return _priceCache[coinType];
  }

  Future<List<PricePoint>> fetchPriceHistory(CoinType coinType, {int days = 7}) async {
    try {
      final cacheKey = '${coinType.name}_$days';

      if (_isHistoryCacheFresh(cacheKey)) {
        return _historyCache[cacheKey]!;
      }

      final coinId = _getCoinId(coinType);
      String interval;
      int actualDays = days;

      // Optimized intervals for each timeframe
      if (days == 0) {
        // 1 hour view
        actualDays = 1;
        interval = '5m'; // 5-minute intervals
      } else if (days == 1) {
        interval = '5m'; // 24 hours with 5-min intervals
      } else if (days <= 7) {
        interval = '1h'; // 1 week with hourly data
      } else if (days <= 30) {
        interval = '4h'; // 1 month with 4-hour intervals
      } else if (days <= 90) {
        interval = 'daily'; // 3 months with daily data
      } else {
        interval = 'daily'; // 1 year with daily data
      }

      // CoinGecko API endpoint
      final url = '${AppConstants.priceApiUrl}/coins/$coinId/market_chart'
          '?vs_currency=usd&days=$actualDays&interval=$interval';

      print('🔄 Fetching price history: $coinId ($actualDays days, $interval)');

      final response = await _client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List? ?? [];

        if (prices.isEmpty) {
          print('⚠️ No price data returned');
          return [];
        }

        // Convert to PricePoint objects
        List<PricePoint> pricePoints = prices.map((point) {
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0]),
            price: (point[1] as num).toDouble(),
          );
        }).toList();

        // Filter to last hour if requested
        if (days == 0) {
          final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
          pricePoints = pricePoints.where((p) => p.timestamp.isAfter(oneHourAgo)).toList();
        }

        // Sample data if too many points (keep ~200 points max)
        if (pricePoints.length > 200) {
          final step = (pricePoints.length / 200).ceil();
          pricePoints = [
            for (int i = 0; i < pricePoints.length; i += step)
              pricePoints[i]
          ];
        }

        // Ensure we have the latest point
        if (pricePoints.isNotEmpty && days == 0) {
          // For 1-hour view, ensure smooth recent data
          pricePoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }

        _historyCache[cacheKey] = pricePoints;
        _historyFetchTime[cacheKey] = DateTime.now();

        print('✅ Fetched ${pricePoints.length} price points for $coinId');
        return pricePoints;
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit hit for history');
        await Future.delayed(const Duration(seconds: 2));
        return _historyCache[cacheKey] ?? [];
      }

      return _historyCache[cacheKey] ?? [];
    } catch (e) {
      print('❌ Error fetching price history: $e');
      final cacheKey = '${coinType.name}_$days';
      return _historyCache[cacheKey] ?? [];
    }
  }

  // Specialized method for hourly data
  Future<List<PricePoint>> fetchHourlyHistory(CoinType coinType) async {
    return fetchPriceHistory(coinType, days: 0);
  }

  bool _isCacheFresh(CoinType coinType) {
    if (!_priceCache.containsKey(coinType)) return false;
    if (!_lastFetchTime.containsKey(coinType)) return false;

    final age = DateTime.now().difference(_lastFetchTime[coinType]!);
    return age < const Duration(minutes: 1);
  }

  bool _isHistoryCacheFresh(String cacheKey, {Duration maxAge = const Duration(minutes: 5)}) {
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