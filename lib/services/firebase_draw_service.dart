import 'package:flutter/material.dart';

// Firebase Realtime DB service - stub until Firebase is configured
// To enable: run flutterfire configure and uncomment the real implementation

class DrawLiveData {
  final int entriesSold;
  final String status;
  final DateTime? endTime;
  
  DrawLiveData({required this.entriesSold, required this.status, this.endTime});
  
  factory DrawLiveData.fromJson(Map<String, dynamic> j) => DrawLiveData(
    entriesSold: j['entries_sold'] ?? 0,
    status: j['status'] ?? 'active',
    endTime: j['end_time'] != null ? DateTime.parse(j['end_time']) : null,
  );
}

class FirebaseDrawService {
  Stream<DrawLiveData> watchDraw(String drawId) {
    // Returns empty stream until Firebase is configured
    return const Stream.empty();
  }
}
