import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet_models.dart';

class CryptoApiService {
  static const String baseUrl = 'https://api.coingecko.com/api/v3';

  static Future<double> getCoinPrice(String coinId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/simple/price?ids=$coinId&vs_currencies=usd'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data[coinId]['usd'] as num).toDouble();
      }
    } catch (e) {
      print('Error fetching price for $coinId: $e');
    }
    return 0.0;
  }

  static Future<List<PricePoint>> getCoinPriceHistory(String coinId, int days) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/coins/$coinId/market_chart?vs_currency=usd&days=$days'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> prices = data['prices'];

        return prices.map((price) {
          return PricePoint(
            time: DateTime.fromMillisecondsSinceEpoch(price[0].toInt()),
            price: (price[1] as num).toDouble(),
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching price history for $coinId: $e');
    }
    return [];
  }

  static Map<String, String> getCoinId(String symbol) {
    final coinMap = {
      'BTC': {'id': 'bitcoin', 'name': 'Bitcoin'},
      'ETH': {'id': 'ethereum', 'name': 'Ethereum'},
      'FIL': {'id': 'filecoin', 'name': 'Filecoin'},
    };
    return coinMap[symbol] ?? {'id': symbol.toLowerCase(), 'name': symbol};
  }
}