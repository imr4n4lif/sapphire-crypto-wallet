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
      // Check cache validity (1 minute for real-time prices)
      if (_isCacheFresh(coinType)) {
        return _priceCache[coinType]!;
      }

      final coinId = _getCoinId(coinType);
      final url = '${AppConstants.priceApiUrl}/coins/markets'
          '?vs_currency=usd&ids=$coinId&order=market_cap_desc'
          '&per_page=1&page=1&sparkline=false&price_change_percentage=24h';

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
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit hit for ${coinType.name}, using cache');
        // Return cached data if available
        if (_priceCache.containsKey(coinType)) {
          return _priceCache[coinType]!;
        }
      }

      // Return cached data or default
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

    // Fetch concurrently with error handling for each
    final results = await Future.wait([
      fetchPrice(CoinType.btc),
      fetchPrice(CoinType.eth),
      fetchPrice(CoinType.fil),
    ].map((future) => future.catchError((e) {
      print('Error in fetchAllPrices: $e');
      return PriceData(price: 0.0, change24h: 0.0, history: []);
    })));

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

      // Check history cache (5 minutes for history data)
      if (_isHistoryCacheFresh(cacheKey)) {
        print('📦 Using cached history for ${coinType.name} ($days days)');
        return _historyCache[cacheKey]!;
      }

      final coinId = _getCoinId(coinType);

      // Improved interval selection for better chart rendering
      String interval = 'daily';

      // For 1 hour view (days = 0 or fractional)
      if (days <= 0) {
        // Fetch last 24 hours with 5-minute intervals
        days = 1;
        interval = 'minutely';
      } else if (days == 1) {
        // For 24 hours, use 5-minute intervals
        interval = 'minutely';
      } else if (days <= 7) {
        // For 1 week, use hourly data
        interval = 'hourly';
      } else if (days <= 30) {
        // For 1 month, use 4-hour intervals
        interval = 'hourly';
      } else if (days <= 90) {
        // For 3 months, use daily
        interval = 'daily';
      } else {
        // For 1 year, use daily
        interval = 'daily';
      }

      final url = '${AppConstants.priceApiUrl}/coins/$coinId/market_chart'
          '?vs_currency=usd&days=$days&interval=$interval';

      print('🔄 Fetching price history: ${coinType.name} ($days days, $interval)');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List? ?? [];

        if (prices.isEmpty) {
          print('⚠️ No price data returned for ${coinType.name}');
          return _historyCache[cacheKey] ?? [];
        }

        // Process and filter data points for optimal chart display
        List<PricePoint> pricePoints = prices.map((point) {
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0]),
            price: (point[1] as num).toDouble(),
          );
        }).toList();

        // Limit data points for better performance
        if (pricePoints.length > 200) {
          // Sample data to keep around 200 points
          final step = pricePoints.length ~/ 200;
          pricePoints = [
            for (int i = 0; i < pricePoints.length; i += step)
              pricePoints[i]
          ];
        }

        _historyCache[cacheKey] = pricePoints;
        _historyFetchTime[cacheKey] = DateTime.now();

        print('✅ Fetched ${pricePoints.length} price points for ${coinType.name}');
        return pricePoints;
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit hit for ${coinType.name} history');
        return _historyCache[cacheKey] ?? [];
      } else {
        print('⚠️ HTTP ${response.statusCode} for ${coinType.name} history');
      }

      return _historyCache[cacheKey] ?? [];
    } catch (e) {
      print('❌ Error fetching price history for $coinType: $e');
      final cacheKey = '${coinType.name}_$days';
      return _historyCache[cacheKey] ?? [];
    }
  }

  // Special method for 1-hour chart data
  Future<List<PricePoint>> fetchHourlyHistory(CoinType coinType) async {
    try {
      final cacheKey = '${coinType.name}_hourly';

      if (_isHistoryCacheFresh(cacheKey, maxAge: const Duration(minutes: 2))) {
        return _historyCache[cacheKey]!;
      }

      final coinId = _getCoinId(coinType);

      // Fetch last 60 minutes with high resolution
      final url = '${AppConstants.priceApiUrl}/coins/$coinId/market_chart'
          '?vs_currency=usd&days=0.042&interval=minutely'; // 0.042 days = ~1 hour

      print('🔄 Fetching hourly data for ${coinType.name}');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List? ?? [];

        final pricePoints = prices.map((point) {
          return PricePoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(point[0]),
            price: (point[1] as num).toDouble(),
          );
        }).toList();

        _historyCache[cacheKey] = pricePoints;
        _historyFetchTime[cacheKey] = DateTime.now();

        return pricePoints;
      }

      return [];
    } catch (e) {
      print('❌ Error fetching hourly history: $e');
      return [];
    }
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

  // Get sparkline data for mini charts
  Future<List<double>> getSparklineData(CoinType coinType) async {
    try {
      final history = await fetchPriceHistory(coinType, days: 7);
      if (history.isEmpty) return [];

      // Return last 24 data points for sparkline
      final points = history.length > 24 ? history.sublist(history.length - 24) : history;
      return points.map((p) => p.price).toList();
    } catch (e) {
      return [];
    }
  }
}