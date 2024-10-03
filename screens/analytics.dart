import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  final String collectionName;

  const AnalyticsScreen({super.key, required this.collectionName});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<FlSpot> tempData = [];
  List<FlSpot> spo2Data = [];
  List<String> timeLabels = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(widget.collectionName)
              .orderBy('time', descending: true)
              .limit(1000) // Adjust the limit to fit your needs
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              final data = snapshot.data!.docs;

              tempData = _addBufferPoints(data
                  .asMap()
                  .entries
                  .map((entry) => FlSpot(
                      entry.key.toDouble(), double.parse(entry.value['Temp'])))
                  .toList());
              spo2Data = _addBufferPoints(data
                  .asMap()
                  .entries
                  .map((entry) => FlSpot(
                      entry.key.toDouble(), double.parse(entry.value['SpO2'])))
                  .toList());
              timeLabels = data.map((doc) {
                var timeField = doc['time'];
                if (timeField is Timestamp) {
                  var dateTime = timeField.toDate();
                  var date = DateFormat('MM/dd').format(dateTime);
                  var time = DateFormat('HH:mm').format(dateTime);
                  return '$date\n$time';
                } else {
                  return 'Invalid Time';
                }
              }).toList();

              return Column(
                children: [
                  _buildLineChart(
                      tempData, timeLabels, 'Temperature (°C)', Colors.blue),
                  const SizedBox(height: 16),
                  _buildLineChart(spo2Data, timeLabels, 'SpO2 (%)', Colors.red),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  List<FlSpot> _addBufferPoints(List<FlSpot> data) {
    if (data.isEmpty) {
      return data;
    }

    // Find the min and max y-values
    double minValue = data
        .map((spot) => spot.y)
        .reduce((min, value) => min < value ? min : value);
    double maxValue = data
        .map((spot) => spot.y)
        .reduce((max, value) => max > value ? max : value);

    // Calculate buffer values
    double buffer = (maxValue - minValue) * 0.1; // 10% buffer
    minValue -= buffer;
    maxValue += buffer;

    // Add buffer points
    data.insert(0, FlSpot(data.first.x - 1, minValue));
    data.add(FlSpot(data.last.x + 1, maxValue));

    return data;
  }

  Widget _buildLineChart(
      List<FlSpot> data, List<String> labels, String title, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    // Width calculated dynamically based on the length of data
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: LineChart(
                      LineChartData(
                        // Grid data: make the grid lines thinner for better visibility
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: color.withOpacity(0.2),
                              strokeWidth: 0.5,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: color.withOpacity(0.2),
                              strokeWidth: 0.5,
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
                                  value.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.black,
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
                                int index = value.toInt();
                                if (index < 0 || index >= labels.length) {
                                  return Container();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    labels[index],
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 8,
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
                            spots: data,
                            isCurved: true,
                            color: color,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(show: false),
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
