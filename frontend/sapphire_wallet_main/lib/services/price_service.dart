// lib/services/price_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PriceService {
  static final PriceService _instance = PriceService._internal();
  factory PriceService() => _instance;
  PriceService._internal();

  static const String _baseUrl = 'https://api.coingecko.com/api/v3';
  Timer? _priceTimer;
  final Map<String, double> _priceCache = {};
  final Map<String, List<PricePoint>> _historyCache = {};

  // Get current prices
  Future<Map<String, double>> getCurrentPrices() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/simple/price?ids=bitcoin,ethereum,filecoin&vs_currencies=usd'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _priceCache['BTC'] = (data['bitcoin']['usd'] as num).toDouble();
        _priceCache['ETH'] = (data['ethereum']['usd'] as num).toDouble();
        _priceCache['FIL'] = (data['filecoin']['usd'] as num).toDouble();
        return Map.from(_priceCache);
      }
    } catch (e) {
      print('Error fetching prices: $e');
    }
    return _priceCache;
  }

  // Get price history
  Future<List<PricePoint>> getPriceHistory(String symbol, int days) async {
    final coinId = _getCoinId(symbol);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/coins/$coinId/market_chart?vs_currency=usd&days=$days'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> prices = data['prices'];

        final history = prices.map((p) => PricePoint(
          time: DateTime.fromMillisecondsSinceEpoch(p[0]),
          price: (p[1] as num).toDouble(),
        )).toList();

        _historyCache[symbol] = history;
        return history;
      }
    } catch (e) {
      print('Error fetching price history: $e');
    }
    return _historyCache[symbol] ?? [];
  }

  String _getCoinId(String symbol) {
    switch (symbol) {
      case 'BTC': return 'bitcoin';
      case 'ETH': return 'ethereum';
      case 'FIL': return 'filecoin';
      default: return symbol.toLowerCase();
    }
  }

  // Start auto-refresh
  void startPriceUpdates(void Function(Map<String, double>) onUpdate) {
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final prices = await getCurrentPrices();
      onUpdate(prices);
    });
  }

  // Stop auto-refresh
  void stopPriceUpdates() {
    _priceTimer?.cancel();
    _priceTimer = null;
  }
}

class PricePoint {
  final DateTime time;
  final double price;

  PricePoint({required this.time, required this.price});
}