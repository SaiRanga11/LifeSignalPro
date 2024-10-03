import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lifepro/screens/analytics.dart';
import 'package:lifepro/screens/data_display.dart';
import 'dart:async';

import 'package:lifepro/services/auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final User? user = Auth().currentUser;
  String _data1 = "";
  String _data2 = "";
  String _data3 = "";
  String? username;
  List<String> parts = [];
  String name = '';
  List<FlSpot> ecgData = [];
  double time = 0.0;
  StreamSubscription? _tempSubscription,
      _spo2Subscription,
      _fallSubscription,
      _ecgSubscription;

  @override
  void initState() {
    super.initState();
    username = user?.email;
    parts = username!.split('@');
    _readData();
  }

  void _readData() {
    _tempSubscription =
        _database.child('${parts[0]}/Temp').onValue.listen((event) {
      final data1 = event.snapshot.value;
      setState(() {
        _data1 = data1.toString();
      });
    });
    _spo2Subscription =
        _database.child('${parts[0]}/SpO2').onValue.listen((event) {
      final data2 = event.snapshot.value;
      setState(() {
        _data2 = data2.toString();
      });
    });
    _fallSubscription =
        _database.child('${parts[0]}/Fall Status').onValue.listen((event) {
      final data3 = event.snapshot.value;
      setState(() {
        _data3 = data3.toString();
        if (_data3 == 'true') {
          // Handle fall detection here, if needed
        }
      });
    });
    _ecgSubscription =
        _database.child('${parts[0]}/Heart Rate').onValue.listen((event) {
      final ecgValue = event.snapshot.value;
      setState(() {
        if (ecgValue != null) {
          ecgData.add(FlSpot(time, double.parse(ecgValue.toString())));
          time += 1;
          // Adjust the data length to control the "waveform" length
          if (ecgData.length > 40) {
            ecgData.removeAt(0);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tempSubscription?.cancel();
    _spo2Subscription?.cancel();
    _fallSubscription?.cancel();
    _ecgSubscription?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    await Auth().signOut();
  }

  Future<void> addUserData(String data1, String data2, String data3) async {
    List<Map<String, double>> ecgDataToSave =
        ecgData.map((e) => {'time': e.x, 'value': e.y}).toList();

    await FirebaseFirestore.instance.collection(parts[0]).add({
      'Temp': data1,
      'SpO2': data2,
      'Fall': data3,
      'ECG': ecgDataToSave,
      'time': Timestamp.now(), // Use Timestamp.now() for Firestore timestamp
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(parts[0]),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AnalyticsScreen(collectionName: parts[0]),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DataDisplay(collectionName: parts[0]),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          // **Top Row: Temperature and SpO2**
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Temperature Block
                  _buildDataBlock(
                    'Temperature',
                    _data1,
                    Icons.thermostat_rounded,
                    Colors.red,
                  ),
                  // SpO2 Block
                  _buildDataBlock(
                    'SpO2',
                    _data2,
                    Icons.health_and_safety_rounded,
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),

          // **ECG Chart Block (takes up the bottom half of the screen)**
          Expanded(
            flex: 7,
            child: Container(
              margin: const EdgeInsets.all(10.0),
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  SizedBox(
                    // Wrap LineChart in a SizedBox for height control
                    height: 500,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.green.withOpacity(0.2),
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: Colors.green.withOpacity(0.2),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.left,
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 13.0),
                                  child: Text(
                                    value.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: ecgData,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(show: false),
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FloatingActionButton(
                      onPressed: () {
                        addUserData(_data1, _data2, _data3);
                      },
                      backgroundColor: Colors.blue,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable widget for building the data blocks
  Widget _buildDataBlock(
    String title,
    String data,
    IconData iconData,
    Color color,
  ) {
    return Container(
      width: 160, // Increased width for the data blocks
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconData,
            size: 32,
            color: color,
          ),
          const SizedBox(height: 8.0),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            data,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
