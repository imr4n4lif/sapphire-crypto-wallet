import 'dart:convert';
import '../../models/address_book_entry.dart';
import '../constants/app_constants.dart';
import 'secure_storage_service.dart';

class AddressBookService {
  static final AddressBookService _instance = AddressBookService._internal();
  factory AddressBookService() => _instance;
  AddressBookService._internal();

  final SecureStorageService _storage = SecureStorageService();
  List<AddressBookEntry> _entries = [];

  static const String _storageKey = 'address_book_entries';

  Future<void> initialize() async {
    await loadEntries();
  }

  Future<void> loadEntries() async {
    try {
      final jsonString = await _storage.readString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _entries = jsonList.map((json) => AddressBookEntry.fromJson(json)).toList();
        print('✅ Loaded ${_entries.length} address book entries');
      }
    } catch (e) {
      print('❌ Error loading address book: $e');
      _entries = [];
    }
  }

  Future<void> _saveEntries() async {
    try {
      final jsonList = _entries.map((entry) => entry.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _storage.saveString(_storageKey, jsonString);
      print('✅ Saved ${_entries.length} address book entries');
    } catch (e) {
      print('❌ Error saving address book: $e');
    }
  }

  Future<void> addEntry(AddressBookEntry entry) async {
    _entries.add(entry);
    await _saveEntries();
  }

  Future<void> updateEntry(AddressBookEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      await _saveEntries();
    }
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _saveEntries();
  }

  List<AddressBookEntry> getAllEntries() {
    return List.from(_entries);
  }

  List<AddressBookEntry> getEntriesByCoin(CoinType coinType) {
    return _entries.where((e) => e.coinType == coinType).toList();
  }

  AddressBookEntry? getEntryById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  bool addressExists(String address, CoinType coinType) {
    return _entries.any((e) => e.address.toLowerCase() == address.toLowerCase() && e.coinType == coinType);
  }
}